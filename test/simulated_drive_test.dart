import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jomlah/core/geo.dart';
import 'package:jomlah/features/map/domain/simulated_drive.dart';

final origin = LatLng(3.1390, 101.6869);
final t0 = DateTime.utc(2026, 10, 24, 8);

void main() {
  final end = offsetM(origin, 0, 1000);
  final shape = [origin, end];
  final cum = [0.0, haversineM(origin, end)];

  test('drives the whole route smoothly and stops at the end', () {
    final sim = SimulatedDrive(shape: shape, cumulativeM: cum, targetSpeedMps: 15);
    var steps = 0;
    var prevSpeed = 0.0;
    var prevLat = origin.latitude;
    var maxSpeed = 0.0;
    LatLng? last;
    while (!sim.finished && steps < 400) {
      final fix = sim.step(1.0, t0.add(Duration(seconds: steps)));
      expect((fix.speedMps - prevSpeed).abs(), lessThan(2.6)); // never a sudden lurch
      expect(fix.position.latitude, greaterThanOrEqualTo(prevLat)); // only ever forwards
      expect(fix.headingDeg, closeTo(0, 0.5)); // due north
      prevSpeed = fix.speedMps;
      prevLat = fix.position.latitude;
      maxSpeed = math.max(maxSpeed, fix.speedMps);
      last = fix.position;
      steps++;
    }
    expect(sim.finished, isTrue);
    expect(steps, lessThan(150));
    expect(haversineM(last!, end), lessThan(1.0));
    expect(maxSpeed, lessThanOrEqualTo(15.01));
  });

  test('slows down for a turn and speeds up again afterwards', () {
    final sim = SimulatedDrive(
      shape: shape,
      cumulativeM: cum,
      targetSpeedMps: 15,
      slowPointsM: const [500],
    );
    double? atTurn;
    double? later;
    var along = 0.0;
    var steps = 0;
    var lastPos = origin;
    while (!sim.finished && steps < 400) {
      final fix = sim.step(1.0, t0.add(Duration(seconds: steps)));
      along += haversineM(lastPos, fix.position);
      lastPos = fix.position;
      if (atTurn == null && along >= 500) atTurn = fix.speedMps;
      if (later == null && along >= 600) later = fix.speedMps;
      steps++;
    }
    expect(atTurn!, lessThan(7.0));
    expect(later!, greaterThan(12.0));
  });

  test('adding jitter keeps the car near the road', () {
    final sim = SimulatedDrive(
      shape: shape,
      cumulativeM: cum,
      targetSpeedMps: 15,
      noiseM: 4,
      random: math.Random(7),
    );
    var worst = 0.0;
    for (var i = 0; i < 40; i++) {
      final fix = sim.step(1.0, t0.add(Duration(seconds: i)));
      // sideways distance from the north-south road (road is the line through origin)
      final sideways = (fix.position.longitude - origin.longitude).abs() *
          111320 *
          math.cos(origin.latitude * math.pi / 180);
      worst = math.max(worst, sideways);
      expect(fix.accuracyM, greaterThanOrEqualTo(6.0));
    }
    expect(worst, lessThan(25.0)); // 4 m jitter should never wander 25 m off
  });
}
