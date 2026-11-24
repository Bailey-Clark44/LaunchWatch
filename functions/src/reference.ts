import { DocumentData, FieldValue, Firestore, Timestamp, WriteBatch } from "firebase-admin/firestore";
import { hasBudget, ll2Get, ll2Source, type Ll2Page, type Throttle } from "./ll2";

/**
 * Slow-changing Launch Library 2 data: events, stations, crews, astronauts,
 * spacewalks, programs, and dockings. Each endpoint has a freshness window and
 * the poller refreshes whichever is most overdue, spending only spare budget so
 * the launch catalog always comes first.
 */

type Json = Record<string, unknown>;

const obj = (v: unknown): Json | null => (v !== null && typeof v === "object" && !Array.isArray(v) ? (v as Json) : null);
const str = (v: unknown): string | null => (typeof v === "string" && v.length > 0 ? v : null);
const num = (v: unknown): number | null => (typeof v === "number" && Number.isFinite(v) ? v : null);
const arr = (v: unknown): Json[] => (Array.isArray(v) ? v.map(obj).filter((x): x is Json => x !== null) : []);
const ts = (v: unknown): Timestamp | null => {
  const s = str(v);
  if (!s) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : Timestamp.fromDate(d);
};

function image(v: unknown): { imageUrl: string | null; thumbUrl: string | null; imageCredit: string | null } {
  const i = obj(v);
  return { imageUrl: str(i?.image_url), thumbUrl: str(i?.thumbnail_url) ?? str(i?.image_url), imageCredit: str(i?.credit) };
}

function links(v: unknown): { url: string; title: string | null }[] {
  return arr(v)
    .map((l) => ({ url: str(l.url), title: str(l.title) ?? str(l.source), priority: num(l.priority) ?? 999 }))
    .filter((l): l is { url: string; title: string | null; priority: number } => l.url !== null)
    .sort((a, b) => a.priority - b.priority)
    .map(({ url, title }) => ({ url, title }));
}

function agencyRef(v: unknown): { id: number | null; name: string | null; abbrev: string | null } | null {
  const a = obj(v);
  if (!a) return null;
  return { id: num(a.id), name: str(a.name), abbrev: str(a.abbrev) };
}

// ---- Mappers ---------------------------------------------------------------

export function mapEvent(raw: unknown, list: "upcoming" | "recent"): { id: string; doc: Json } | null {
  const e = obj(raw);
  const id = num(e?.id);
  const name = str(e?.name);
  if (!e || id === null || !name) return null;
  const precision = obj(e.date_precision);
  return {
    id: String(id),
    doc: {
      name,
      slug: str(e.slug),
      list,
      type: str(obj(e.type)?.name),
      description: str(e.description),
      date: ts(e.date),
      precision: precision ? { abbrev: str(precision.abbrev), name: str(precision.name) } : null,
      location: str(e.location),
      webcastLive: e.webcast_live === true,
      ...image(e.image),
      webcasts: links(e.vid_urls),
      infoUrls: links(e.info_urls),
      updates: arr(e.updates)
        .map((u) => ({ id: num(u.id), comment: str(u.comment), createdOn: str(u.created_on), infoUrl: str(u.info_url) }))
        .filter((u) => u.id !== null)
        .slice(0, 10),
      agencies: arr(e.agencies).map((a) => str(a.name)).filter(Boolean),
      launchIds: arr(e.launches).map((l) => str(l.id)).filter(Boolean),
      stationIds: arr(e.spacestations).map((s) => num(s.id)).filter((x) => x !== null).map(String),
      expeditionIds: arr(e.expeditions).map((x) => num(x.id)).filter((x) => x !== null).map(String),
      programIds: arr(e.program).map((p) => num(p.id)).filter((x) => x !== null).map(String),
      astronautIds: arr(e.astronauts).map((a) => num(a.id)).filter((x) => x !== null).map(String),
    },
  };
}

