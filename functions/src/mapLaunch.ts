export interface NamedRef {
  id: number | null;
  name: string | null;
  abbrev: string | null;
}

export interface Webcast {
  url: string;
  priority: number | null;
  title: string | null;
}

export interface InfoUrl {
  url: string;
  title: string | null;
}

export interface LaunchUpdate {
  id: number;
  comment: string | null;
  createdOn: string | null;
  infoUrl: string | null;
}

export interface MappedLaunch {
  name: string;
  slug: string | null;
  net: string;
  windowStart: string | null;
  windowEnd: string | null;
  netPrecision: NamedRef | null;
  status: NamedRef;
  provider: { id: number | null; name: string | null };
  vehicle: { id: number | null; name: string | null };
  mission: {
    name: string | null;
    description: string | null;
    type: string | null;
    orbit: string | null;
  };
  pad: {
    id: number | null;
    name: string | null;
    locationName: string | null;
    latitude: number | null;
    longitude: number | null;
    countryCode: string | null;
  };
  crewed: boolean | null;
  suborbital: boolean | null;
  webcasts: Webcast[];
  infoUrls: InfoUrl[];
  updates: LaunchUpdate[];
  imageUrl: string | null;
  ll2LastUpdated: string | null;
}

type Json = Record<string, unknown>;

function asObject(value: unknown): Json | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Json)
    : null;
}

function asString(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function asNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function asBoolean(value: unknown): boolean | null {
  return typeof value === "boolean" ? value : null;
}

function namedRef(value: unknown): NamedRef | null {
  const object = asObject(value);
  if (!object) return null;
  const id = asNumber(object.id);
  const name = asString(object.name);
  const abbrev = asString(object.abbrev);
  if (id === null && name === null && abbrev === null) return null;
  return { id, name, abbrev };
}

function countryCode(pad: Json | null): string | null {
  const location = asObject(pad?.location);
  const fromLocation = asString(asObject(asObject(location?.country))?.alpha_3_code);
  if (fromLocation) return fromLocation;
  return asString(asObject(pad?.country)?.alpha_3_code);
}

export function mapLaunch(raw: unknown): MappedLaunch | null {
  const launch = asObject(raw);
  const name = asString(launch?.name);
  const net = asString(launch?.net);
  const status = namedRef(launch?.status);
  if (!launch || !name || !net || !status || status.id === null) return null;

  const provider = asObject(launch.launch_service_provider);
  const configuration = asObject(asObject(launch.rocket)?.configuration);
  const mission = asObject(launch.mission);
  const orbit = asObject(mission?.orbit);
  const pad = asObject(launch.pad);

  const webcasts = Array.isArray(launch.vid_urls)
    ? launch.vid_urls
        .map((item) => {
          const video = asObject(item);
          const url = asString(video?.url);
          if (!video || !url) return null;
          return {
            url,
            priority: asNumber(video.priority),
            title: asString(video.title),
          };
        })
        .filter((item): item is Webcast => item !== null)
        .sort((a, b) => (a.priority ?? 999) - (b.priority ?? 999))
    : [];

  const infoUrls = Array.isArray(launch.info_urls)
    ? launch.info_urls
        .map((item) => {
          const info = asObject(item);
          const url = asString(info?.url);
          if (!info || !url) return null;
          return { url, title: asString(info.title) };
        })
        .filter((item): item is InfoUrl => item !== null)
    : [];

  const updates = Array.isArray(launch.updates)
    ? launch.updates
        .map((item) => {
          const update = asObject(item);
          const id = asNumber(update?.id);
          if (!update || id === null) return null;
          return {
            id,
            comment: asString(update.comment),
            createdOn: asString(update.created_on),
            infoUrl: asString(update.info_url),
          };
        })
        .filter((item): item is LaunchUpdate => item !== null)
        .sort((a, b) => (b.createdOn ?? "").localeCompare(a.createdOn ?? ""))
        .slice(0, 20)
    : [];

  return {
    name,
    slug: asString(launch.slug),
    net,
    windowStart: asString(launch.window_start),
    windowEnd: asString(launch.window_end),
    netPrecision: namedRef(launch.net_precision),
    status,
    provider: {
      id: asNumber(provider?.id),
      name: asString(provider?.name),
    },
    vehicle: {
      id: asNumber(configuration?.id),
      name: asString(configuration?.name),
    },
    mission: {
      name: asString(mission?.name),
      description: asString(mission?.description),
      type: asString(mission?.type),
      orbit: asString(orbit?.name),
    },
    pad: {
      id: asNumber(pad?.id),
      name: asString(pad?.name),
      locationName: asString(asObject(pad?.location)?.name),
      latitude: asNumber(pad?.latitude),
      longitude: asNumber(pad?.longitude),
      countryCode: countryCode(pad),
    },
    crewed: isCrewed(launch, mission, asString(configuration?.name)),
    suborbital: asBoolean(launch.suborbital),
    webcasts,
    infoUrls,
    updates,
    imageUrl: imageUrl(launch),
    ll2LastUpdated: asString(launch.last_updated),
  };
}

const CREWED_MISSION_TYPES = new Set(["Human Exploration", "Tourism"]);
const CREWED_NAME = /\b(Crew-\d+|Crew Flight|Shenzhou \d+|Soyuz MS-\d+|Axiom|Ax-\d+|Polaris|Inspiration4|Fram2|Starliner-1|Gaganyaan-H\d*|Artemis I{2,}|Mengzhou-\d+)\b/i;

/**
 * LL2 2.3 does not publish a crewed flag in list mode. Prefer real crew data
 * from detailed mode, then fall back to mission type and well-known names.
 */
export function isCrewed(launch: Json, mission: Json | null, vehicleName: string | null): boolean {
  const explicit = asBoolean(launch.is_crewed) ?? asBoolean(mission?.is_crewed);
  if (explicit !== null) return explicit;
  const stages = asObject(launch.rocket)?.spacecraft_stage;
  const stageList = Array.isArray(stages) ? stages : stages ? [stages] : [];
  for (const stage of stageList) {
    const crew = asObject(stage)?.launch_crew;
    if (Array.isArray(crew) && crew.length > 0) return true;
  }
  const type = asString(mission?.type);
  if (type && CREWED_MISSION_TYPES.has(type)) return true;
  const name = `${asString(launch.name) ?? ""} ${vehicleName ?? ""}`;
  return CREWED_NAME.test(name);
}

function imageUrl(launch: Json): string | null {
  const image = asObject(launch.image);
  return asString(image?.image_url) ?? asString(image?.thumbnail_url);
}

export function detailRank(launch: MappedLaunch, followed: boolean, now: number): number | null {
  const net = Date.parse(launch.net);
  const withinSevenDays =
    Number.isFinite(net) && net - now <= 7 * 24 * 60 * 60 * 1000 && net >= now - 60 * 60 * 1000;
  const statusId = launch.status.id;
  if (statusId === 6) return 0;
  if (statusId === 5) return 1;
  if (withinSevenDays) return 2;
  if (followed) return 3;
  return null;
}
