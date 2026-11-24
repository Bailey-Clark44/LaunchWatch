import assert from "node:assert/strict";
import test from "node:test";
import { Timestamp } from "firebase-admin/firestore";
import { describeNet, diffLaunch, periodKey, type LaunchSnapshot } from "./notify";
import { digestMessage, weekAhead } from "./digest";
import { calendar, canCalendar, launchEvent } from "./calendar";
import { isCrewed } from "./mapLaunch";

function snap(overrides: Partial<LaunchSnapshot> = {}): LaunchSnapshot {
  return {
    name: "Starlink Group 10-12",
    net: new Date("2026-11-20T14:40:00Z"),
    precision: "MIN",
    statusId: 1,
    statusName: "Go for Launch",
    updateIds: [1],
    latestUpdate: null,
    ...overrides,
  };
}

test("a clock slip of five minutes or more is news", () => {
  const change = diffLaunch("a", snap(), snap({ net: new Date("2026-11-21T14:40:00Z") }));
  assert.equal(change?.kind, "slips");
  assert.match(change!.message("UTC").title, /slipped to Sat 21 Nov/);
});

test("a two-minute nudge is not", () => {
  assert.equal(diffLaunch("a", snap(), snap({ net: new Date("2026-11-20T14:42:00Z") })), null);
});

test("a month-precision date moving inside the month is not news", () => {
  const before = snap({ precision: "M", net: new Date("2026-12-01T00:00:00Z") });
  const after = snap({ precision: "M", net: new Date("2026-12-15T00:00:00Z") });
  assert.equal(diffLaunch("a", before, after), null);
});

test("a year-precision date moving to the next year is news", () => {
  const before = snap({ precision: "Y", net: new Date("2026-12-31T00:00:00Z") });
  const after = snap({ precision: "Y", net: new Date("2027-12-31T00:00:00Z") });
  assert.equal(diffLaunch("a", before, after)?.kind, "slips");
});

test("status changes win over slips, and liftoff and outcome are their own kinds", () => {
  assert.equal(diffLaunch("a", snap(), snap({ statusId: 5, net: new Date("2026-11-22T00:00:00Z") }))?.kind, "status");
  assert.equal(diffLaunch("a", snap(), snap({ statusId: 6 }))?.kind, "liftoff");
  assert.equal(diffLaunch("a", snap({ statusId: 6 }), snap({ statusId: 3 }))?.kind, "outcome");
});

test("new updates are collapsed into one message", () => {
  const change = diffLaunch("a", snap(), snap({ updateIds: [1, 2, 3], latestUpdate: "Weather scrub." }));
  assert.equal(change?.kind, "updates");
  assert.equal(change!.message("UTC").title, "2 updates on Starlink Group 10-12");
});

test("the first sighting of a launch is not a change", () => {
  assert.equal(diffLaunch("a", null, snap()), null);
});

test("periods and descriptions respect precision", () => {
  assert.equal(periodKey(new Date("2027-05-02T00:00:00Z"), "Q2"), "2027-Q1");
  assert.equal(describeNet(new Date("2027-12-31T00:00:00Z"), "Y", "UTC"), "2027");
  assert.equal(describeNet(new Date("2027-03-31T00:00:00Z"), "M", "UTC"), "March 2027");
});

test("the digest counts only dated launches in the next week", () => {
  const now = Date.parse("2026-11-16T08:00:00Z");
  const week = weekAhead(
    [
      { id: "1", name: "A", net: new Date("2026-11-17T10:00:00Z"), precision: "MIN", crewed: false },
      { id: "2", name: "B", net: new Date("2026-11-18T00:00:00Z"), precision: "DAY", crewed: true },
      { id: "3", name: "C", net: new Date("2026-11-19T00:00:00Z"), precision: "M", crewed: false },
      { id: "4", name: "D", net: new Date("2026-12-30T00:00:00Z"), precision: "MIN", crewed: false },
    ],
    now,
  );
  assert.deepEqual(week.map((l) => l.id), ["1", "2"]);
  assert.equal(digestMessage(week, "UTC").title, "This week: 2 launches, 1 crewed");
});

test("calendar events exist only for dated launches", () => {
  assert.equal(canCalendar("Y"), false);
  assert.equal(canCalendar("DAY"), true);
  const timed = launchEvent("abc", { name: "Vulcan", net: Timestamp.fromDate(new Date("2026-11-13T17:54:00Z")), netPrecision: { abbrev: "MIN" } }, "https://x.app");
  assert.ok(timed?.includes("DTSTART:20261113T175400Z"));
  const allDay = launchEvent("abc", { name: "Vulcan", net: Timestamp.fromDate(new Date("2026-11-13T00:00:00Z")), netPrecision: { abbrev: "DAY" } }, "https://x.app");
  assert.ok(allDay?.includes("DTSTART;VALUE=DATE:20261113"));
  assert.equal(launchEvent("abc", { name: "X", net: Timestamp.now(), netPrecision: { abbrev: "Y" } }, "https://x.app"), null);
  assert.match(calendar("Test", [timed!]), /^BEGIN:VCALENDAR\r\n/);
});

test("crewed flights are recognised without an LL2 flag", () => {
  assert.equal(isCrewed({ name: "Long March 2F/G | Shenzhou 24" }, { type: "Human Exploration" }, null), true);
  assert.equal(isCrewed({ name: "Falcon 9 Block 5 | Crew-12" }, { type: "Human Exploration" }, null), true);
  assert.equal(isCrewed({ name: "Falcon 9 Block 5 | Starlink Group 10-12" }, { type: "Communications" }, null), false);
  assert.equal(isCrewed({ name: "Falcon 9 | CRS-34" }, { type: "Resupply" }, null), false);
});
