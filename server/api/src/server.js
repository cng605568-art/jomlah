import Fastify from 'fastify';
import pg from 'pg';
import {
  applyVote, parseNearbyQuery, RateLimiter, REPORT_TYPES,
  reporterHash, validateNewReport, validDeviceId, voterHash,
} from './logic.js';

const { DATABASE_URL, HMAC_SECRET, PORT = '8080' } = process.env;
if (!DATABASE_URL) throw new Error('DATABASE_URL is required');
if (!HMAC_SECRET || HMAC_SECRET.length < 16) throw new Error('HMAC_SECRET (16+ chars) is required');

const pool = new pg.Pool({ connectionString: DATABASE_URL, max: 10 });
const app = Fastify({ logger: true, bodyLimit: 4096 });
const limiter = new RateLimiter({ limit: 10, windowMs: 10 * 60 * 1000 }); // 10 reports / 10 min

const COLUMNS = `id, type, ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lng,
                 created_at, expires_at, confirms, denies`;

const toJson = (r) => ({
  id: r.id,
  type: r.type,
  lat: r.lat,
  lng: r.lng,
  created_at: r.created_at.toISOString(),
  expires_at: r.expires_at.toISOString(),
  confirms: r.confirms,
  denies: r.denies,
});

const deviceIdOf = (req) => {
  const id = req.headers['x-device-id'];
  return validDeviceId(id) ? id : null;
};

/** Records one vote per device per report, then updates counts and expiry. Call inside a transaction. */
async function castVote(client, row, deviceId, vote) {
  const ins = await client.query(
    `INSERT INTO votes (report_id, voter_hash, vote) VALUES ($1, $2, $3)
     ON CONFLICT DO NOTHING RETURNING 1`,
    [row.id, voterHash(HMAC_SECRET, deviceId, row.id), vote],
  );
  if (ins.rowCount === 0) return { row, alreadyVoted: true };
  const next = applyVote(
    { ttlSeconds: REPORT_TYPES[row.type], createdAt: row.created_at, expiresAt: row.expires_at,
      confirms: row.confirms, denies: row.denies },
    vote,
  );
  const upd = await client.query(
    `UPDATE reports SET confirms = $2, denies = $3, expires_at = $4 WHERE id = $1 RETURNING ${COLUMNS}`,
    [row.id, next.confirms, next.denies, next.expiresAt],
  );
  return { row: upd.rows[0], alreadyVoted: false };
}

app.get('/healthz', async () => ({ ok: true }));

app.get('/v1/reports', async (req, reply) => {
  const q = parseNearbyQuery(req.query);
  if (!q.ok) return reply.code(400).send({ error: q.error });
  const { lat, lng, radiusM } = q.value;
  const { rows } = await pool.query(
    `SELECT ${COLUMNS} FROM reports
     WHERE expires_at > now()
       AND ST_DWithin(geom, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography, $3::float8)
     ORDER BY created_at DESC LIMIT 200`,
    [lng, lat, radiusM],
  );
  return { reports: rows.map(toJson) };
});

app.post('/v1/reports', async (req, reply) => {
  const deviceId = deviceIdOf(req);
  if (!deviceId) return reply.code(400).send({ error: 'X-Device-Id header is required.' });
  const v = validateNewReport(req.body);
  if (!v.ok) return reply.code(400).send({ error: v.error });
  const { type, lat, lng, ttlSeconds } = v.value;

  const who = reporterHash(HMAC_SECRET, deviceId);
  if (!limiter.allow(who)) return reply.code(429).send({ error: 'Too many reports. Try again soon.' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // The same alert type within 100 m is the same alert: count it as a confirmation instead.
    const dup = await client.query(
      `SELECT ${COLUMNS} FROM reports
       WHERE type = $1 AND expires_at > now()
         AND ST_DWithin(geom, ST_SetSRID(ST_MakePoint($2::float8, $3::float8), 4326)::geography, 100)
       ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,
      [type, lng, lat],
    );
    if (dup.rowCount > 0) {
      const { row } = await castVote(client, dup.rows[0], deviceId, 'confirm');
      await client.query('COMMIT');
      return reply.code(200).send({ report: toJson(row), merged: true });
    }
    const ins = await client.query(
      `INSERT INTO reports (type, geom, expires_at, reporter_hash)
       VALUES ($1, ST_SetSRID(ST_MakePoint($2::float8, $3::float8), 4326)::geography,
               now() + make_interval(secs => $4::float8), $5)
       RETURNING ${COLUMNS}`,
      [type, lng, lat, ttlSeconds, who],
    );
    await client.query('COMMIT');
    return reply.code(201).send({ report: toJson(ins.rows[0]), merged: false });
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
});

app.post('/v1/reports/:id/vote', async (req, reply) => {
  const deviceId = deviceIdOf(req);
  if (!deviceId) return reply.code(400).send({ error: 'X-Device-Id header is required.' });
  const vote = req.body?.vote;
  if (vote !== 'confirm' && vote !== 'deny') {
    return reply.code(400).send({ error: 'vote must be confirm or deny.' });
  }
  const id = req.params.id;
  if (!/^[0-9a-f-]{36}$/i.test(id)) return reply.code(404).send({ error: 'Not found.' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const found = await client.query(
      `SELECT ${COLUMNS} FROM reports WHERE id = $1 AND expires_at > now() FOR UPDATE`,
      [id],
    );
    if (found.rowCount === 0) {
      await client.query('ROLLBACK');
      return reply.code(404).send({ error: 'Alert is gone.' });
    }
    const { row, alreadyVoted } = await castVote(client, found.rows[0], deviceId, vote);
    await client.query('COMMIT');
    return { report: toJson(row), already_voted: alreadyVoted };
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
});

// Privacy and housekeeping: delete alerts a day after they expire (votes go with them).
setInterval(async () => {
  try {
    limiter.sweep();
    await pool.query(`DELETE FROM reports WHERE expires_at < now() - interval '1 day'`);
  } catch (err) {
    app.log.error(err, 'cleanup failed');
  }
}, 60 * 60 * 1000).unref();

await app.listen({ port: Number(PORT), host: '0.0.0.0' });