export function mapAstronaut(raw: unknown): { id: string; doc: Json } | null {
  const a = obj(raw);
  const id = num(a?.id);
  const name = str(a?.name);
  if (!a || id === null || !name) return null;
  const nationality = arr(a.nationality)[0];
  return {
    id: String(id),
    doc: {
      name,
      status: str(obj(a.status)?.name),
      type: str(obj(a.type)?.name),
      agency: agencyRef(a.agency),
      nationality: nationality ? { name: str(nationality.nationality_name) ?? str(nationality.name), code: str(nationality.alpha_2_code) } : null,
      ...image(a.image),
      inSpace: a.in_space === true,
      timeInSpace: str(a.time_in_space),
      evaTime: str(a.eva_time),
      age: num(a.age),
      dateOfBirth: str(a.date_of_birth),
      dateOfDeath: str(a.date_of_death),
      bio: str(a.bio),
      wiki: str(a.wiki),
      firstFlight: ts(a.first_flight),
      lastFlight: ts(a.last_flight),
      flightsCount: num(a.flights_count),
      landingsCount: num(a.landings_count),
      spacewalksCount: num(a.spacewalks_count),
    },
  };
}

function crewList(v: unknown): { id: string; name: string; role: string | null; thumbUrl: string | null; agency: string | null; nationality: string | null }[] {
  return arr(v)
    .map((c) => {
      const a = obj(c.astronaut);
      const id = num(a?.id);
      const name = str(a?.name);
      if (!a || id === null || !name) return null;
      return {
        id: String(id),
        name,
        role: str(obj(c.role)?.role),
        thumbUrl: image(a.image).thumbUrl,
        agency: str(obj(a.agency)?.abbrev) ?? str(obj(a.agency)?.name),
        nationality: str(arr(a.nationality)[0]?.alpha_2_code),
      };
    })
    .filter((x): x is NonNullable<typeof x> => x !== null);
}

export function mapExpedition(raw: unknown): { id: string; doc: Json; astronauts: { id: string; doc: Json }[] } | null {
  const e = obj(raw);
  const id = num(e?.id);
  const name = str(e?.name);
  if (!e || id === null || !name) return null;
  const station = obj(e.spacestation);
  return {
    id: String(id),
    doc: {
      name,
      start: ts(e.start),
      end: ts(e.end),
      active: !e.end,
      stationId: num(station?.id) === null ? null : String(num(station?.id)),
      stationName: str(station?.name),
      crew: crewList(e.crew),
      patches: arr(e.mission_patches).map((p) => str(p.image_url)).filter(Boolean),
      spacewalkCount: arr(e.spacewalks).length,
    },
    astronauts: arr(e.crew).map((c) => mapAstronaut(c.astronaut)).filter((x): x is NonNullable<typeof x> => x !== null),
  };
}

function dockedCraft(docking: Json | null): { spacecraft: string | null; since: Timestamp | null; launchId: string | null; thumbUrl: string | null } | null {
  if (!docking) return null;
  const flight = obj(docking.flight_vehicle_chaser);
  const craft = obj(flight?.spacecraft);
  const payload = obj(obj(docking.payload_flight_chaser)?.payload);
  const station = obj(docking.space_station_chaser);
  const name = str(craft?.name) ?? str(payload?.name) ?? str(station?.name);
  if (!name) return null;
  return {
    spacecraft: name,
    since: ts(docking.docking),
    launchId: str(obj(flight?.launch)?.id),
    thumbUrl: image(craft?.image ?? payload?.image).thumbUrl,
  };
}

