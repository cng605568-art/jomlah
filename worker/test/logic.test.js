import test from 'node:test';
import assert from 'node:assert/strict';
import {
  applyVote, cellOf, cellsAround, distanceM, parseNearbyQuery, REPORT_TYPES,
  reporterHash, validateNewReport, validDeviceId, voterHash,
} from '../src/logic.js';

const T0 = Date.parse('2026-10-24T08:00:00Z');
const min = (n) => T0 + n * 60_000;
const police = (over = {}) => ({
  ttlSeconds: REPORT_TYPES.police, createdAt: T0, expiresAt: min(45), confirms: 0, denies: 0, ...over,
});
const q = (o) => new URLSearchParams(o);

test('validateNewReport accepts a good report and fills the server-side TTL', () => {
  const r = validateNewReport({ type: 'flood', lat: 3.14, lng: 101.69, accuracy_m: 12 });
  assert.equal(r.ok, true);
  assert.equal(r.value.ttlSeconds, 3 * 3600);
});

test('validateNewReport rejects junk', () => {
  assert.equal(validateNewReport(null).ok, false);
  assert.equal(validateNewReport({ type: 'ufo', lat: 3, lng: 101 }).ok, false);
  assert.equal(validateNewReport({ type: 'police', lat: '3', lng: 101 }).ok, false);
  assert.equal(validateNewReport({ type: 'police', lat: 51.5, lng: -0.12 }).ok, false); // London
  assert.equal(validateNewReport({ type: 'police', lat: 3.1, lng: 101.6, accuracy_m: 500 }).ok, false);
  assert.equal(validateNewReport({ type: '__proto__', lat: 3.1, lng: 101.6 }).ok, false);
});

test('parseNearbyQuery defaults to 10 km and caps at 25 km', () => {
  assert.equal(parseNearbyQuery(q({ lat: '3.1', lng: '101.6' })).value.radiusM, 10_000);
  assert.equal(parseNearbyQuery(q({ lat: '3.1', lng: '101.6', r: '999' })).value.radiusM, 25_000);
  assert.equal(parseNearbyQuery(q({ lat: 'x', lng: '101.6' })).ok, false);
  assert.equal(parseNearbyQuery(q({ lng: '101.6' })).ok, false);
  assert.equal(parseNearbyQuery(q({ lat: '3.1', lng: '101.6', r: '-4' })).ok, false);
});

test('a confirmation extends the alert by half its normal life', () => {
  const out = applyVote(police(), 'confirm', min(40));
  assert.equal(out.confirms, 1);
  assert.equal(out.expiresAt, min(40 + 22.5));
});

test('a confirmation never shortens an alert', () => {
  assert.equal(applyVote(police({ expiresAt: min(120) }), 'confirm', min(10)).expiresAt, min(120));
});

test('confirmations are capped at 3x the normal life from creation', () => {
  assert.equal(applyVote(police({ expiresAt: min(130) }), 'confirm', min(125)).expiresAt, min(135));
});

test('two net denies kill an alert; one deny does not', () => {
  assert.equal(applyVote(police(), 'deny', min(5)).expiresAt, min(45));
  assert.equal(applyVote(police({ denies: 1 }), 'deny', min(6)).expiresAt, min(6));
  assert.equal(applyVote(police({ denies: 1, confirms: 1 }), 'deny', min(6)).expiresAt, min(45));
});

test('hashes are stable, per day for reporters and per report for voters', async () => {
  const s = 'a-long-test-secret-value';
  assert.equal(await reporterHash(s, 'dev', T0), await reporterHash(s, 'dev', min(30)));
  assert.notEqual(await reporterHash(s, 'dev', T0), await reporterHash(s, 'dev', Date.parse('2026-10-25T08:00:00Z')));
  assert.equal(await voterHash(s, 'dev', 'r1'), await voterHash(s, 'dev', 'r1'));
  assert.notEqual(await voterHash(s, 'dev', 'r1'), await voterHash(s, 'dev', 'r2'));
  assert.equal((await reporterHash(s, 'dev', T0)).length, 32);
});

test('device id format', () => {
  assert.equal(validDeviceId('3f2c9e1a-7b4d-4c1e-9a55-0d2b6f7a8c10'), true);
  assert.equal(validDeviceId('short'), false);
  assert.equal(validDeviceId('has spaces in it and more more'), false);
  assert.equal(validDeviceId(null), false);
});

test('the squares around a point cover the whole radius', () => {
  // KLCC, 10 km: every point 10 km away in any direction must be in one of the squares.
  const lat = 3.1579, lng = 101.7116;
  const cells = new Set(cellsAround(lat, lng, 10_000));
  for (let deg = 0; deg < 360; deg += 15) {
    const a = (deg * Math.PI) / 180;
    const pLat = lat + (10_000 * Math.cos(a)) / 111_320;
    const pLng = lng + (10_000 * Math.sin(a)) / (111_320 * Math.cos((lat * Math.PI) / 180));
    assert.ok(cells.has(cellOf(pLat, pLng)), `missing square at ${deg} degrees`);
  }
  assert.equal(cells.size, 9);
  assert.ok(cellsAround(lat, lng, 25_000).length <= 49); // D1 allows 100 values per query
});

test('distanceM is about right', () => {
  assert.ok(Math.abs(distanceM(3.0, 101.0, 3.001, 101.0) - 111) < 1);
});
