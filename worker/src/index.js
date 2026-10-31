// Jomlah shared road alerts, on Cloudflare Workers with a D1 (SQLite) database.
//
//   GET  /healthz                        is the server up?
//   GET  /v1/reports?lat=&lng=&r=        live alerts near a point (r in km, default 10, max 25)
//   POST /v1/reports                     {type, lat, lng}            new alert (or confirms a twin)
//   POST /v1/reports/:id/vote            {vote: "confirm" | "deny"}  "Masih ada?"
//   POST /v1/speeds                      {samples: [{lat, lng, heading, kmh}]}  live traffic readings
//   GET  /v1/traffic?lat=&lng=&r=        average speeds on stretches near a point (last 15 min)
//
// Every write needs an X-Device-Id header: the app's random, weekly-changing id. It is never
// stored; see logic.js. Same API as the self-hosted server in server/api, so the app does not care
// which one it talks to.

import {
  applyVote, cellOf, cellsAround, distanceM, LIMITS, MIN_READINGS, parseNearbyQuery, REPORT_TYPES,
  reporterHash, SAME_ALERT_M, segmentOf, SPEED_BUCKET_MS, TRAFFIC_WINDOW_MS, validateNewReport,
  validateSpeeds, validDeviceId, validReportId, voterHash,
} from './logic.js';

const COLUMNS = 'id, type, lat, lng, created_at, expires_at, confirms, denies';

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });

const toJson = (r) => ({
  id: r.id,
  type: r.type,
  lat: r.lat,
  lng: r.lng,
  created_at: new Date(r.created_at).toISOString(),
  expires_at: new Date(r.expires_at).toISOString(),
  confirms: r.confirms,
  denies: r.denies,
});

