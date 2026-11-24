import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import * as functionsV1 from "firebase-functions/v1";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { runPoll } from "./poll";
import { sendWeeklyDigest } from "./digest";
import { calendarResponse } from "./calendar";
import { runNewsPoll, runReferencePoll } from "./reference";

const REGION = "europe-west2";
setGlobalOptions({ region: REGION, maxInstances: 1 });

function db() {
  if (getApps().length === 0) initializeApp();
  return getFirestore();
}

export const pollQuiet = onSchedule("every 30 minutes", async () => {
  await runPoll({ detailed: false });
});

export const pollHot = onSchedule("every 10 minutes", async () => {
  await runPoll({ detailed: true, onlyIfHot: true });
});

/** Events, stations, crews, astronauts, spacewalks, programs: spare LL2 budget only. */
export const pollReference = onSchedule({ schedule: "every 30 minutes", timeoutSeconds: 300, memory: "512MiB" }, async () => {
  const done = await runReferencePoll(db());
  console.log(`Reference refreshed: ${done.join(", ") || "nothing due or no budget"}`);
});

/** Spaceflight News API: separate service, separate (generous) limits. */
export const pollNews = onSchedule("every 30 minutes", async () => {
  const n = await runNewsPoll(db());
  console.log(`News refreshed: ${n} articles`);
});

/** Monday morning summary for people who chose it over per-launch alerts. */
export const weeklyDigest = onSchedule({ schedule: "every monday 08:00", timeZone: "Europe/London" }, async () => {
  const sent = await sendWeeklyDigest(db());
  console.log(`Weekly digest sent to ${sent} users`);
});

/** Live .ics feeds. Calendar apps re-fetch them, so a slip moves the event. */
export const calendar = onRequest({ cors: true, maxInstances: 3 }, async (req, res) => {
  const origin = `https://${req.get("x-forwarded-host") ?? req.hostname}`;
  const { status, body } = await calendarResponse(db(), req.path, origin);
  res.status(status);
  res.set("Cache-Control", "public, max-age=600");
  res.set("Content-Type", status === 200 ? "text/calendar; charset=utf-8" : "text/plain; charset=utf-8");
  if (status === 200) res.set("Content-Disposition", 'inline; filename="launchwatch.ics"');
  res.send(body);
});

/** Deleting an account removes everything stored under it. */
export const cleanUpDeletedUser = functionsV1.region(REGION).auth.user().onDelete(async (user) => {
  const ref = db().collection("users").doc(user.uid);
  await db().recursiveDelete(ref);
});
