import assert from "node:assert/strict";
import test from "node:test";
import { detailRank, mapLaunch } from "./mapLaunch";

const sample = {
  id: "ef9850ad-1096-425b-9d27-f7bbd186e61a",
  name: "Vulcan VC6L | Amazon Leo (LV-01)",
  slug: "vulcan-vc6l-amazon-leo-lv-01",
  status: { id: 2, name: "To Be Determined", abbrev: "TBD" },
  last_updated: "2026-10-28T15:16:48Z",
  net: "2026-11-13T00:00:00Z",
  net_precision: { id: 5, name: "Day", abbrev: "DAY" },
  window_end: "2026-11-13T00:00:00Z",
  window_start: "2026-11-13T00:00:00Z",
  launch_service_provider: { id: 124, name: "United Launch Alliance" },
  rocket: { configuration: { id: 479, name: "Vulcan VC6L" } },
  mission: {
    name: "Amazon Leo (LV-01)",
    type: "Communications",
    description: "A constellation flight.",
    orbit: { name: "Low Earth Orbit", abbrev: "LEO" },
  },
  pad: {
    id: 29,
    name: "Space Launch Complex 41",
    latitude: 28.58,
    longitude: -80.58,
    location: { name: "Cape Canaveral", country: { alpha_3_code: "USA" } },
  },
  image: { image_url: "https://example.com/vulcan.jpg" },
  vid_urls: [
    { url: "https://example.com/backup", priority: 2, title: "Backup" },
    { url: "https://example.com/main", priority: 0, title: "Main" },
  ],
  info_urls: [{ url: "https://example.com/info", title: "ULA" }],
  updates: [
    { id: 2, comment: "Slipped one day.", created_on: "2026-11-01T00:00:00Z", info_url: null },
    { id: 9, comment: "Newer note.", created_on: "2026-11-02T00:00:00Z", info_url: "https://example.com/note" },
  ],
};

test("mapLaunch keeps the fields the app shows", () => {
  const mapped = mapLaunch(sample);
  assert.ok(mapped);
  assert.equal(mapped.name, "Vulcan VC6L | Amazon Leo (LV-01)");
  assert.equal(mapped.status.abbrev, "TBD");
  assert.equal(mapped.netPrecision?.abbrev, "DAY");
  assert.equal(mapped.provider.name, "United Launch Alliance");
  assert.equal(mapped.vehicle.name, "Vulcan VC6L");
  assert.equal(mapped.mission.orbit, "Low Earth Orbit");
  assert.equal(mapped.pad.countryCode, "USA");
  assert.equal(mapped.imageUrl, "https://example.com/vulcan.jpg");
  assert.equal(mapped.webcasts[0]?.title, "Main");
  assert.equal(mapped.updates[0]?.id, 9);
  assert.equal(mapped.crewed, false);
});

test("mapLaunch drops a row with no time or status", () => {
  assert.equal(mapLaunch({ name: "Broken" }), null);
  assert.equal(mapLaunch({ name: "Broken", net: "2026-11-13T00:00:00Z" }), null);
});

test("detailRank prefers in-flight, then soon, and ignores the rest", () => {
  const mapped = mapLaunch(sample);
  assert.ok(mapped);
  const now = Date.parse("2026-11-12T12:00:00Z");
  assert.equal(detailRank(mapped, false, now), 2);

  mapped.status = { id: 6, name: "Launch in Flight", abbrev: "In Flight" };
  assert.equal(detailRank(mapped, false, now), 0);

  mapped.status = { id: 2, name: "To Be Determined", abbrev: "TBD" };
  mapped.net = "2027-06-01T00:00:00Z";
  assert.equal(detailRank(mapped, false, now), null);
  assert.equal(detailRank(mapped, true, now), 3);
});
