import test from 'node:test';
import assert from 'node:assert/strict';
import worker, { cleanup } from '../src/index.js';
import { LIMITS } from '../src/logic.js';
import { testDb } from './d1.js';

// The whole server, one request at a time, against an in-memory database.

const T0 = Date.parse('2026-10-31T02:00:00Z');
const KLCC = { lat: 3.1579, lng: 101.7116 };
const dev = (n) => `device-${String(n).padStart(4, '0')}-aaaa-bbbb-cccc`;

function setup() {
  const env = { DB: testDb(), HMAC_SECRET: 'test-secret-that-is-long-enough' };
  const call = async (method, path, { body, device, now = T0 } = {}) => {
    const headers = { 'content-type': 'application/json' };
    if (device) headers['x-device-id'] = device;
    const res = await worker.fetch(
      new Request(`https://alerts.test${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined }),
      env,
      {},
      now,
    );
    return { status: res.status, body: await res.json() };
  };
  return { env, call };
}

const report = (call, device, extra = {}, now = T0) =>
  call('POST', '/v1/reports', { device, now, body: { type: 'police', ...KLCC, ...extra } });
const near = (call, now = T0, where = KLCC) => call('GET', `/v1/reports?lat=${where.lat}&lng=${where.lng}`, { now });

test('health check', async () => {
  const { call } = setup();
  const r = await call('GET', '/healthz');
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { ok: true, ready: true });
});

test('a new report is shared with everyone nearby, and nobody far away', async () => {
  const { call } = setup();
  const r = await report(call, dev(1));
  assert.equal(r.status, 201);
  assert.equal(r.body.merged, false);
  assert.equal(r.body.report.type, 'police');
  assert.equal(r.body.report.expires_at, new Date(T0 + 45 * 60_000).toISOString());

  const here = await near(call);
  assert.equal(here.body.reports.length, 1);
  assert.equal(here.body.reports[0].id, r.body.report.id);

  const penang = await near(call, T0, { lat: 5.4141, lng: 100.3288 });
  assert.equal(penang.body.reports.length, 0);
});

test('the same alert reported twice nearby becomes one alert with a confirmation', async () => {
  const { call } = setup();
  const first = await report(call, dev(1));
  const twin = await report(call, dev(2), { lat: KLCC.lat + 0.0005 }); // about 55 m away
  assert.equal(twin.status, 200);
  assert.equal(twin.body.merged, true);
  assert.equal(twin.body.report.id, first.body.report.id);
  assert.equal(twin.body.report.confirms, 1);
  // A different type at the same spot is a different alert.
  const flood = await report(call, dev(3), { type: 'flood' });
  assert.equal(flood.status, 201);
  assert.equal((await near(call)).body.reports.length, 2);
});

test('"Masih ada?" votes: one per phone, and two net denies remove the alert', async () => {
  const { call } = setup();
  const id = (await report(call, dev(1))).body.report.id;
  const vote = (device, choice, now = T0 + 60_000) =>
    call('POST', `/v1/reports/${id}/vote`, { device, now, body: { vote: choice } });

  const c = await vote(dev(2), 'confirm');
  assert.equal(c.status, 200);
  assert.equal(c.body.report.confirms, 1);
  const again = await vote(dev(2), 'confirm');
  assert.equal(again.body.already_voted, true);
  assert.equal(again.body.report.confirms, 1);

  await vote(dev(3), 'deny');
  await vote(dev(4), 'deny');
  const gone = await vote(dev(5), 'deny'); // 3 denies - 1 confirm = 2: expired
  assert.equal(gone.status, 200);
  assert.equal((await near(call, T0 + 2 * 60_000)).body.reports.length, 0);
  assert.equal((await vote(dev(6), 'confirm', T0 + 3 * 60_000)).status, 404);
});

test('alerts expire on their own', async () => {
  const { call } = setup();
  await report(call, dev(1), { type: 'jam' }); // 30 minutes
  assert.equal((await near(call, T0 + 29 * 60_000)).body.reports.length, 1);
  assert.equal((await near(call, T0 + 31 * 60_000)).body.reports.length, 0);
});

test('one phone cannot flood the map', async () => {
  const { call } = setup();
  for (let i = 0; i < LIMITS.reportsPerDevice; i++) {
    // Spread out so they are not merged into one alert.
    const r = await report(call, dev(1), { lat: KLCC.lat + i * 0.01 });
    assert.equal(r.status, 201, `report ${i}`);
  }
  assert.equal((await report(call, dev(1), { lat: 3.5 })).status, 429);
  assert.equal((await report(call, dev(2), { lat: 3.5 })).status, 201); // another phone is fine
  assert.equal((await report(call, dev(1), { lat: 3.6 }, T0 + LIMITS.windowMs + 1)).status, 201); // later is fine
});

test('many phones cannot flood one area either', async () => {
  const { call } = setup();
  for (let i = 0; i < LIMITS.reportsPerArea; i++) {
    const r = await report(call, dev(i), { lat: KLCC.lat + (i % 6) * 0.0015, lng: KLCC.lng + Math.floor(i / 6) * 0.0015 });
    assert.equal(r.status, 201, `report ${i}`);
  }
  const extra = await report(call, dev(999), { lat: KLCC.lat + 0.012, lng: KLCC.lng + 0.012 });
  assert.equal(extra.status, 429);
});

test('bad requests are refused politely', async () => {
  const { call } = setup();
  assert.equal((await report(call, undefined)).status, 400); // no device id
  assert.equal((await report(call, 'short')).status, 400);
  assert.equal((await report(call, dev(1), { lat: 51.5, lng: -0.12 })).status, 400); // London
  assert.equal((await report(call, dev(1), { type: 'ufo' })).status, 400);
  assert.equal((await call('GET', '/v1/reports?lat=x&lng=1')).status, 400);
  assert.equal((await call('POST', '/v1/reports/not-an-id/vote', { device: dev(1), body: { vote: 'confirm' } })).status, 404);
  assert.equal((await call('POST', `/v1/reports/${crypto.randomUUID()}/vote`, { device: dev(1), body: { vote: 'maybe' } })).status, 400);
  assert.equal((await call('GET', '/nothing-here')).status, 404);
});

test('without its secret the server only reads, so nothing unhashed is ever stored', async () => {
  const { env, call } = setup();
  delete env.HMAC_SECRET;
  assert.equal((await report(call, dev(1))).status, 503);
  assert.equal((await near(call)).status, 200);
  assert.deepEqual((await call('GET', '/healthz')).body, { ok: true, ready: false });
});

test('nothing about the phone is stored: no device id anywhere in the database', async () => {
  const { env, call } = setup();
  const id = (await report(call, dev(7))).body.report.id;
  await call('POST', `/v1/reports/${id}/vote`, { device: dev(8), body: { vote: 'confirm' } });
  const everything = JSON.stringify([
    env.DB.raw.prepare('SELECT * FROM reports').all(),
    env.DB.raw.prepare('SELECT * FROM votes').all(),
    env.DB.raw.prepare('SELECT * FROM hits').all(),
  ]);
  assert.ok(!everything.includes(dev(7)) && !everything.includes(dev(8)));
});

test('hourly cleanup deletes alerts a day after they expire, with their votes', async () => {
  const { env, call } = setup();
  const id = (await report(call, dev(1), { type: 'jam' })).body.report.id;
  await call('POST', `/v1/reports/${id}/vote`, { device: dev(2), body: { vote: 'confirm' } });
  await cleanup(env.DB, T0 + 2 * 3600_000); // expired, but less than a day ago: kept
  assert.equal(env.DB.raw.prepare('SELECT COUNT(*) AS n FROM reports').get().n, 1);
  await cleanup(env.DB, T0 + 26 * 3600_000);
  assert.equal(env.DB.raw.prepare('SELECT COUNT(*) AS n FROM reports').get().n, 0);
  assert.equal(env.DB.raw.prepare('SELECT COUNT(*) AS n FROM votes').get().n, 0);
  assert.equal(env.DB.raw.prepare('SELECT COUNT(*) AS n FROM hits').get().n, 0);
});
