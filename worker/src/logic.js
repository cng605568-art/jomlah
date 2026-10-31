// Pure rules for reports: no database, no network, so they are easy to test.
// Ported from server/api/src/logic.js (the self-hosted version) to run on Cloudflare Workers.

/** How long each alert lives without confirmations, in seconds. The server decides, not the app. */
export const REPORT_TYPES = {
  police: 45 * 60,
  camera: 30 * 24 * 3600,
  flood: 3 * 3600,
  pothole: 7 * 24 * 3600,
  brokenLorry: 2 * 3600,
  jam: 30 * 60,
  crash: 3600,
};

/** Rate limits, per 10 minutes. */
export const LIMITS = {
  windowMs: 10 * 60 * 1000,
  reportsPerDevice: 10, // one phone
  reportsPerArea: 30, // one ~11 km square, all phones together (blunts floods of fake reports)
  votesPerDevice: 60,
  speedBatchesPerDevice: 20, // the app sends one batch every 2 minutes while navigating
};

/** The same alert type within this distance is the same alert: a confirmation, not a new one. */
export const SAME_ALERT_M = 100;

// Rough box around Malaysia. A cheap junk filter, not a border.
const BOX = { minLat: 0.8, maxLat: 7.4, minLng: 99.6, maxLng: 119.3 };

export function inMalaysia(lat, lng) {
  return lat >= BOX.minLat && lat <= BOX.maxLat && lng >= BOX.minLng && lng <= BOX.maxLng;
}

const isNum = (v) => typeof v === 'number' && Number.isFinite(v);

export function validateNewReport(body) {
  if (!body || typeof body !== 'object') return { ok: false, error: 'Body must be JSON.' };
  const { type, lat, lng, accuracy_m: accuracy } = body;
  if (typeof type !== 'string' || !Object.hasOwn(REPORT_TYPES, type)) {
    return { ok: false, error: 'Unknown report type.' };
  }
  if (!isNum(lat) || !isNum(lng)) return { ok: false, error: 'lat and lng must be numbers.' };
  if (!inMalaysia(lat, lng)) return { ok: false, error: 'Location is outside Malaysia.' };
  if (accuracy !== undefined && (!isNum(accuracy) || accuracy > 100)) {
    return { ok: false, error: 'GPS accuracy too low for a report.' };
  }
  return { ok: true, value: { type, lat, lng, ttlSeconds: REPORT_TYPES[type] } };
}

/** ?lat=&lng=&r= (km, default 10, at most 25). */
export function parseNearbyQuery(params) {
  const lat = Number(params.get('lat'));
  const lng = Number(params.get('lng'));
  if (!params.has('lat') || !params.has('lng') || !Number.isFinite(lat) || !Number.isFinite(lng) || !inMalaysia(lat, lng)) {
    return { ok: false, error: 'lat and lng are required and must be in Malaysia.' };
  }
  const km = params.has('r') ? Number(params.get('r')) : 10;
  if (!Number.isFinite(km) || km <= 0) return { ok: false, error: 'r must be a positive number of km.' };
  return { ok: true, value: { lat, lng, radiusM: Math.min(km, 25) * 1000 } };
}

/**
 * "Masih ada?" votes.
 * confirm: the alert lives at least half its normal lifetime from now, capped at 3x from creation.
 * deny: two more denies than confirms and it expires immediately.
 * Times are milliseconds.
 */
export function applyVote(r, vote, nowMs = Date.now()) {
  let { confirms, denies } = r;
  let expiresAt = r.expiresAt;
  const ttlMs = r.ttlSeconds * 1000;
  if (vote === 'confirm') {
    confirms += 1;
    const extended = nowMs + ttlMs / 2;
    const cap = r.createdAt + ttlMs * 3;
    expiresAt = Math.min(Math.max(extended, expiresAt), cap);
  } else {
    denies += 1;
    if (denies - confirms >= 2) expiresAt = nowMs;
  }
  return { confirms, denies, expiresAt };
}

export function validDeviceId(id) {
  return typeof id === 'string' && /^[A-Za-z0-9-]{16,64}$/.test(id);
}

