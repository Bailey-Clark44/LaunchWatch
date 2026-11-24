import { DocumentData, FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

/** Alert categories a follow can switch on or off. Mirrors the app's settings. */
export type AlertKind = "slips" | "status" | "liftoff" | "outcome" | "reminder24h" | "updates";

export interface LaunchSnapshot {
  name: string;
  net: Date | null;
  precision: string | null;
  statusId: number | null;
  statusName: string | null;
  updateIds: number[];
  latestUpdate: string | null;
}

export interface LaunchChange {
  launchId: string;
  kind: AlertKind;
  /** Builds the message for one recipient, in their timezone. */
  message(timeZone: string): { title: string; body: string };
}

const CLOCK_PRECISIONS = new Set(["SEC", "MIN", "HR"]);
const FINE_PRECISIONS = new Set(["SEC", "MIN", "HR", "AM", "PM", "DAY"]);
const OUTCOME_STATUSES = new Set([3, 4, 7, 9]);
const FIVE_MINUTES = 5 * 60 * 1000;

const STATUS_LABELS: Record<number, string> = {
  1: "Go",
  2: "Unconfirmed",
  3: "Success",
  4: "Failure",
  5: "Hold",
  6: "In flight",
  7: "Partial failure",
  8: "To be confirmed",
  9: "Deployed",
};

export function statusLabel(id: number | null, fallback: string | null): string {
  return (id !== null && STATUS_LABELS[id]) || fallback || "Updated";
}

/**
 * The period a NET names, at its published precision. Two dates in the same
 * period are the same news: a month-precision date that moves a day is not a slip.
 */
export function periodKey(net: Date, precision: string | null): string {
  const y = net.getUTCFullYear();
  const m = net.getUTCMonth();
  switch (precision) {
    case "M":
      return `${y}-${m}`;
    case "Q1":
    case "Q2":
    case "Q3":
    case "Q4":
      return `${y}-Q${Math.floor(m / 3)}`;
    case "H1":
    case "H2":
      return `${y}-H${m < 6 ? 1 : 2}`;
    case "FY":
    case "Y":
      return `${y}`;
    case "DEC":
      return `${Math.floor(y / 10)}`;
    case "WK":
      return `${y}-w${Math.floor((net.getTime() - Date.UTC(y, 0, 1)) / (7 * 86400000))}`;
    default:
      return net.toISOString().slice(0, 10);
  }
}

/** Formats a NET for a notification, honest about its precision. */
export function describeNet(net: Date, precision: string | null, timeZone: string): string {
  const zone = safeZone(timeZone);
  const fmt = (options: Intl.DateTimeFormatOptions) =>
    new Intl.DateTimeFormat("en-GB", { timeZone: zone, ...options }).format(net);
  switch (precision) {
    case "SEC":
    case "MIN":
      return fmt({ weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
    case "HR":
      return `about ${fmt({ weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}`;
    case "AM":
    case "PM":
    case "DAY":
      return fmt({ weekday: "short", day: "numeric", month: "short" });
    case "WK":
      return `the week of ${fmt({ day: "numeric", month: "short" })}`;
    case "M":
      return fmt({ month: "long", year: "numeric" });
    case "Q1":
    case "Q2":
    case "Q3":
    case "Q4":
    case "H1":
    case "H2":
      return `${precision} ${net.getUTCFullYear()}`;
    case "FY":
    case "Y":
      return `${net.getUTCFullYear()}`;
    default:
      return fmt({ day: "numeric", month: "short", year: "numeric" });
  }
}

function safeZone(zone: string): string {
  try {
    new Intl.DateTimeFormat("en-GB", { timeZone: zone });
    return zone;
  } catch {
    return "UTC";
  }
}

/**
 * Compares two snapshots of one launch and returns at most one change, the
 * most important one. Returns null for noise inside the published precision.
 */
export function diffLaunch(launchId: string, before: LaunchSnapshot | null, after: LaunchSnapshot): LaunchChange | null {
  if (!before) return null;
  const name = after.name;

  if (after.statusId !== null && before.statusId !== after.statusId) {
    const label = statusLabel(after.statusId, after.statusName);
    if (after.statusId === 6) {
      return { launchId, kind: "liftoff", message: () => ({ title: `Liftoff: ${name}`, body: `${name} is in flight.` }) };
    }
    if (OUTCOME_STATUSES.has(after.statusId)) {
      return { launchId, kind: "outcome", message: () => ({ title: `${label}: ${name}`, body: `${name} has a result: ${label.toLowerCase()}.` }) };
    }
    return {
      launchId,
      kind: "status",
      message: (zone) => ({
        title: `${name} is now ${label}`,
        body: after.net ? `Status changed from ${statusLabel(before.statusId, before.statusName)}. NET ${describeNet(after.net, after.precision, zone)}.` : `Status changed from ${statusLabel(before.statusId, before.statusName)}.`,
      }),
    };
  }

  if (before.net && after.net) {
    const moved = after.net.getTime() - before.net.getTime();
    const clockSlip = CLOCK_PRECISIONS.has(after.precision ?? "") && Math.abs(moved) >= FIVE_MINUTES;
    const periodChanged = periodKey(before.net, before.precision) !== periodKey(after.net, after.precision);
    const fineDayChange = FINE_PRECISIONS.has(after.precision ?? "") && before.net.toISOString().slice(0, 10) !== after.net.toISOString().slice(0, 10);
    if (clockSlip || periodChanged || fineDayChange) {
      const verb = moved > 0 ? "slipped to" : moved < 0 ? "moved up to" : "is now";
      return {
        launchId,
        kind: "slips",
        message: (zone) => ({
          title: `${name} ${verb} ${describeNet(after.net!, after.precision, zone)}`,
          body: `Previously ${describeNet(before.net!, before.precision, zone)}.${after.latestUpdate ? ` ${after.latestUpdate}` : ""}`,
        }),
      };
    }
  }

  const known = new Set(before.updateIds);
  const fresh = after.updateIds.filter((id) => !known.has(id));
  if (before.updateIds.length > 0 && fresh.length > 0) {
    return {
      launchId,
      kind: "updates",
      message: () => ({
        title: fresh.length === 1 ? `Update on ${name}` : `${fresh.length} updates on ${name}`,
        body: after.latestUpdate ?? "Open LaunchWatch for the latest.",
      }),
    };
  }
  return null;
}

export function snapshotFromDoc(doc: DocumentData | undefined): LaunchSnapshot | null {
  if (!doc) return null;
  const updates = Array.isArray(doc.updates) ? doc.updates : [];
  return {
    name: typeof doc.name === "string" ? doc.name : "A launch",
    net: doc.net instanceof Timestamp ? doc.net.toDate() : null,
    precision: doc.netPrecision?.abbrev ?? null,
    statusId: typeof doc.status?.id === "number" ? doc.status.id : null,
    statusName: doc.status?.name ?? null,
    updateIds: updates.map((u: { id?: number }) => u.id).filter((id: unknown): id is number => typeof id === "number"),
    latestUpdate: typeof updates[0]?.comment === "string" ? updates[0].comment : null,
  };
}

export interface FollowRef {
  uid: string;
  launchId: string;
  data: DocumentData;
  path: string;
}

/** All follows, grouped by launch. One read per follow, done once per poll. */
export async function loadFollows(db: Firestore): Promise<Map<string, FollowRef[]>> {
  const snap = await db.collectionGroup("follows").get();
  const byLaunch = new Map<string, FollowRef[]>();
  for (const doc of snap.docs) {
    const uid = doc.ref.parent.parent?.id;
    if (!uid) continue;
    const launchId = (doc.get("launchId") as string | undefined) ?? doc.id;
    const list = byLaunch.get(launchId) ?? [];
    list.push({ uid, launchId, data: doc.data(), path: doc.ref.path });
    byLaunch.set(launchId, list);
  }
  return byLaunch;
}

function wants(follow: FollowRef, kind: AlertKind): boolean {
  const key = kind === "updates" ? "slips" : kind;
  const value = follow.data[key];
  return value === undefined ? true : value === true;
}

/** Delivers one message to one user: an inbox row always, push to every device. */
export async function deliver(
  db: Firestore,
  uid: string,
  launchId: string,
  kind: AlertKind,
  build: (zone: string) => { title: string; body: string },
): Promise<void> {
  const userRef = db.collection("users").doc(uid);
  const [user, devices] = await Promise.all([userRef.get(), userRef.collection("devices").get()]);
  const zone = (user.get("timezone") as string | undefined) ?? "UTC";
  const { title, body } = build(zone);

  await userRef.collection("inbox").add({
    title,
    body,
    launchId,
    kind,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const tokens = devices.docs.map((d) => d.get("token")).filter((t): t is string => typeof t === "string");
  if (tokens.length === 0) return;
  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: { launchId: launchId ?? "", kind },
    webpush: { fcmOptions: { link: launchId ? `/launch/${launchId}` : "/" } },
    android: { priority: kind === "liftoff" ? "high" : "normal", notification: { channelId: "launch_alerts" } },
    apns: { payload: { aps: { sound: "default" } } },
  });
  const stale: Promise<unknown>[] = [];
  response.responses.forEach((result, index) => {
    const code = result.error?.code;
    if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
      stale.push(devices.docs[index].ref.delete());
    }
  });
  await Promise.all(stale);
}

/** Sends every change to the people following that launch. */
export async function notifyFollowers(
  db: Firestore,
  changes: LaunchChange[],
  follows: Map<string, FollowRef[]>,
): Promise<number> {
  let sent = 0;
  for (const change of changes) {
    for (const follow of follows.get(change.launchId) ?? []) {
      if (!wants(follow, change.kind)) continue;
      try {
        await deliver(db, follow.uid, change.launchId, change.kind, change.message);
        await db.doc(follow.path).set({ lastNotifiedAt: FieldValue.serverTimestamp() }, { merge: true });
        sent += 1;
      } catch (error) {
        console.warn(`Could not notify ${follow.uid} about ${change.launchId}`, error);
      }
    }
  }
  return sent;
}

/** Day-before reminders for clock-precise launches that are Go or on Hold. */
export async function sendReminders(
  db: Firestore,
  launches: Map<string, LaunchSnapshot>,
  follows: Map<string, FollowRef[]>,
  now = Date.now(),
): Promise<number> {
  let sent = 0;
  for (const [launchId, launch] of launches) {
    if (!launch.net || !["SEC", "MIN"].includes(launch.precision ?? "")) continue;
    if (launch.statusId !== 1 && launch.statusId !== 5) continue;
    const until = launch.net.getTime() - now;
    if (until <= 0 || until > 24 * 60 * 60 * 1000) continue;
    for (const follow of follows.get(launchId) ?? []) {
      if (!wants(follow, "reminder24h")) continue;
      const sentFor = follow.data.reminderSentForNet;
      if (sentFor instanceof Timestamp && sentFor.toMillis() === launch.net.getTime()) continue;
      try {
        await deliver(db, follow.uid, launchId, "reminder24h", (zone) => ({
          title: `Tomorrow: ${launch.name}`,
          body: `Scheduled for ${describeNet(launch.net!, launch.precision, zone)}. Status: ${statusLabel(launch.statusId, launch.statusName)}.`,
        }));
        await db.doc(follow.path).set({ reminderSentForNet: Timestamp.fromDate(launch.net) }, { merge: true });
        sent += 1;
      } catch (error) {
        console.warn(`Could not send reminder to ${follow.uid}`, error);
      }
    }
  }
  return sent;
}
