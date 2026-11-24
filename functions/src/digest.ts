import { Firestore, Timestamp } from "firebase-admin/firestore";
import { deliver, describeNet } from "./notify";

const FINE = new Set(["SEC", "MIN", "HR", "AM", "PM", "DAY"]);

export interface DigestLaunch {
  id: string;
  name: string;
  net: Date;
  precision: string | null;
  crewed: boolean;
}

/** The week ahead, counting only launches dated to the day or better. */
export function weekAhead(launches: DigestLaunch[], now: number): DigestLaunch[] {
  const end = now + 7 * 24 * 60 * 60 * 1000;
  return launches
    .filter((l) => FINE.has(l.precision ?? "") && l.net.getTime() >= now && l.net.getTime() < end)
    .sort((a, b) => a.net.getTime() - b.net.getTime());
}

export function digestMessage(week: DigestLaunch[], zone: string): { title: string; body: string } {
  if (week.length === 0) {
    return { title: "A quiet week for launches", body: "Nothing is dated for the next seven days yet. We'll tell you when that changes." };
  }
  const crewed = week.filter((l) => l.crewed).length;
  const first = week[0];
  const count = `${week.length} launch${week.length === 1 ? "" : "es"}`;
  return {
    title: crewed > 0 ? `This week: ${count}, ${crewed} crewed` : `This week: ${count}`,
    body: `First up: ${first.name}, ${describeNet(first.net, first.precision, zone)}.`,
  };
}

export async function sendWeeklyDigest(db: Firestore, now = Date.now()): Promise<number> {
  const [launchSnap, users] = await Promise.all([
    db.collection("launches").where("list", "==", "upcoming").get(),
    db.collection("users").where("digest", "==", true).get(),
  ]);
  const launches: DigestLaunch[] = launchSnap.docs
    .map((doc) => {
      const net = doc.get("net");
      if (!(net instanceof Timestamp)) return null;
      return {
        id: doc.id,
        name: String(doc.get("name") ?? "A launch"),
        net: net.toDate(),
        precision: (doc.get("netPrecision.abbrev") as string | undefined) ?? null,
        crewed: doc.get("crewed") === true,
      };
    })
    .filter((l): l is DigestLaunch => l !== null);
  const week = weekAhead(launches, now);
  let sent = 0;
  for (const user of users.docs) {
    try {
      await deliver(db, user.id, week[0]?.id ?? "", "status", (zone) => digestMessage(week, zone));
      sent += 1;
    } catch (error) {
      console.warn(`Could not send digest to ${user.id}`, error);
    }
  }
  return sent;
}