export function validReportId(id) {
  return typeof id === 'string' && /^[0-9a-f-]{36}$/i.test(id);
}

/** HMAC-SHA256 as 32 hex characters (Web Crypto: works on Workers and in Node). */
export async function hmacHex(secret, message) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(message)));
  return [...sig].map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 32);
}

/**
 * Privacy: the device id is never stored. The reporter hash changes every day (it is only used for
 * rate limits). The voter hash is different for every report, so votes cannot be linked together.
 */
export const reporterHash = (secret, deviceId, nowMs = Date.now()) =>
  hmacHex(secret, `r:${new Date(nowMs).toISOString().slice(0, 10)}:${deviceId}`);

export const voterHash = (secret, deviceId, reportId) => hmacHex(secret, `v:${reportId}:${deviceId}`);

// ---- Where things are ----

const CELL_DEG = 0.1;

/** The 0.1 degree square a point is in, as one number (fast to index). */
export function cellOf(lat, lng) {
  return Math.floor(lat / CELL_DEG) * 10000 + Math.floor(lng / CELL_DEG);
}

/** Every square within [radiusM] of the point (the point's square and enough neighbours). */
export function cellsAround(lat, lng, radiusM) {
  const latSteps = Math.ceil(radiusM / 111_320 / CELL_DEG);
  const lngSteps = Math.ceil(radiusM / (111_320 * Math.cos((lat * Math.PI) / 180)) / CELL_DEG);
  const row = Math.floor(lat / CELL_DEG);
  const col = Math.floor(lng / CELL_DEG);
  const out = [];
  for (let r = row - latSteps; r <= row + latSteps; r++) {
    for (let c = col - lngSteps; c <= col + lngSteps; c++) out.push(r * 10000 + c);
  }
  return out;
}

/** Metres between two points. */
export function distanceM(lat1, lng1, lat2, lng2) {
  const rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad;
  const dLng = (lng2 - lng1) * rad;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.sqrt(a));
}

// ---- Live traffic ----

/** Size of a traffic stretch: a square of 0.0015 degrees (about 165 m). */
export const SEG_DEG = 0.0015;
/** A stretch's speed is only shown once at least this many readings agree (one car is not traffic). */
export const MIN_READINGS = 2;
export const SPEED_BUCKET_MS = 5 * 60 * 1000;
export const TRAFFIC_WINDOW_MS = 15 * 60 * 1000;
export const MAX_SAMPLES = 10;

/** 0 = north, 1 = north-east ... 7 = north-west. */
export const dirOf = (headingDeg) => Math.round((((headingDeg % 360) + 360) % 360) / 45) % 8;

/** The stretch a reading belongs to: its key, centre and direction. */
export function segmentOf(lat, lng, headingDeg) {
  const row = Math.floor(lat / SEG_DEG);
  const col = Math.floor(lng / SEG_DEG);
  const dir = dirOf(headingDeg);
  const cLat = (row + 0.5) * SEG_DEG;
  const cLng = (col + 0.5) * SEG_DEG;
  return { seg: `${row}:${col}:${dir}`, lat: +cLat.toFixed(6), lng: +cLng.toFixed(6), dir, cell: cellOf(cLat, cLng) };
}

/** {samples: [{lat, lng, heading, kmh}, ...]}: 1 to 10 readings, each in Malaysia and plausible. */
export function validateSpeeds(body) {
  const samples = body?.samples;
  if (!Array.isArray(samples) || samples.length === 0 || samples.length > MAX_SAMPLES) {
    return { ok: false, error: `samples must be a list of 1 to ${MAX_SAMPLES} readings.` };
  }
  const out = [];
  for (const s of samples) {
    const { lat, lng, heading, kmh } = s ?? {};
    if (![lat, lng, heading, kmh].every(isNum)) return { ok: false, error: 'Each reading needs lat, lng, heading and kmh.' };
    if (!inMalaysia(lat, lng)) return { ok: false, error: 'Reading outside Malaysia.' };
    if (heading < 0 || heading > 360 || kmh < 0 || kmh > 200) return { ok: false, error: 'Reading out of range.' };
    out.push({ lat, lng, heading, kmh });
  }
  return { ok: true, value: out };
}
