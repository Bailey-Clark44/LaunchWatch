import { DocumentData, FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { detailRank, mapLaunch, type MappedLaunch } from "./mapLaunch";
import { hasBudget, ll2Get, ll2Source, type Ll2Page, type Throttle } from "./ll2";
import { diffLaunch, loadFollows, notifyFollowers, sendReminders, snapshotFromDoc, type LaunchChange, type LaunchSnapshot } from "./notify";

const UPCOMING_PATH =
  "/launches/upcoming/?mode=normal&limit=100&ordering=net&hide_recent_previous=true&format=json";
const PREVIOUS_PATH =
  "/launches/previous/?mode=normal&limit=20&ordering=-net&format=json";
const HISTORICAL_COUNT_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const HISTORICAL_COUNT_INTERVAL_MS = 25 * 60 * 1000;

type HistoricalCountType = "vehicle" | "organisation";

interface HistoricalCountTarget {
  type: HistoricalCountType;
  id: number;
  name: string;
}

interface LauncherConfigurationStats {
  total_launch_count?: number;
  successful_launches?: number;
  failed_launches?: number;
  pending_launches?: number;
  maiden_flight?: string | null;
  active?: boolean;
}

export interface PollResult {
  skipped: "rate_limit" | "not_hot" | null;
  notified?: number;
  upcoming: number;
  recent: number;
  detailed: number;
  source: "lldev" | "ll2";
}

interface PollOptions {
  detailed: boolean;
  onlyIfHot?: boolean;
}

type LaunchRecord = Record<string, unknown>;

let firestoreConfigured = false;

function firestore() {
  if (getApps().length === 0) {
    initializeApp({
      projectId: process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "launchwatch-dev",
    });
  }
  const db = getFirestore();
  if (!firestoreConfigured) {
    db.settings({ ignoreUndefinedProperties: true });
    firestoreConfigured = true;
  }
  return db;
}

function timestamp(iso: string | null): Timestamp | null {
  if (!iso) return null;
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? null : Timestamp.fromDate(date);
}

function toDocument(launch: MappedLaunch, list: "upcoming" | "recent"): LaunchRecord {
  return {
    name: launch.name,
    slug: launch.slug,
    list,
    net: timestamp(launch.net),
    windowStart: timestamp(launch.windowStart),
    windowEnd: timestamp(launch.windowEnd),
    netPrecision: launch.netPrecision,
    status: launch.status,
    provider: launch.provider,
    vehicle: launch.vehicle,
    mission: launch.mission,
    pad: launch.pad,
    crewed: launch.crewed,
    suborbital: launch.suborbital,
    webcasts: launch.webcasts,
    infoUrls: launch.infoUrls,
    updates: launch.updates,
    imageUrl: launch.imageUrl,
    ll2LastUpdated: timestamp(launch.ll2LastUpdated),
  };
}

async function catalogIsHot(): Promise<boolean> {
  const snap = await firestore().collection("launches").where("list", "==", "upcoming").get();
  const now = Date.now();
  const hour = 60 * 60 * 1000;
  return snap.docs.some((doc) => {
    const statusId = doc.get("status.id");
    if (statusId === 6) return true;
    const net = doc.get("net") as Timestamp | undefined;
    if (!(net instanceof Timestamp)) return false;
    const until = net.toDate().getTime() - now;
    // A Go or Hold launch is only "hot" in the final day. Most of the
    // catalog is Go weeks out, which used to keep this poll running nonstop.
    if ((statusId === 1 || statusId === 5) && until <= 24 * hour && until >= -2 * hour) return true;
    return Math.abs(until) <= 6 * hour;
  });
}

const DETAIL_FIELDS = ["webcasts", "infoUrls", "updates"] as const;
const NET_HISTORY_LIMIT = 20;

function sameMillis(a: unknown, b: unknown): boolean {
  const ms = (v: unknown) => (v instanceof Timestamp ? v.toMillis() : null);
  return ms(a) === ms(b);
}

async function writeCatalog(
  rows: { id: string; list: "upcoming" | "recent"; launch: MappedLaunch; detailed: boolean }[],
): Promise<{ changes: LaunchChange[]; snapshots: Map<string, LaunchSnapshot> }> {
  const changes: LaunchChange[] = [];
  const snapshots = new Map<string, LaunchSnapshot>();
  if (rows.length === 0) return { changes, snapshots };
  const db = firestore();
  const refs = rows.map((row) => db.collection("launches").doc(row.id));
  const existing = new Map<string, DocumentData>();
  for (let i = 0; i < refs.length; i += 100) {
    const chunk = refs.slice(i, i + 100);
    const found = await db.getAll(...chunk);
    found.forEach((doc) => {
      if (doc.exists) existing.set(doc.id, doc.data() ?? {});
    });
  }

  for (let i = 0; i < rows.length; i += 400) {
    const batch = db.batch();
    for (const row of rows.slice(i, i + 400)) {
      const previousDoc = existing.get(row.id);
      const previousUpdates = Array.isArray(previousDoc?.updates) ? previousDoc.updates : [];
      const document = toDocument(row.launch, row.list);
      // List-mode responses do not carry webcasts, links, or updates. Keep the
      // last detailed copy instead of overwriting it with an empty list.
      if (!row.detailed && previousDoc) {
        for (const field of DETAIL_FIELDS) {
          const fresh = document[field];
          if (Array.isArray(fresh) && fresh.length === 0 && Array.isArray(previousDoc[field])) {
            document[field] = previousDoc[field];
          }
        }
      }
      // Slip history: one entry each time the NET, its precision, or the status moves.
      const history: Record<string, unknown>[] = Array.isArray(previousDoc?.netHistory) ? [...previousDoc.netHistory] : [];
      const last = history[history.length - 1];
      const precisionAbbrev = row.launch.netPrecision?.abbrev ?? null;
      if (
        !last ||
        !sameMillis(last.net, document.net) ||
        last.precision !== precisionAbbrev ||
        last.statusId !== row.launch.status.id
      ) {
        history.push({
          net: document.net,
          precision: precisionAbbrev,
          statusId: row.launch.status.id,
          recordedAt: Timestamp.now(),
        });
      }
      document.netHistory = history.slice(-NET_HISTORY_LIMIT);

      const before = snapshotFromDoc(previousDoc);
      const after = snapshotFromDoc(document);
      if (after) {
        snapshots.set(row.id, after);
        // Update-only changes are only trustworthy when this row was fetched in detail.
        const change = diffLaunch(row.id, before, row.detailed ? after : { ...after, updateIds: before?.updateIds ?? [] });
        if (change) changes.push(change);
      }

      batch.set(db.collection("launches").doc(row.id), {
        ...document,
        cachedAt: FieldValue.serverTimestamp(),
        detailFetchedAt: row.detailed ? FieldValue.serverTimestamp() : previousDoc?.detailFetchedAt ?? null,
        previous: previousDoc
          ? {
              net: previousDoc.net ?? null,
              statusId: previousDoc.status?.id ?? null,
              updateIds: previousUpdates
                .map((update: { id?: number }) => update.id)
                .filter((id: number | undefined): id is number => typeof id === "number"),
            }
          : null,
      });
    }
    await batch.commit();
  }
  return { changes, snapshots };
}

async function prune(
  upcomingIds: Set<string>,
  recentIds: Set<string>,
  followed: Set<string>,
): Promise<void> {
  const db = firestore();
  for (const list of ["upcoming", "recent"] as const) {
    const keep = list === "upcoming" ? upcomingIds : recentIds;
    const snap = await db.collection("launches").where("list", "==", list).get();
    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db.batch();
      let writes = 0;
      for (const doc of snap.docs.slice(i, i + 400)) {
        if (keep.has(doc.id)) continue;
        if (followed.has(doc.id)) {
          batch.set(doc.ref, { list: "archive" }, { merge: true });
        } else {
          batch.delete(doc.ref);
        }
        writes += 1;
      }
      if (writes > 0) await batch.commit();
    }
  }
}

