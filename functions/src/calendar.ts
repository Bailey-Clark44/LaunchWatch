import { DocumentData, Firestore, Timestamp } from "firebase-admin/firestore";

/** Precisions that can honestly become a calendar entry. */
const TIMED = new Set(["SEC", "MIN", "HR"]);
const ALL_DAY = new Set(["AM", "PM", "DAY"]);

function stamp(date: Date): string {
  return date.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
}

function day(date: Date): string {
  return date.toISOString().slice(0, 10).replace(/-/g, "");
}

function escape(text: string): string {
  return text.replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
}

/** RFC 5545 lines are folded at 75 octets. */
function fold(line: string): string {
  const parts: string[] = [];
  let rest = line;
  while (rest.length > 74) {
    parts.push(rest.slice(0, 74));
    rest = ` ${rest.slice(74)}`;
  }
  parts.push(rest);
  return parts.join("\r\n");
}

export function canCalendar(precision: string | null | undefined): boolean {
  return TIMED.has(precision ?? "") || ALL_DAY.has(precision ?? "");
}

export function launchEvent(id: string, doc: DocumentData, origin: string, now = new Date(), kind: "launch" | "event" = "launch"): string[] | null {
  const net = doc.net instanceof Timestamp ? doc.net.toDate() : null;
  const precision = doc.netPrecision?.abbrev ?? null;
  if (!net || !canCalendar(precision)) return null;
  const name = String(doc.name ?? "Launch");
  const end = doc.windowEnd instanceof Timestamp ? doc.windowEnd.toDate() : null;
  const pad = [doc.pad?.name, doc.pad?.locationName].filter(Boolean).join(", ");
  const status = doc.status?.name ? `Status: ${doc.status.name}. ` : "";
  const webcast = Array.isArray(doc.webcasts) && doc.webcasts[0]?.url ? ` Webcast: ${doc.webcasts[0].url}` : "";
  const lines = [
    "BEGIN:VEVENT",
    `UID:${kind === "event" ? `event-${id}` : id}@launchwatch`,
    `DTSTAMP:${stamp(now)}`,
    `SUMMARY:${escape(`${kind === "event" ? "🛰️" : "🚀"} ${name}`)}`,
  ];
  if (TIMED.has(precision)) {
    const finish = end && end.getTime() > net.getTime() ? end : new Date(net.getTime() + 30 * 60 * 1000);
    lines.push(`DTSTART:${stamp(net)}`, `DTEND:${stamp(finish)}`);
  } else {
    const next = new Date(net.getTime() + 24 * 60 * 60 * 1000);
    lines.push(`DTSTART;VALUE=DATE:${day(net)}`, `DTEND;VALUE=DATE:${day(next)}`);
  }
  if (pad) lines.push(`LOCATION:${escape(pad)}`);
  lines.push(
    `DESCRIPTION:${escape(`${status}Times update automatically if the launch moves.${webcast}`)}`,
    `URL:${origin}/${kind}/${id}`,
    "END:VEVENT",
  );
  return lines;
}

export function calendar(name: string, events: string[][]): string {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//LaunchWatch//Launch calendar//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:${escape(name)}`,
    "REFRESH-INTERVAL;VALUE=DURATION:PT1H",
    "X-PUBLISHED-TTL:PT1H",
    ...events.flat(),
    "END:VCALENDAR",
  ];
  return lines.map(fold).join("\r\n") + "\r\n";
}

/**
 * /cal/launch/{id}.ics  one launch, always current.
 * /cal/user/{token}.ics every launch a user follows, as a subscribable feed.
 */
export async function calendarResponse(db: Firestore, path: string, origin: string): Promise<{ status: number; body: string }> {
  const launchMatch = path.match(/^\/cal\/launch\/([\w-]+)\.ics$/);
  if (launchMatch) {
    const doc = await db.collection("launches").doc(launchMatch[1]).get();
    if (!doc.exists) return { status: 404, body: "Launch not found" };
    const event = launchEvent(doc.id, doc.data() ?? {}, origin);
    if (!event) return { status: 409, body: "This launch does not have a firm date yet." };
    return { status: 200, body: calendar(String(doc.get("name") ?? "Launch"), [event]) };
  }

  const eventMatch = path.match(/^\/cal\/event\/(\d+)\.ics$/);
  if (eventMatch) {
    const doc = await db.collection("events").doc(eventMatch[1]).get();
    if (!doc.exists) return { status: 404, body: "Event not found" };
    const data = doc.data() ?? {};
    const event = launchEvent(
      doc.id,
      { name: data.name, net: data.date, netPrecision: data.precision, pad: { name: data.location }, webcasts: data.webcasts },
      origin,
      new Date(),
      "event",
    );
    if (!event) return { status: 409, body: "This event does not have a firm date yet." };
    return { status: 200, body: calendar(String(data.name ?? "Event"), [event]) };
  }

  const userMatch = path.match(/^\/cal\/user\/([A-Za-z0-9]{20,64})\.ics$/);
  if (userMatch) {
    const users = await db.collection("users").where("calendarToken", "==", userMatch[1]).limit(1).get();
    if (users.empty) return { status: 404, body: "Calendar not found" };
    const follows = await users.docs[0].ref.collection("follows").get();
    const refs = follows.docs.map((f) => db.collection("launches").doc(f.get("launchId") ?? f.id));
    const docs = refs.length ? await db.getAll(...refs) : [];
    const events = docs
      .filter((d) => d.exists)
      .map((d) => launchEvent(d.id, d.data() ?? {}, origin))
      .filter((e): e is string[] => e !== null);
    return { status: 200, body: calendar("LaunchWatch: followed launches", events) };
  }
  return { status: 404, body: "Not found" };
}
