import test from 'node:test';
import assert from 'node:assert/strict';
import {
  applyVote, parseNearbyQuery, RateLimiter, REPORT_TYPES,
  reporterHash, validateNewReport, validDeviceId, voterHash,
} from '../src/logic.js';

const T0 = new Date('2026-10-24T08:00:00Z');
const min = (n) => new Date(T0.getTime() + n * 60_000);
const police = (over = {}) => ({
  ttlSeconds: REPORT_TYPES.police, createdAt: T0, expiresAt: min(45), confirms: 0, denies: 0, ...over,
});

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
  assert.equal(parseNearbyQuery({ lat: '3.1', lng: '101.6' }).value.radiusM, 10_000);
  assert.equal(parseNearbyQuery({ lat: '3.1', lng: '101.6', r: '999' }).value.radiusM, 25_000);
  assert.equal(parseNearbyQuery({ lat: 'x', lng: '101.6' }).ok, false);
  assert.equal(parseNearbyQuery({ lat: '3.1', lng: '101.6', r: '-4' }).ok, false);
});

test('a confirmation extends the alert by half its normal life', () => {
  const out = applyVote(police(), 'confirm', min(40));
  assert.equal(out.confirms, 1);
  assert.equal(out.expiresAt.getTime(), min(40 + 22.5).getTime());
});

test('a confirmation never shortens an alert', () => {
  const out = applyVote(police({ expiresAt: min(120) }), 'confirm', min(10));
  assert.equal(out.expiresAt.getTime(), min(120).getTime());
});

test('confirmations are capped at 3x the normal life from creation', () => {
  const out = applyVote(police({ expiresAt: min(130) }), 'confirm', min(125));
  assert.equal(out.expiresAt.getTime(), min(135).getTime());
});

test('two net denies kill an alert; one deny does not', () => {
  const one = applyVote(police(), 'deny', min(5));
  assert.equal(one.expiresAt.getTime(), min(45).getTime());
  const two = applyVote(police({ denies: 1 }), 'deny', min(6));
  assert.equal(two.expiresAt.getTime(), min(6).getTime());
  const offset = applyVote(police({ denies: 1, confirms: 1 }), 'deny', min(6));
  assert.equal(offset.expiresAt.getTime(), min(45).getTime());
});

test('hashes are stable, per-day for reporters and per-report for voters', () => {
  const s = 'a-long-test-secret-value';
  assert.equal(reporterHash(s, 'dev', T0), reporterHash(s, 'dev', min(30)));
  assert.notEqual(reporterHash(s, 'dev', T0), reporterHash(s, 'dev', new Date('2026-10-25T08:00:00Z')));
  assert.equal(voterHash(s, 'dev', 'r1'), voterHash(s, 'dev', 'r1'));
  assert.notEqual(voterHash(s, 'dev', 'r1'), voterHash(s, 'dev', 'r2'));
  assert.ok(!reporterHash(s, 'dev', T0).includes('dev'));
});

test('device id format', () => {
  assert.equal(validDeviceId('3f2c9e1a-7b4d-4c1e-9a55-0d2b6f7a8c10'), true);
  assert.equal(validDeviceId('short'), false);
  assert.equal(validDeviceId('has spaces in it and more more'), false);
  assert.equal(validDeviceId(undefined), false);
});

test('RateLimiter allows the limit, blocks the next, and recovers after the window', () => {
  const rl = new RateLimiter({ limit: 3, windowMs: 1000 });
  assert.deepEqual([0, 100, 200].map((t) => rl.allow('k', t)), [true, true, true]);
  assert.equal(rl.allow('k', 300), false);
  assert.equal(rl.allow('other', 300), true);
  assert.equal(rl.allow('k', 1250), true);
});
