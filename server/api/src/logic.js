// Pure rules for reports: no database, no network, so it is easy to test.
import { createHmac } from 'node:crypto';

/** Server is the source of truth for how long each alert lives without confirmations. */
export const REPORT_TYPES = {
  police: 45 * 60,
  camera: 30 * 24 * 3600,
  flood: 3 * 3600,
  pothole: 7 * 24 * 3600,
  brokenLorry: 2 * 3600,
  jam: 30 * 60,
  crash: 3600,
};

// Rough box around Malaysia. Cheap junk filter, not a border.
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

export function parseNearbyQuery(q) {
  const lat = Number(q?.lat);
  const lng = Number(q?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || !inMalaysia(lat, lng)) {
    return { ok: false, error: 'lat and lng are required and must be in Malaysia.' };
  }
  const km = q.r === undefined ? 10 : Number(q.r);
  if (!Number.isFinite(km) || km <= 0) return { ok: false, error: 'r must be a positive number of km.' };
  return { ok: true, value: { lat, lng, radiusM: Math.min(km, 25) * 1000 } };
}

/**
 * "Masih ada?" votes.
 * confirm: alert lives at least half its normal lifetime from now, capped at 3x from creation.
 * deny: two more denies than confirms and it expires immediately.
 */
export function applyVote(r, vote, now = new Date()) {
  let { confirms, denies } = r;
  let expiresAt = new Date(r.expiresAt);
  const ttlMs = r.ttlSeconds * 1000;
  if (vote === 'confirm') {
    confirms += 1;
    const extended = new Date(now.getTime() + ttlMs / 2);
    const cap = new Date(new Date(r.createdAt).getTime() + ttlMs * 3);
    const target = extended > expiresAt ? extended : expiresAt;
    expiresAt = target > cap ? cap : target;
  } else {
    denies += 1;
    if (denies - confirms >= 2) expiresAt = new Date(now);
  }
  return { confirms, denies, expiresAt };
}

/**
 * Privacy: we never store the device id. Reporter hash changes daily (rate limits only).
 * Voter hash is different for every report, so votes cannot be linked across reports.
 */
export function reporterHash(secret, deviceId, now = new Date()) {
  const day = now.toISOString().slice(0, 10);
  return createHmac('sha256', secret).update(`r:${day}:${deviceId}`).digest('hex').slice(0, 32);
}

export function voterHash(secret, deviceId, reportId) {
  return createHmac('sha256', secret).update(`v:${reportId}:${deviceId}`).digest('hex').slice(0, 32);
}

export function validDeviceId(id) {
  return typeof id === 'string' && /^[A-Za-z0-9-]{16,64}$/.test(id);
}

/** Simple in-memory limiter. One server instance only; use Redis if you scale out. */
export class RateLimiter {
  constructor({ limit, windowMs }) {
    this.limit = limit;
    this.windowMs = windowMs;
    this.hits = new Map();
  }
  allow(key, nowMs = Date.now()) {
    const recent = (this.hits.get(key) ?? []).filter((t) => nowMs - t < this.windowMs);
    if (recent.length >= this.limit) {
      this.hits.set(key, recent);
      return false;
    }
    recent.push(nowMs);
    this.hits.set(key, recent);
    return true;
  }
  sweep(nowMs = Date.now()) {
    for (const [k, v] of this.hits) {
      if (!v.some((t) => nowMs - t < this.windowMs)) this.hits.delete(k);
    }
  }
}