async function chooseDetailed(
  launches: Map<string, MappedLaunch>,
  followed: Set<string>,
  budgetLeft: number,
): Promise<string[]> {
  const now = Date.now();
  return [...launches.entries()]
    .map(([id, launch]) => ({ id, launch, rank: detailRank(launch, followed.has(id), now) }))
    .filter((item): item is { id: string; launch: MappedLaunch; rank: number } => item.rank !== null)
    .sort((a, b) => a.rank - b.rank || Date.parse(a.launch.net) - Date.parse(b.launch.net))
    .slice(0, Math.min(4, Math.max(0, budgetLeft)))
    .map((item) => item.id);
}

function historicalCountTargetId(target: HistoricalCountTarget): string {
  return `${target.type}_${target.id}`;
}

async function nextHistoricalCountTarget(
  launches: Pick<MappedLaunch, "provider" | "vehicle">[],
  ignoreInterval = false,
): Promise<{ target: HistoricalCountTarget; cursor: string | null } | null> {
  const targets = new Map<string, HistoricalCountTarget>();
  for (const launch of launches) {
    const provider = launch.provider;
    if (provider.id !== null && provider.name) {
      const target = { type: "organisation" as const, id: provider.id, name: provider.name };
      targets.set(historicalCountTargetId(target), target);
    }
    const vehicle = launch.vehicle;
    if (vehicle.id !== null && vehicle.name) {
      const target = { type: "vehicle" as const, id: vehicle.id, name: vehicle.name };
      targets.set(historicalCountTargetId(target), target);
    }
  }
  if (targets.size === 0) return null;

  const db = firestore();
  const entries = [...targets.entries()].sort(([a], [b]) => a.localeCompare(b));
  const staleTargets: HistoricalCountTarget[] = [];
  for (let i = 0; i < entries.length; i += 100) {
    const chunk = entries.slice(i, i + 100);
    const refs = chunk.map(([id]) => db.collection("catalogStats").doc(id));
    const docs = await db.getAll(...refs);
    for (let j = 0; j < docs.length; j += 1) {
      const checkedAt = docs[j].get("checkedAt");
      const isFresh =
        docs[j].exists &&
        checkedAt instanceof Timestamp &&
        Date.now() - checkedAt.toMillis() < HISTORICAL_COUNT_TTL_MS;
      if (!isFresh) staleTargets.push(chunk[j][1]);
    }
  }
  if (staleTargets.length === 0) return null;

  const meta = await db.doc("meta/catalogStats").get();
  const lastCountAt = meta.get("lastCountAt");
  if (!ignoreInterval && lastCountAt instanceof Timestamp && Date.now() - lastCountAt.toMillis() < HISTORICAL_COUNT_INTERVAL_MS) {
    return null;
  }
  const cursor = typeof meta.get("cursor") === "string" ? (meta.get("cursor") as string) : null;
  staleTargets.sort((a, b) => historicalCountTargetId(a).localeCompare(historicalCountTargetId(b)));
  const next = cursor === null
    ? staleTargets[0]
    : staleTargets.find((target) => historicalCountTargetId(target) > cursor) ?? staleTargets[0];
  return { target: next, cursor };
}