async function readJson(request) {
  const text = await request.text();
  if (text.length > 4096) return undefined;
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

/** Counts [key] in the last window and records one more hit. True when still under [limit]. */
async function underLimit(db, key, limit, now) {
  const row = await db.prepare('SELECT COUNT(*) AS n FROM hits WHERE key = ? AND at > ?').bind(key, now - LIMITS.windowMs).first();
  if ((row?.n ?? 0) >= limit) return false;
  await db.prepare('INSERT INTO hits (key, at) VALUES (?, ?)').bind(key, now).run();
  return true;
}

/** Live alerts of [type] near the point, nearest first. */
async function liveNear(db, lat, lng, radiusM, now, type) {
  const cells = cellsAround(lat, lng, radiusM);
  const marks = cells.map(() => '?').join(',');
  const typeSql = type ? ' AND type = ?' : '';
  const { results } = await db
    .prepare(`SELECT ${COLUMNS} FROM reports WHERE cell IN (${marks}) AND expires_at > ?${typeSql} LIMIT 500`)
    .bind(...cells, now, ...(type ? [type] : []))
    .all();
  return results
    .map((r) => ({ ...r, d: distanceM(lat, lng, r.lat, r.lng) }))
    .filter((r) => r.d <= radiusM)
    .sort((a, b) => a.d - b.d);
}

/** One vote per device per report; then counts and expiry change. Returns the updated row. */
async function castVote(db, secret, row, deviceId, vote, now) {
  const voter = await voterHash(secret, deviceId, row.id);
  const ins = await db
    .prepare('INSERT INTO votes (report_id, voter_hash, vote, created_at) VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING')
    .bind(row.id, voter, vote, now)
    .run();
  if ((ins.meta?.changes ?? 0) === 0) return { row, alreadyVoted: true };
  const next = applyVote(
    { ttlSeconds: REPORT_TYPES[row.type], createdAt: row.created_at, expiresAt: row.expires_at, confirms: row.confirms, denies: row.denies },
    vote,
    now,
  );
  const updated = await db
    .prepare(`UPDATE reports SET confirms = ?, denies = ?, expires_at = ? WHERE id = ? RETURNING ${COLUMNS}`)
    .bind(next.confirms, next.denies, next.expiresAt, row.id)
    .first();
  return { row: updated ?? row, alreadyVoted: false };
}

async function nearby(url, env, now) {
  const q = parseNearbyQuery(url.searchParams);
  if (!q.ok) return json({ error: q.error }, 400);
  const { lat, lng, radiusM } = q.value;
  const rows = await liveNear(env.DB, lat, lng, radiusM, now);
  return json({ reports: rows.slice(0, 200).map(toJson) });
}

async function create(request, env, now) {
  const deviceId = request.headers.get('x-device-id');
  if (!validDeviceId(deviceId)) return json({ error: 'X-Device-Id header is required.' }, 400);
  const v = validateNewReport(await readJson(request));
  if (!v.ok) return json({ error: v.error }, 400);
  const { type, lat, lng, ttlSeconds } = v.value;
  const db = env.DB;

  const who = await reporterHash(env.HMAC_SECRET, deviceId, now);
  const cell = cellOf(lat, lng);
  if (!(await underLimit(db, `r:${who}`, LIMITS.reportsPerDevice, now))) {
    return json({ error: 'Too many reports. Try again soon.' }, 429);
  }

  // The same alert type within 100 m is the same alert: count it as a confirmation instead.
  const [twin] = await liveNear(db, lat, lng, SAME_ALERT_M, now, type);
  if (twin) {
    const { row } = await castVote(db, env.HMAC_SECRET, twin, deviceId, 'confirm', now);
    return json({ report: toJson(row), merged: true }, 200);
  }

  if (!(await underLimit(db, `a:${cell}`, LIMITS.reportsPerArea, now))) {
    return json({ error: 'Too many reports here. Try again soon.' }, 429);
  }
  const row = await db
    .prepare(
      `INSERT INTO reports (id, type, lat, lng, cell, created_at, expires_at, reporter_hash)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING ${COLUMNS}`,
    )
    .bind(crypto.randomUUID(), type, lat, lng, cell, now, now + ttlSeconds * 1000, who)
    .first();
  return json({ report: toJson(row), merged: false }, 201);
}

async function vote(request, env, id, now) {
  const deviceId = request.headers.get('x-device-id');
  if (!validDeviceId(deviceId)) return json({ error: 'X-Device-Id header is required.' }, 400);
  const body = await readJson(request);
  const choice = body?.vote;
  if (choice !== 'confirm' && choice !== 'deny') return json({ error: 'vote must be confirm or deny.' }, 400);
  if (!validReportId(id)) return json({ error: 'Not found.' }, 404);
  const db = env.DB;

  const who = await reporterHash(env.HMAC_SECRET, deviceId, now);
  if (!(await underLimit(db, `v:${who}`, LIMITS.votesPerDevice, now))) {
    return json({ error: 'Too many votes. Try again soon.' }, 429);
  }
  const found = await db.prepare(`SELECT ${COLUMNS} FROM reports WHERE id = ? AND expires_at > ?`).bind(id, now).first();
  if (!found) return json({ error: 'Alert is gone.' }, 404);
  const { row, alreadyVoted } = await castVote(db, env.HMAC_SECRET, found, deviceId, choice, now);
  return json({ report: toJson(row), already_voted: alreadyVoted });
}

/** Live traffic readings. Each one only adds to a 5-minute average for its stretch; nothing about
 * the phone, or which readings came together, is kept. */
async function speeds(request, env, now) {
  const deviceId = request.headers.get('x-device-id');
  if (!validDeviceId(deviceId)) return json({ error: 'X-Device-Id header is required.' }, 400);
  const v = validateSpeeds(await readJson(request));
  if (!v.ok) return json({ error: v.error }, 400);
  const db = env.DB;
  const who = await reporterHash(env.HMAC_SECRET, deviceId, now);
  if (!(await underLimit(db, `s:${who}`, LIMITS.speedBatchesPerDevice, now))) {
    return json({ error: 'Too many readings. Try again soon.' }, 429);
  }
  const minute = Math.floor(now / SPEED_BUCKET_MS) * SPEED_BUCKET_MS;
  const upsert = db.prepare(
    `INSERT INTO speeds (seg, cell, minute, lat, lng, dir, sum_kmh, n) VALUES (?, ?, ?, ?, ?, ?, ?, 1)
     ON CONFLICT (seg, minute) DO UPDATE SET sum_kmh = sum_kmh + excluded.sum_kmh, n = n + 1`,
  );
  await db.batch(
    v.value.map((r) => {
      const s = segmentOf(r.lat, r.lng, r.heading);
      return upsert.bind(s.seg, s.cell, minute, s.lat, s.lng, s.dir, r.kmh);
    }),
  );
  return json({ ok: true, accepted: v.value.length });
}

/** Average speeds near a point over the last 15 minutes, only where at least two readings agree. */
async function traffic(url, env, now) {
  const q = parseNearbyQuery(url.searchParams);
  if (!q.ok) return json({ error: q.error }, 400);
  const { lat, lng, radiusM } = q.value;
  const cells = cellsAround(lat, lng, radiusM);
  const { results } = await env.DB
    .prepare(
      `SELECT seg, lat, lng, dir, SUM(sum_kmh) AS total, SUM(n) AS n FROM speeds
       WHERE cell IN (${cells.map(() => '?').join(',')}) AND minute >= ?
       GROUP BY seg HAVING SUM(n) >= ? LIMIT 5000`,
    )
    .bind(...cells, now - TRAFFIC_WINDOW_MS, MIN_READINGS)
    .all();
  const segments = results
    .filter((r) => distanceM(lat, lng, r.lat, r.lng) <= radiusM)
    .map((r) => ({ lat: r.lat, lng: r.lng, dir: r.dir, kmh: Math.round(r.total / r.n), n: r.n }));
  return json({ segments: segments.slice(0, 2000) });
}

/** Privacy and housekeeping: alerts go a day after they expire (their votes with them); traffic
 * averages go after an hour. */
export async function cleanup(db, now = Date.now()) {
  const cutoff = now - 24 * 3600 * 1000;
  await db.batch([
    db.prepare('DELETE FROM votes WHERE report_id IN (SELECT id FROM reports WHERE expires_at < ?)').bind(cutoff),
    db.prepare('DELETE FROM reports WHERE expires_at < ?').bind(cutoff),
    db.prepare('DELETE FROM hits WHERE at < ?').bind(now - 3600 * 1000),
    db.prepare('DELETE FROM speeds WHERE minute < ?').bind(now - 3600 * 1000),
  ]);
}

export default {
  async fetch(request, env, _ctx, now = Date.now()) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';
    try {
      if (request.method === 'GET' && path === '/healthz') {
        await env.DB.prepare('SELECT 1').first();
        return json({ ok: true, ready: Boolean(env.HMAC_SECRET) });
      }
      if (request.method === 'GET' && path === '/v1/reports') return await nearby(url, env, now);
      if (request.method === 'GET' && path === '/v1/traffic') return await traffic(url, env, now);

      const writes = request.method === 'POST';
      if (writes && !env.HMAC_SECRET) return json({ error: 'Server is still being set up.' }, 503);
      if (writes && path === '/v1/reports') return await create(request, env, now);
      if (writes && path === '/v1/speeds') return await speeds(request, env, now);
      const m = path.match(/^\/v1\/reports\/([^/]+)\/vote$/);
      if (writes && m) return await vote(request, env, m[1], now);

      return json({ error: 'Not found.' }, 404);
    } catch (err) {
      console.error(err);
      return json({ error: 'Server error.' }, 500);
    }
  },

  // Runs every hour (see wrangler.toml).
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(cleanup(env.DB));
  },
};