export function mapStation(raw: unknown): { id: string; doc: Json } | null {
  const s = obj(raw);
  const id = num(s?.id);
  const name = str(s?.name);
  if (!s || id === null || !name) return null;
  const status = str(obj(s.status)?.name);
  return {
    id: String(id),
    doc: {
      name,
      status,
      active: status === "Active",
      type: str(obj(s.type)?.name),
      founded: str(s.founded),
      deorbited: str(s.deorbited),
      description: str(s.description),
      orbit: str(s.orbit),
      owners: arr(s.owners).map((o) => ({ id: num(o.id), name: str(o.name), abbrev: str(o.abbrev) })),
      ...image(s.image),
      height: num(s.height),
      width: num(s.width),
      mass: num(s.mass),
      volume: num(s.volume),
      onboardCrew: num(s.onboard_crew),
      dockedVehicles: num(s.docked_vehicles),
      activeExpeditionIds: arr(s.active_expeditions).map((e) => num(e.id)).filter((x) => x !== null).map(String),
      ports: arr(s.docking_location)
        .map((p) => ({ port: str(p.name), ...(dockedCraft(obj(p.currently_docked)) ?? { spacecraft: null, since: null, launchId: null, thumbUrl: null }) }))
        .filter((p) => p.port !== null),
    },
  };
}

export function mapSpacewalk(raw: unknown): { id: string; doc: Json } | null {
  const w = obj(raw);
  const id = num(w?.id);
  const name = str(w?.name);
  if (!w || id === null || !name) return null;
  const station = obj(w.spacestation);
  const expedition = obj(w.expedition);
  return {
    id: String(id),
    doc: {
      name,
      start: ts(w.start),
      end: ts(w.end),
      duration: str(w.duration),
      location: str(w.location),
      crew: crewList(w.crew),
      stationId: num(station?.id) === null ? null : String(num(station?.id)),
      stationName: str(station?.name),
      expeditionId: num(expedition?.id) === null ? null : String(num(expedition?.id)),
      expeditionName: str(expedition?.name),
      eventId: num(obj(w.event)?.id) === null ? null : String(num(obj(w.event)?.id)),
      webcasts: links(obj(w.event)?.vid_urls),
      ...image(obj(w.event)?.image ?? station?.image),
    },
  };
}

export function mapProgram(raw: unknown): { id: string; doc: Json } | null {
  const p = obj(raw);
  const id = num(p?.id);
  const name = str(p?.name);
  if (!p || id === null || !name) return null;
  return {
    id: String(id),
    doc: {
      name,
      description: str(p.description),
      type: str(obj(p.type)?.name),
      start: ts(p.start_date),
      end: ts(p.end_date),
      infoUrl: str(p.info_url),
      wikiUrl: str(p.wiki_url),
      agencies: arr(p.agencies).map((a) => str(a.name)).filter(Boolean),
      patches: arr(p.mission_patches).map((m) => str(m.image_url)).filter(Boolean).slice(0, 12),
      ...image(p.image),
    },
  };
}

export function mapDocking(raw: unknown): { id: string; doc: Json } | null {
  const d = obj(raw);
  const id = num(d?.id);
  if (!d || id === null) return null;
  const craft = dockedCraft(d);
  const location = obj(d.docking_location);
  const station = obj(d.space_station_target) ?? obj(location?.spacestation);
  if (!craft?.spacecraft) return null;
  return {
    id: String(id),
    doc: {
      docking: ts(d.docking),
      departure: ts(d.departure),
      port: str(location?.name),
      stationId: num(station?.id) === null ? null : String(num(station?.id)),
      stationName: str(station?.name),
      spacecraft: craft.spacecraft,
      launchId: craft.launchId,
      thumbUrl: craft.thumbUrl,
    },
  };
}

export function mapArticle(raw: unknown): { id: string; doc: Json } | null {
  const a = obj(raw);
  const id = num(a?.id);
  const title = str(a?.title);
  const url = str(a?.url);
  if (!a || id === null || !title || !url) return null;
  return {
    id: String(id),
    doc: {
      title,
      url,
      imageUrl: str(a.image_url),
      site: str(a.news_site),
      summary: str(a.summary)?.replace(/\s+/g, " ").replace(/The post .* appeared first on .*$/, "").trim() ?? null,
      publishedAt: ts(a.published_at),
      featured: a.featured === true,
      launchIds: arr(a.launches).map((l) => str(l.launch_id)).filter(Boolean),
      eventIds: arr(a.events).map((e) => num(e.event_id)).filter((x) => x !== null).map(String),
    },
  };
}

