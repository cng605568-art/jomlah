import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jomlah/core/geo.dart';
import 'package:jomlah/features/map/domain/traffic.dart';
import 'package:jomlah/features/routing/domain/route_plan.dart';

// Live traffic on the phone: which readings are shared, and how crowd speeds become orange and red
// stretches on the route.

final _t0 = DateTime(2026, 10, 31, 9);
final _start = LatLng(3.0000, 101.6000);

/// A straight 3 km route heading north, with a point every 100 m. Planned at 60 km/h.
RoutePlan _north() => RoutePlan(
      shape: [for (var m = 0.0; m <= 3000; m += 100) offsetM(_start, 0, m)],
      maneuvers: const [],
      distanceKm: 3,
      durationSec: 180,
    );

/// Crowd speeds on every stretch the route passes between [fromM] and [toM].
Map<String, TrafficSegment> _crowd(RoutePlan plan, double fromM, double toM,
    {required double kmh, int n = 3, double heading = 0}) {
  final out = <String, TrafficSegment>{};
  for (var m = fromM; m <= toM; m += 20) {
    final c = stretchCentre(pointAlong(plan, m));
    final s = TrafficSegment(centre: c, dir: dirOf(heading), kmh: kmh, n: n);
    out[s.key] = s;
  }
  return out;
}

void main() {
  test('directions and stretches match the server rules', () {
    expect(dirOf(0), 0);
    expect(dirOf(359), 0);
    expect(dirOf(90), 2);
    expect(dirOf(270), 6);
    expect(dirOf(-90), 6);
    // Same example as worker/test/traffic.test.js: Federal Highway near Sunway, heading west.
    expect(stretchKey(LatLng(3.0738, 101.6047), 270), '2049:67736:6');
    final c = stretchCentre(LatLng(3.0738, 101.6047));
    expect(stretchKey(c, 270), '2049:67736:6'); // the centre stays in its own square
  });

  test('a reading every 30 s, sent every 2 minutes, rounded to its stretch', () {
    final s = SpeedSampler();
    final here = LatLng(3.0738, 101.6047);
    for (var sec = 0; sec <= 120; sec += 1) {
      s.add(now: _t0.add(Duration(seconds: sec)), at: here, headingDeg: 268, kmh: 47.6, alongM: 2000, remainingM: 5000);
    }
    expect(s.takeBatch(_t0.add(const Duration(seconds: 60))), isEmpty); // not time yet
    final batch = s.takeBatch(_t0.add(const Duration(seconds: 125)));
    expect(batch.length, 5); // 0, 30, 60, 90, 120 s
    expect(batch.first.headingDeg, 270);
    expect(batch.first.kmh, 48);
    expect(batch.first.centre, stretchCentre(here));
    expect(batch.first.centre == here, isFalse); // the exact position never leaves the phone
    expect(s.takeBatch(_t0.add(const Duration(seconds: 126))), isEmpty); // sent already
  });

  test('the first and last 500 m of a trip are never shared', () {
    final s = SpeedSampler(every: Duration.zero, batchEvery: Duration.zero);
    final here = LatLng(3.0738, 101.6047);
    s.add(now: _t0, at: here, headingDeg: 0, kmh: 30, alongM: 300, remainingM: 9000);
    s.add(now: _t0.add(const Duration(seconds: 1)), at: here, headingDeg: 0, kmh: 30, alongM: 9000, remainingM: 400);
    expect(s.takeBatch(_t0.add(const Duration(seconds: 2))), isEmpty);
    s.add(now: _t0.add(const Duration(seconds: 3)), at: here, headingDeg: 0, kmh: 30, alongM: 600, remainingM: 600);
    expect(s.takeBatch(_t0.add(const Duration(seconds: 4))).length, 1);
  });

  test('how bad a stretch is depends on the road, and red needs three readings', () {
    TrafficSegment seg(double kmh, int n) => TrafficSegment(centre: _start, dir: 0, kmh: kmh, n: n);
    expect(trafficLevel(seg(8, 3), 90), TrafficLevel.heavy);
    expect(trafficLevel(seg(8, 2), 90), TrafficLevel.slow); // two readings: only orange
    expect(trafficLevel(seg(35, 3), 110), TrafficLevel.slow); // crawling on a highway
    expect(trafficLevel(seg(35, 3), 50), isNull); // normal in town
    expect(trafficLevel(seg(45, 3), 110), isNull); // not jam speed
  });

  test('a jam ahead on our side of the road becomes a red stretch; the other side does not count', () {
    final plan = _north();
    final jam = _crowd(plan, 1000, 1500, kmh: 6);
    final stretches = slowStretches(plan, 200, jam);
    expect(stretches.length, 1);
    expect(stretches.single.level, TrafficLevel.heavy);
    // Stretches are ~165 m squares, so the red part starts and ends at their edges.
    expect(stretches.single.startM, closeTo(1000, 170));
    expect(stretches.single.endM, closeTo(1500, 170));

    final otherSide = _crowd(plan, 1000, 1500, kmh: 6, heading: 180);
    expect(slowStretches(plan, 200, otherSide), isEmpty);
  });

  test('stretches already behind the car, or past the look-ahead, are left out', () {
    final plan = _north();
    final jam = _crowd(plan, 1000, 1500, kmh: 6);
    expect(slowStretches(plan, 1600, jam), isEmpty);
    expect(slowStretches(plan, 0, jam, lookAheadM: 500), isEmpty);
  });

  test('the speed limit decides what is slow when the map knows it', () {
    final plan = _north();
    final crawl = _crowd(plan, 1000, 1500, kmh: 30);
    expect(slowStretches(plan, 0, crawl), isEmpty); // route planned at 60: 30 is half, not below it
    final onHighway = slowStretches(plan, 0, crawl, limitAt: (_) => 110);
    expect(onHighway.single.level, TrafficLevel.slow);
  });

  test('shapeBetween gives the road between two distances', () {
    final plan = _north();
    final part = shapeBetween(plan, 250, 480);
    expect(part.length, 4); // start, the points at 300 and 400 m, end
    expect(haversineM(part.first, pointAlong(plan, 250)), lessThan(0.5));
    expect(haversineM(part.last, pointAlong(plan, 480)), lessThan(0.5));
    expect(shapeBetween(plan, 500, 400), isEmpty);
  });
}
