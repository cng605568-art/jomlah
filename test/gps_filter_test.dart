import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jomlah/core/geo.dart';
import 'package:jomlah/features/map/domain/car_motion.dart';
import 'package:jomlah/features/map/domain/gps_filter.dart';

final origin = LatLng(3.1390, 101.6869);
final t0 = DateTime.utc(2026, 10, 24, 8);

/// Repeatable pseudo-noise (east, north) in metres, so the tests never flake.
(double, double) noise(int i, double amp) => (
      amp * math.sin(i * 2.399) * math.cos(i * 0.731 + 1.0),
      amp * math.cos(i * 1.713 + 0.5) * math.sin(i * 0.419 + 2.0),
    );

/// A car driving due north at 15 m/s (54 km/h).
LatLng truth(double t) => offsetM(origin, 0, 15.0 * t);

GpsFix fix(
  LatLng p, {
  required double t,
  double acc = 6,
  double speed = 15,
  double heading = 0,
}) =>
    GpsFix(
      position: p,
      accuracyM: acc,
      speedMps: speed,
      headingDeg: heading,
      time: t0.add(Duration(milliseconds: (t * 1000).round())),
    );

void main() {
  test('smooths noise while driving, without lagging behind the car', () {
    final f = GpsFilter();
    var raw = 0.0, filtered = 0.0, lag = 0.0;
    var n = 0;
    for (var i = 0; i <= 40; i++) {
      final tp = truth(i.toDouble());
      final (ne, nn) = noise(i, 8.0);
      final meas = offsetM(tp, ne, nn);
      final out = f.accept(fix(
        meas,
        t: i.toDouble(),
        speed: 15.0 + 0.4 * math.sin(i.toDouble()),
        heading: (360 + 3 * math.sin(i * 0.5)) % 360,
      ));
      if (i >= 5 && out != null) {
        n++;
        raw += haversineM(meas, tp);
        filtered += haversineM(out.position, tp);
        lag += (tp.latitude - out.position.latitude) * 111320;
      }
    }
    expect(filtered / n, lessThan(raw / n));
    expect(filtered / n, lessThan(3.5));
    expect((lag / n).abs(), lessThan(2.0)); // metres behind along the road
  });

  test('stands still at the lights instead of wandering', () {
    final f = GpsFilter();
    var maxErr = 0.0;
    for (var i = 0; i < 60; i++) {
      final (ne, nn) = noise(i, 10.0);
      final out = f.accept(fix(offsetM(origin, ne, nn), t: i.toDouble(), acc: 8, speed: 0, heading: -1));
      if (i >= 10 && out != null) {
        maxErr = math.max(maxErr, haversineM(out.position, origin));
      }
    }
    expect(maxErr, lessThan(3.0));
  });

  test('ignores a teleport spike', () {
    final f = GpsFilter();
    var maxErr = 0.0;
    for (var i = 0; i < 40; i++) {
      final tp = truth(i.toDouble());
      final (ne, nn) = noise(i, 4.0);
      var meas = offsetM(tp, ne, nn);
      if (i == 20) meas = offsetM(tp, 600, 0);
      final out = f.accept(fix(meas, t: i.toDouble()));
      if (i == 20) expect(out, isNull);
      if (i >= 5 && out != null) maxErr = math.max(maxErr, haversineM(out.position, tp));
    }
    expect(maxErr, lessThan(5.0));
  });

  test('ignores poor-accuracy fixes while it has a good track', () {
    final f = GpsFilter();
    for (var i = 0; i < 30; i++) {
      final tp = truth(i.toDouble());
      final (ne, nn) = noise(i, 4.0);
      var meas = offsetM(tp, ne, nn);
      var acc = 6.0;
      if (i == 15 || i == 16) {
        meas = offsetM(tp, 70, -40);
        acc = 90;
      }
      final out = f.accept(fix(meas, t: i.toDouble(), acc: acc));
      if (i == 15 || i == 16) expect(out, isNull);
      if (i == 17) expect(haversineM(out!.position, tp), lessThan(6.0));
    }
  });

  test('a fix bounced off a tall building barely moves the car', () {
    // The phone claims 6 m accuracy but puts us 35 m to the side for two fixes.
    final f = GpsFilter();
    var during = 0.0, after = 0.0;
    for (var i = 0; i < 40; i++) {
      final tp = truth(i.toDouble());
      final (ne, nn) = noise(i, 4.0);
      var meas = offsetM(tp, ne, nn);
      if (i == 20 || i == 21) meas = offsetM(tp, 35, 0);
      final out = f.accept(fix(meas, t: i.toDouble()))!;
      final e = haversineM(out.position, tp);
      if (i == 20 || i == 21) {
        during = math.max(during, e);
      } else if (i >= 22) {
        after = math.max(after, e);
      }
    }
    expect(during, lessThan(8.0)); // without the gate: about 13 m
    expect(after, lessThan(7.0)); // without the gate: about 10.6 m
  });

  test('reports how sure it is, getting surer with good fixes', () {
    final f = GpsFilter();
    final first = f.accept(fix(truth(0), t: 0))!;
    expect(first.accuracyM, closeTo(6, 0.01));
    FilteredFix? last;
    for (var i = 1; i < 20; i++) {
      final (ne, nn) = noise(i, 4.0);
      last = f.accept(fix(offsetM(truth(i.toDouble()), ne, nn), t: i.toDouble()));
    }
    expect(last!.accuracyM, lessThan(6));
    expect(last.accuracyM, greaterThanOrEqualTo(3));
  });

  test('stops ignoring bad fixes after 5 in a row (tunnel, car park)', () {
    final f = GpsFilter();
    FilteredFix? at15;
    for (var i = 0; i < 30; i++) {
      final tp = truth(i.toDouble());
      final (ne, nn) = noise(i, 4.0);
      final acc = (i >= 10 && i <= 16) ? 120.0 : 6.0;
      final out = f.accept(fix(offsetM(tp, ne, nn), t: i.toDouble(), acc: acc));
      if (i == 15) at15 = out;
    }
    expect(at15, isNotNull);
  });

  test('the drawn car moves in small steps every frame and stays close to the real car', () {
    final f = GpsFilter();
    final m = CarMotion();
    LatLng? prev;
    var maxStep = 0.0, errSum = 0.0, maxErr = 0.0;
    var errN = 0;
    var tFix = 0;
    for (var frame = 0; frame < 60 * 20; frame++) {
      final now = frame / 60.0;
      if (now >= tFix && tFix <= 19) {
        final tp = truth(tFix.toDouble());
        final (ne, nn) = noise(tFix, 8.0);
        final out = f.accept(fix(offsetM(tp, ne, nn), t: tFix.toDouble()));
        if (out != null) {
          m.onFix(out.position, speedMps: out.speedMps, headingDeg: out.headingDeg, now: now);
        }
        tFix++;
      }
      final pose = m.tick(now);
      if (pose == null) continue;
      if (prev != null && frame >= 121) maxStep = math.max(maxStep, haversineM(prev, pose.position));
      prev = pose.position;
      if (frame > 180) {
        final e = haversineM(pose.position, truth(now));
        errSum += e;
        errN++;
        maxErr = math.max(maxErr, e);
      }
    }
    expect(maxStep, lessThan(1.0)); // a teleporting car would jump about 15 m
    expect(errSum / errN, lessThan(6.0));
    expect(maxErr, lessThan(9.0));
  });

  test('heading turns the short way round, never through 180', () {
    final m = CarMotion();
    m.onFix(origin, speedMps: 10, headingDeg: 359, now: 0);
    m.tick(0);
    m.onFix(origin, speedMps: 10, headingDeg: 1, now: 0.1);
    for (var k = 1; k < 200; k++) {
      final h = m.tick(0.1 + k / 60.0)!.headingDeg;
      expect(h >= 340 || h <= 20, isTrue, reason: 'heading $h went the long way');
    }
  });
}