// ---- Endpoints and freshness -------------------------------------------------

const HOUR = 60 * 60 * 1000;

interface Endpoint {
  key: string;
  path: string;
  ttl: number;
  write: (db: Firestore, page: Ll2Page<unknown>) => Promise<number>;
}

async function commitAll(db: Firestore, ops: ((batch: WriteBatch) => void)[]): Promise<void> {
  for (let i = 0; i < ops.length; i += 400) {
    const batch = db.batch();
    ops.slice(i, i + 400).forEach((op) => op(batch));
    await batch.commit();
  }
}

/** Writes mapped docs; removes docs of the same list that are no longer listed. */
async function replaceList(db: Firestore, collection: string, rows: { id: string; doc: Json }[], field?: string, value?: unknown): Promise<number> {
  const ref = db.collection(collection);
  const ops: ((b: WriteBatch) => void)[] = rows.map((r) => (b) => b.set(ref.doc(r.id), { ...r.doc, cachedAt: FieldValue.serverTimestamp() }, { merge: true }));
  if (field) {
    const keep = new Set(rows.map((r) => r.id));
    const old = await ref.where(field, "==", value).get();
    for (const d of old.docs) if (!keep.has(d.id)) ops.push((b) => b.delete(d.ref));
  }
  await commitAll(db, ops);
  return rows.length;
}

/** Keeps the newest [keep] docs in a collection by [orderField]. */
async function trim(db: Firestore, collection: string, orderField: string, keep: number): Promise<void> {
  const old = await db.collection(collection).orderBy(orderField, "desc").offset(keep).get();
  await commitAll(db, old.docs.map((d) => (b) => b.delete(d.ref)));
}

const mapped = <T>(page: Ll2Page<unknown>, fn: (r: unknown) => T | null): T[] => page.results.map(fn).filter((x): x is T => x !== null);

export const ENDPOINTS: Endpoint[] = [
  {
    key: "eventsUpcoming",
    path: "/events/upcoming/?limit=40&mode=detailed&format=json",
    ttl: 2 * HOUR,
    write: (db, page) => replaceList(db, "events", mapped(page, (r) => mapEvent(r, "upcoming")), "list", "upcoming"),
  },
  {
    key: "stations",
    path: "/space_stations/?limit=30&mode=detailed&format=json",
    ttl: 3 * HOUR,
    write: (db, page) => replaceList(db, "stations", mapped(page, mapStation)),
  },
  {
    key: "expeditions",
    path: "/expeditions/?is_active=true&mode=detailed&limit=10&format=json",
    ttl: 3 * HOUR,
    write: async (db, page) => {
      const rows = mapped(page, mapExpedition);
      await replaceList(db, "expeditions", rows.map(({ id, doc }) => ({ id, doc })), "active", true);
      await replaceList(db, "astronauts", rows.flatMap((r) => r.astronauts));
      return rows.length;
    },
  },
  {
    key: "inSpace",
    path: "/astronauts/?in_space=true&limit=60&mode=normal&format=json",
    ttl: 4 * HOUR,
    write: async (db, page) => {
      const rows = mapped(page, mapAstronaut);
      const keep = new Set(rows.map((r) => r.id));
      const stale = await db.collection("astronauts").where("inSpace", "==", true).get();
      const ops: ((b: WriteBatch) => void)[] = stale.docs.filter((d) => !keep.has(d.id)).map((d) => (b) => b.set(d.ref, { inSpace: false }, { merge: true }));
      await commitAll(db, ops);
      return replaceList(db, "astronauts", rows);
    },
  },
  {
    key: "dockings",
    path: "/docking_events/?limit=25&ordering=-docking&mode=normal&format=json",
    ttl: 6 * HOUR,
    write: async (db, page) => {
      const n = await replaceList(db, "dockings", mapped(page, mapDocking));
      await trim(db, "dockings", "docking", 60);
      return n;
    },
  },
  {
    key: "eventsRecent",
    path: "/events/previous/?limit=20&mode=detailed&format=json",
    ttl: 12 * HOUR,
    write: (db, page) => replaceList(db, "events", mapped(page, (r) => mapEvent(r, "recent")), "list", "recent"),
  },
  {
    key: "spacewalks",
    path: "/spacewalks/?limit=20&ordering=-start&mode=normal&format=json",
    ttl: 12 * HOUR,
    write: async (db, page) => {
      const n = await replaceList(db, "spacewalks", mapped(page, mapSpacewalk));
      await trim(db, "spacewalks", "start", 40);
      return n;
    },
  },
  {
    key: "programs",
    path: "/programs/?limit=60&mode=normal&format=json",
    ttl: 7 * 24 * HOUR,
    write: (db, page) => replaceList(db, "programs", mapped(page, mapProgram)),
  },
];