async function refreshOneHistoricalCount(
  launches: Pick<MappedLaunch, "provider" | "vehicle">[],
  ignoreInterval = false,
): Promise<boolean> {
  const next = await nextHistoricalCountTarget(launches, ignoreInterval);
  if (!next) return false;

  let pastLaunches: number;
  let extraStats: Record<string, unknown> = {};
  if (next.target.type === "vehicle") {
    const stats = await ll2Get<LauncherConfigurationStats>(
      `/launcher_configurations/${next.target.id}/?mode=normal&format=json`,
    );
    if (!Number.isSafeInteger(stats.total_launch_count) || (stats.total_launch_count ?? -1) < 0) {
      throw new Error(`LL2 returned an invalid vehicle launch total for ${next.target.id}`);
    }
    pastLaunches = stats.total_launch_count!;
    extraStats = {
      successfulLaunches: stats.successful_launches ?? null,
      failedLaunches: stats.failed_launches ?? null,
      pendingLaunches: stats.pending_launches ?? null,
      maidenFlight: stats.maiden_flight ?? null,
      active: stats.active ?? null,
    };
  } else {
    const page = await ll2Get<Ll2Page<unknown>>(
      `/launches/previous/?mode=normal&limit=1&ordering=-net&lsp__id=${next.target.id}&format=json`,
    );
    if (!Number.isSafeInteger(page.count) || page.count < 0) {
      throw new Error(`LL2 returned an invalid historical count for organisation ${next.target.id}`);
    }
    pastLaunches = page.count;
  }

  const db = firestore();
  const id = historicalCountTargetId(next.target);
  await Promise.all([
    db.collection("catalogStats").doc(id).set({
      type: next.target.type,
      entityId: next.target.id,
      name: next.target.name,
      pastLaunches,
      ...extraStats,
      checkedAt: FieldValue.serverTimestamp(),
      source: ll2Source(),
    }, { merge: true }),
    db.doc("meta/catalogStats").set({
      cursor: id,
      lastEntity: next.target.name,
      lastCountAt: FieldValue.serverTimestamp(),
      source: ll2Source(),
    }, { merge: true }),
  ]);
  return true;
}

