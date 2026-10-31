import test from 'node:test';
import assert from 'node:assert/strict';
import worker, { cleanup } from '../src/index.js';
import { dirOf, LIMITS, segmentOf, validateSpeeds } from '../src/logic.js';
import { testDb } from './d1.js';

// Live traffic: anonymous speed readings in, short-lived averages out.

const T0 = Date.parse('2026-10-31T09:00:00Z');
const dev = (n) => `device-${String(n).padStart(4, '0')}-aaaa-bbbb-cccc`;
// Federal Highway near Sunway, heading west (270 degrees).
const FH = { lat: 3.0738, lng: 101.6047 };

function setup() {
  const env = { DB: testDb(), HMAC_SECRET: 'test-secret-that-is-long-enough' };
  const call = async (method, path, { body, device, now = T0 } = {}) => {
    const headers = { 'content-type': 'application/json' };
    if (device) headers['x-device-id'] = device;
    const res = await worker.fetch(
      new Request(`https://alerts.test${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined }),
      env, {}, now,
    );
    return { status: res.status, body: await res.json() };
  };
  return { env, call };
}

const send = (call, device, samples, now = T0) => call('POST', '/v1/speeds', { device, now, body: { samples } });
const look = (call, now = T0, where = FH) => call('GET', `/v1/traffic?lat=${where.lat}&lng=${where.lng}`, { now });
const reading = (kmh, heading = 270, where = FH) => ({ ...where, heading, kmh });

test('directions and stretches', () => {
  assert.equal(dirOf(0), 0);
  assert.equal(dirOf(359), 0);
  assert.equal(dirOf(90), 2);
  assert.equal(dirOf(270), 6);
  assert.equal(dirOf(-90), 6);
  const a = segmentOf(FH.lat, FH.lng, 270);
  const b = segmentOf(FH.lat + 0.0001, FH.lng + 0.0001, 265); // same square, same direction
  const c = segmentOf(FH.lat, FH.lng, 90); // other side of the road
  assert.equal(a.seg, '2049:67736:6'); // same example as test/traffic_test.dart in the app
  assert.equal(a.seg, b.seg);
  assert.notEqual(a.seg, c.seg);
  assert.ok(Math.abs(a.lat - FH.lat) < 0.0015 && Math.abs(a.lng - FH.lng) < 0.0015);
});

test('readings are checked', () => {
  assert.equal(validateSpeeds({ samples: [reading(40)] }).ok, true);
  assert.equal(validateSpeeds({}).ok, false);
  assert.equal(validateSpeeds({ samples: [] }).ok, false);
  assert.equal(validateSpeeds({ samples: Array(11).fill(reading(40)) }).ok, false);
  assert.equal(validateSpeeds({ samples: [reading(400)] }).ok, false);
  assert.equal(validateSpeeds({ samples: [{ ...reading(40), lat: 51.5, lng: -0.1 }] }).ok, false);
  assert.equal(validateSpeeds({ samples: [{ lat: 3, lng: 101 }] }).ok, false);
});

test('one car alone is not traffic; two readings make an average', async () => {
  const { call } = setup();
  assert.equal((await send(call, dev(1), [reading(8)])).status, 200);
  assert.deepEqual((await look(call)).body.segments, []);
  await send(call, dev(2), [reading(12)], T0 + 60_000);
  const segs = (await look(call, T0 + 90_000)).body.segments;
  assert.equal(segs.length, 1);
  assert.equal(segs[0].kmh, 10);
  assert.equal(segs[0].n, 2);
  assert.equal(segs[0].dir, 6);
});

test('each direction of a road is its own stretch', async () => {
  const { call } = setup();
  await send(call, dev(1), [reading(5, 270), reading(80, 90)]);
  await send(call, dev(2), [reading(7, 270), reading(90, 90)]);
  const segs = (await look(call)).body.segments.sort((a, b) => a.dir - b.dir);
  assert.deepEqual(segs.map((s) => [s.dir, s.kmh]), [[2, 85], [6, 6]]);
});

test('only the last 15 minutes count, and averages are deleted after an hour', async () => {
  const { env, call } = setup();
  await send(call, dev(1), [reading(10), reading(10)]);
  assert.equal((await look(call, T0 + 10 * 60_000)).body.segments.length, 1);
  assert.equal((await look(call, T0 + 25 * 60_000)).body.segments.length, 0);
  await cleanup(env.DB, T0 + 30 * 60_000);
  assert.equal(env.DB.raw.prepare('SELECT COUNT(*) AS n FROM speeds').get().n, 1); // not yet
  await cleanup(env.DB, T0 + 70 * 60_000);
  assert.equal(env.DB.raw.prepare('SELECT COUNT(*) AS n FROM speeds').get().n, 0);
});

test('nothing about the phone is kept with the speeds', async () => {
  const { env, call } = setup();
  await send(call, dev(42), [reading(30), reading(31)]);
  const rows = env.DB.raw.prepare('SELECT * FROM speeds').all();
  assert.deepEqual(Object.keys(rows[0]).sort(), ['cell', 'dir', 'lat', 'lng', 'minute', 'n', 'seg', 'sum_kmh']);
  assert.ok(!JSON.stringify(rows).includes(dev(42)));
});

test('one phone cannot flood the traffic data', async () => {
  const { call } = setup();
  for (let i = 0; i < LIMITS.speedBatchesPerDevice; i++) {
    assert.equal((await send(call, dev(1), [reading(50)])).status, 200, `batch ${i}`);
  }
  assert.equal((await send(call, dev(1), [reading(50)])).status, 429);
  assert.equal((await send(call, dev(2), [reading(50)])).status, 200);
});

test('bad traffic requests are refused', async () => {
  const { call } = setup();
  assert.equal((await send(call, undefined, [reading(40)])).status, 400);
  assert.equal((await send(call, dev(1), [reading(999)])).status, 400);
  assert.equal((await call('GET', '/v1/traffic?lat=51.5&lng=-0.1')).status, 400);
});