/** Most overdue first. Never-fetched endpoints count as infinitely overdue. */
export function dueEndpoints(fetched: Record<string, number | undefined>, now: number, endpoints = ENDPOINTS): Endpoint[] {
  return endpoints
    .map((e) => ({ e, overdue: fetched[e.key] === undefined ? Infinity : now - fetched[e.key]! - e.ttl }))
    .filter((x) => x.overdue >= 0)
    .sort((a, b) => b.overdue - a.overdue)
    .map((x) => x.e);
}

/** Calls are spent only while this many remain for launch polls in the hour. */
const RESERVE = 6;

export async function runReferencePoll(db: Firestore, maxCalls = 3, now = Date.now()): Promise<string[]> {
  const metaRef = db.doc("meta/reference");
  const meta = (await metaRef.get()).data() ?? {};
  const fetched: Record<string, number | undefined> = {};
  for (const e of ENDPOINTS) {
    const at = meta[e.key];
    if (at instanceof Timestamp) fetched[e.key] = at.toMillis();
  }
  const due = dueEndpoints(fetched, now);
  const done: string[] = [];
  for (const endpoint of due) {
    if (done.length >= maxCalls) break;
    const throttle = await ll2Get<Throttle>("/api-throttle/?format=json");
    if (!hasBudget(throttle, RESERVE)) break;
    try {
      const page = await ll2Get<Ll2Page<unknown>>(endpoint.path);
      const count = await endpoint.write(db, page);
      await metaRef.set({ [endpoint.key]: FieldValue.serverTimestamp(), [`${endpoint.key}Count`]: count, source: ll2Source() }, { merge: true });
      done.push(endpoint.key);
    } catch (error) {
      console.warn(`Reference endpoint ${endpoint.key} failed`, error);
      break;
    }
  }
  return done;
}

// ---- News (Spaceflight News API) ----------------------------------------------

const SNAPI = "https://api.spaceflightnewsapi.net/v4";

export async function runNewsPoll(db: Firestore): Promise<number> {
  const response = await fetch(`${SNAPI}/articles/?limit=50&ordering=-published_at`, {
    headers: { Accept: "application/json", "User-Agent": process.env.LL2_USER_AGENT ?? "LaunchWatch/0.2" },
  });
  if (!response.ok) throw new Error(`SNAPI ${response.status}`);
  const page = (await response.json()) as Ll2Page<unknown>;
  const rows = page.results.map(mapArticle).filter((x): x is NonNullable<typeof x> => x !== null);
  await replaceList(db, "news", rows);
  await trim(db, "news", "publishedAt", 200);
  await db.doc("meta/reference").set({ news: FieldValue.serverTimestamp(), newsCount: rows.length }, { merge: true });
  return rows.length;
}

export type { DocumentData };
