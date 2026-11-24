import assert from "node:assert/strict";
import test from "node:test";
import { Timestamp } from "firebase-admin/firestore";
import { ENDPOINTS, dueEndpoints, mapArticle, mapDocking, mapEvent, mapExpedition, mapStation } from "./reference";
import { launchEvent } from "./calendar";

const astronaut = {
  id: 764,
  name: "Zhu Yangzhu",
  status: { id: 1, name: "Active" },
  agency: { id: 17, name: "China National Space Administration", abbrev: "CNSA" },
  image: { image_url: "https://x/full.jpg", thumbnail_url: "https://x/thumb.jpg" },
  in_space: true,
  time_in_space: "P314DT9H1M30S",
  nationality: [{ alpha_2_code: "CN", nationality_name: "Chinese" }],
  flights_count: 2,
};

test("events keep their precision, links, and relations", () => {
  const e = mapEvent(
    {
      id: 394,
      name: "BepiColombo Mercury Orbit Insertion",
      type: { id: 1, name: "Orbital Insertion" },
      date: "2026-11-30T00:00:00Z",
      date_precision: { abbrev: "M", name: "Month" },
      vid_urls: [{ url: "https://b", priority: 5 }, { url: "https://a", priority: 1, title: "Main" }],
      launches: [{ id: "abc" }],
      spacestations: [{ id: 4 }],
    },
    "upcoming",
  )!;
  assert.equal(e.id, "394");
  assert.deepEqual(e.doc.precision, { abbrev: "M", name: "Month" });
  assert.equal((e.doc.webcasts as { url: string }[])[0].url, "https://a");
  assert.deepEqual(e.doc.launchIds, ["abc"]);
  assert.deepEqual(e.doc.stationIds, ["4"]);
});

test("stations summarise who is docked at each port", () => {
  const s = mapStation({
    id: 4,
    name: "International Space Station",
    status: { name: "Active" },
    onboard_crew: 7,
    docking_location: [
      { name: "Harmony forward", currently_docked: { docking: "2026-10-01T23:05:00Z", flight_vehicle_chaser: { spacecraft: { name: "Crew Dragon Grace" }, launch: { id: "L1" } } } },
      { name: "Zarya nadir", currently_docked: null },
    ],
  })!;
  const ports = s.doc.ports as { port: string; spacecraft: string | null; launchId: string | null }[];
  assert.equal(s.doc.active, true);
  assert.equal(ports[0].spacecraft, "Crew Dragon Grace");
  assert.equal(ports[0].launchId, "L1");
  assert.equal(ports[1].spacecraft, null);
});

test("expeditions carry a compact crew and full astronaut profiles", () => {
  const x = mapExpedition({ id: 167, name: "Shenzhou 23", start: "2026-05-24T18:45:00Z", end: null, spacestation: { id: 18, name: "Tiangong" }, crew: [{ role: { role: "Commander" }, astronaut }] })!;
  assert.equal(x.doc.active, true);
  assert.deepEqual((x.doc.crew as { name: string; role: string; agency: string }[])[0], { id: "764", name: "Zhu Yangzhu", role: "Commander", thumbUrl: "https://x/thumb.jpg", agency: "CNSA", nationality: "CN" });
  assert.equal(x.astronauts[0].doc.inSpace, true);
  assert.equal((x.astronauts[0].doc.nationality as { name: string }).name, "Chinese");
});

test("dockings and news map their links", () => {
  const d = mapDocking({ id: 638, docking: "2026-04-28T00:00:48Z", docking_location: { name: "Harmony zenith" }, space_station_target: { id: 4, name: "ISS" }, flight_vehicle_chaser: { spacecraft: { name: "Cargo Dragon C211" }, launch: { id: "L2" } } })!;
  assert.equal(d.doc.spacecraft, "Cargo Dragon C211");
  assert.equal(d.doc.stationId, "4");
  const a = mapArticle({ id: 1, title: "T", url: "https://n", summary: "Hello\n world. The post T appeared first on SpaceNews.", launches: [{ launch_id: "L3" }], events: [{ event_id: 9 }] })!;
  assert.equal(a.doc.summary, "Hello world.");
  assert.deepEqual(a.doc.launchIds, ["L3"]);
  assert.deepEqual(a.doc.eventIds, ["9"]);
});

test("the most overdue endpoint goes first, and fresh ones wait", () => {
  const now = Date.parse("2026-11-12T12:00:00Z");
  const fetched: Record<string, number> = Object.fromEntries(ENDPOINTS.map((e) => [e.key, now]));
  assert.equal(dueEndpoints(fetched, now).length, 0);
  delete fetched.programs;
  fetched.eventsUpcoming = now - 5 * 3600 * 1000;
  assert.deepEqual(dueEndpoints(fetched, now).map((e) => e.key), ["programs", "eventsUpcoming"]);
});

test("events become calendar entries with their own link", () => {
  const lines = launchEvent("394", { name: "Spacewalk", net: Timestamp.fromDate(new Date("2026-12-01T12:00:00Z")), netPrecision: { abbrev: "MIN" } }, "https://x.app", new Date(), "event")!;
  assert.ok(lines.includes("URL:https://x.app/event/394"));
  assert.ok(lines.includes("UID:event-394@launchwatch"));
});