export async function runPoll(options: PollOptions): Promise<PollResult> {
  const db = firestore();
  const source = ll2Source();
  await db.doc("meta/catalog").set(
    { lastAttemptAt: FieldValue.serverTimestamp(), source },
    { merge: true },
  );

  if (options.onlyIfHot && !(await catalogIsHot())) {
    return { skipped: "not_hot", upcoming: 0, recent: 0, detailed: 0, source };
  }

  try {
    const throttle = await ll2Get<Throttle>("/api-throttle/?format=json");
    const listCalls = 2;
    if (!hasBudget(throttle, listCalls)) {
      await db.doc("meta/catalog").set(
        { lastSkipReason: "rate_limit", source },
        { merge: true },
      );
      return { skipped: "rate_limit", upcoming: 0, recent: 0, detailed: 0, source };
    }

    const [upcomingPage, previousPage] = await Promise.all([
      ll2Get<Ll2Page<unknown>>(UPCOMING_PATH),
      ll2Get<Ll2Page<unknown>>(PREVIOUS_PATH),
    ]);

    const upcoming = new Map<string, MappedLaunch>();
    const recent = new Map<string, MappedLaunch>();
    for (const raw of upcomingPage.results) {
      const id = typeof (raw as { id?: unknown }).id === "string" ? (raw as { id: string }).id : null;
      const mapped = id ? mapLaunch(raw) : null;
      if (id && mapped) upcoming.set(id, mapped);
    }
    for (const raw of previousPage.results) {
      const id = typeof (raw as { id?: unknown }).id === "string" ? (raw as { id: string }).id : null;
      const mapped = id ? mapLaunch(raw) : null;
      if (id && mapped && !upcoming.has(id)) recent.set(id, mapped);
    }

    let countCalls = 0;
    if (!options.detailed && hasBudget(throttle, listCalls + 1)) {
      try {
        countCalls = (await refreshOneHistoricalCount([...upcoming.values(), ...recent.values()])) ? 1 : 0;
      } catch (error) {
        // Historical counts are useful profile data; a failed count must not block the launch feed.
        countCalls = 1;
        console.warn("Could not refresh one LL2 historical count", error);
      }
    }

    const follows = await loadFollows(db);
    const followed = new Set(follows.keys());
    const detailedIds = options.detailed
      ? await chooseDetailed(
          new Map([...upcoming, ...recent]),
          followed,
          throttle.your_request_limit - throttle.current_use - listCalls - 1 - countCalls,
        )
      : [];

    for (const id of detailedIds) {
      const raw = await ll2Get<unknown>(`/launches/${id}/?mode=detailed&format=json`);
      const mapped = mapLaunch(raw);
      if (!mapped) continue;
      if (upcoming.has(id)) upcoming.set(id, mapped);
      else recent.set(id, mapped);
    }

    const detailed = new Set(detailedIds);
    const { changes, snapshots } = await writeCatalog([
      ...[...upcoming].map(([id, launch]) => ({
        id,
        list: "upcoming" as const,
        launch,
        detailed: detailed.has(id),
      })),
      ...[...recent].map(([id, launch]) => ({
        id,
        list: "recent" as const,
        launch,
        detailed: detailed.has(id),
      })),
    ]);
    await prune(new Set(upcoming.keys()), new Set(recent.keys()), followed);

    let notified = 0;
    try {
      notified += await notifyFollowers(db, changes, follows);
      notified += await sendReminders(db, snapshots, follows);
    } catch (error) {
      // Alerts must never block the catalog refresh.
      console.warn("Could not send launch alerts", error);
    }

    await db.doc("meta/catalog").set(
      {
        updatedAt: FieldValue.serverTimestamp(),
        lastSkipReason: null,
        source,
        upcomingCount: upcoming.size,
        recentCount: recent.size,
      },
      { merge: true },
    );

    return {
      skipped: null,
      notified,
      upcoming: upcoming.size,
      recent: recent.size,
      detailed: detailedIds.length,
      source,
    };
  } catch (error) {
    await db.doc("meta/catalog").set({ lastSkipReason: "ll2_error", source }, { merge: true });
    throw error;
  }
}

/**
 * Fills every missing vehicle and organisation total in one run, within the
 * LL2 budget. The scheduled poll only refreshes one entity per 25 minutes,
 * which takes about half a day to cover a fresh catalog.
 */
export async function backfillHistoricalCounts(maxCalls: number): Promise<number> {
  const snap = await firestore().collection("launches").get();
  const launches = snap.docs.map((doc) => ({
    provider: { id: doc.get("provider.id") ?? null, name: doc.get("provider.name") ?? null },
    vehicle: { id: doc.get("vehicle.id") ?? null, name: doc.get("vehicle.name") ?? null },
  }));
  let done = 0;
  while (done < maxCalls) {
    const throttle = await ll2Get<Throttle>("/api-throttle/?format=json");
    if (!hasBudget(throttle, 1)) {
      console.log(`LL2 budget exhausted; try again in ${throttle.next_use_secs}s`);
      break;
    }
    if (!(await refreshOneHistoricalCount(launches, true))) break;
    done += 1;
  }
  return done;
}
