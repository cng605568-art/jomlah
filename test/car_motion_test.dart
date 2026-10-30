import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jomlah/core/geo.dart';
import 'package:jomlah/features/map/domain/car_motion.dart';

typedef TestRoute = ({List<LatLng> shape, List<double> cum});

final origin = LatLng(3.1390, 101.6869);

/// A route as the app stores it: points, plus metres from the start to each point.
TestRoute route(List<LatLng> pts) {
  final cum = <double>[0];
  for (var i = 1; i < pts.length; i++) {
    cum.add(cum.last + haversineM(pts[i - 1], pts[i]));
  }
  return (shape: pts, cum: cum);
}

/// The point [s] metres along [r].
LatLng pointAt(TestRoute r, double s) {
  if (s <= 0) return r.shape.first;
  if (s >= r.cum.last) return r.shape.last;
  var i = 0;
  while (r.cum[i + 1] < s) {
    i++;
  }
  final t = (s - r.cum[i]) / (r.cum[i + 1] - r.cum[i]);
  final a = r.shape[i];
  final b = r.shape[i + 1];
  return LatLng(a.latitude + t * (b.latitude - a.latitude), a.longitude + t * (b.longitude - a.longitude));
}

/// How far [p] is from the road, and how far along the road its closest point is.
({double dist, double along}) toRoute(TestRoute r, LatLng p) {
  const k = 111320.0;
  final cosLat = math.cos(p.latitude * math.pi / 180);
  var best = (dist: double.infinity, along: 0.0);
  for (var i = 0; i < r.shape.length - 1; i++) {
    final a = r.shape[i];
    final b = r.shape[i + 1];
    final ax = (a.longitude - p.longitude) * k * cosLat;
    final ay = (a.latitude - p.latitude) * k;
    final dx = (b.longitude - a.longitude) * k * cosLat;
    final dy = (b.latitude - a.latitude) * k;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : math.min(1.0, math.max(0.0, (-ax * dx - ay * dy) / len2));
    final d = math.sqrt(math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2));
    if (d < best.dist) best = (dist: d, along: r.cum[i] + t * (r.cum[i + 1] - r.cum[i]));
  }
  return best;
}

double turn(double from, double to) => ((((to - from) + 540) % 360) - 180).abs();

void main() {
  // 300 m north, a right-angle corner, then 300 m east.
  final lRoute = route([origin, offsetM(origin, 0, 300), offsetM(origin, 300, 300)]);

  /// Drives the L route at 15 m/s (54 km/h) with one fix a second, already snapped onto the road.
  /// [jitterM] moves each fix back and forth along the road, like real GPS does.
  ({double maxOff, int backSteps, double maxTurn, double lastHeading}) drive(double jitterM) {
    final m = CarMotion()..setRoute(lRoute.shape, lRoute.cum);
    var maxOff = 0.0, maxTurn = 0.0, lastHeading = 0.0;
    var back = 0;
    double? prevAlong, prevHeading;
    var nextFix = 0;
    for (var frame = 0; frame < 60 * 38; frame++) {
      final now = frame / 60.0;
      if (now >= nextFix && nextFix <= 37) {
        final along = 15.0 * nextFix + (nextFix > 0 ? jitterM * math.sin(nextFix * 2.399) : 0.0);
        final heading = bearingDeg(pointAt(lRoute, math.max(0.0, along - 1)), pointAt(lRoute, along + 1));
        m.onFix(pointAt(lRoute, along), speedMps: 15, headingDeg: heading, now: now, alongM: along);
        nextFix++;
      }
      final pose = m.tick(now)!;
      final r = toRoute(lRoute, pose.position);
      if (now > 1) maxOff = math.max(maxOff, r.dist);
      if (prevAlong != null && r.along < prevAlong - 0.01) back++;
      prevAlong = r.along;
      if (prevHeading != null) maxTurn = math.max(maxTurn, turn(prevHeading, pose.headingDeg));
      prevHeading = pose.headingDeg;
      lastHeading = pose.headingDeg;
    }
    return (maxOff: maxOff, backSteps: back, maxTurn: maxTurn, lastHeading: lastHeading);
  }

  test('follows the road round a corner instead of cutting across it', () {
    final r = drive(0);
    expect(r.maxOff, lessThan(0.3)); // the old straight-line animation went about 8 m off the road
    expect(r.backSteps, 0);
    expect(r.maxTurn, lessThan(6)); // degrees per frame: turns smoothly with the road
    expect(turn(r.lastHeading, 90), lessThan(1)); // facing east after the corner
  });

  test('never slides backwards when GPS jitters along the road', () {
    final r = drive(6);
    expect(r.maxOff, lessThan(0.3));
    expect(r.backSteps, 0);
    expect(r.maxTurn, lessThan(6));
  });

  test('reports how far along the route the drawn car is (for trimming the route line)', () {
    final m = CarMotion()..setRoute(lRoute.shape, lRoute.cum);
    expect(identical(m.route, lRoute.shape), isTrue);
    CarPose? pose;
    for (var frame = 0; frame <= 60 * 5; frame++) {
      final now = frame / 60.0;
      if (frame % 60 == 0) {
        final along = 15.0 * (frame ~/ 60);
        m.onFix(pointAt(lRoute, along), speedMps: 15, headingDeg: 0, now: now, alongM: along);
      }
      pose = m.tick(now);
    }
    expect(pose!.alongM, closeTo(75, 3)); // 5 s at 15 m/s
    expect(toRoute(lRoute, pose.position).along, closeTo(pose.alongM!, 0.5));

    final free = CarMotion();
    free.onFix(origin, speedMps: 10, headingDeg: 0, now: 0);
    expect(free.tick(0)!.alongM, isNull); // not following a route
  });

  test('joins the road smoothly when the fixes start snapping onto it', () {
    final m = CarMotion()..setRoute(lRoute.shape, lRoute.cum);
    LatLng? prev;
    var maxStep = 0.0, offAfter = 0.0;
    var nextFix = 0;
    for (var frame = 0; frame < 60 * 12; frame++) {
      final now = frame / 60.0;
      if (now >= nextFix && nextFix <= 11) {
        final along = 15.0 * nextFix;
        final road = pointAt(lRoute, along);
        if (nextFix < 4) {
          m.onFix(offsetM(road, 20, 0), speedMps: 15, headingDeg: 0, now: now); // not on the road yet
        } else {
          m.onFix(road, speedMps: 15, headingDeg: 0, now: now, alongM: along);
        }
        nextFix++;
      }
      final pose = m.tick(now)!;
      if (prev != null) maxStep = math.max(maxStep, haversineM(prev, pose.position));
      prev = pose.position;
      if (now > 6) offAfter = math.max(offAfter, toRoute(lRoute, pose.position).dist);
    }
    expect(maxStep, lessThan(1.5)); // 15 m/s is 0.25 m a frame; a jump would be 20 m
    expect(offAfter, lessThan(0.5));
  });

  test('a new route mid-drive does not make the car jump', () {
    final m = CarMotion();
    final westAt150 = route([offsetM(origin, 0, 150), offsetM(origin, -200, 150)]);
    LatLng? prev;
    var maxStep = 0.0;
    var nextFix = 0;
    for (var frame = 0; frame < 60 * 20; frame++) {
      final now = frame / 60.0;
      if (now >= nextFix && nextFix <= 19) {
        if (nextFix < 10) {
          final along = 15.0 * nextFix;
          m.setRoute(lRoute.shape, lRoute.cum);
          m.onFix(pointAt(lRoute, along), speedMps: 15, headingDeg: 0, now: now, alongM: along);
        } else {
          final along = 15.0 * (nextFix - 10);
          m.setRoute(westAt150.shape, westAt150.cum);
          m.onFix(pointAt(westAt150, along), speedMps: 15, headingDeg: 270, now: now, alongM: along);
        }
        nextFix++;
      }
      final pose = m.tick(now)!;
      if (prev != null) maxStep = math.max(maxStep, haversineM(prev, pose.position));
      prev = pose.position;
    }
    expect(maxStep, lessThan(1.0));
  });

  test('brake lights come on when slowing down hard, and go off again', () {
    final m = CarMotion()..setRoute(lRoute.shape, lRoute.cum);
    final speeds = <double>[15, 15, 15, 15, 10, 5, 5, 5, 5, 5, 5];
    final braking = <double, bool>{};
    var along = 0.0;
    for (var i = 0; i < speeds.length; i++) {
      along += speeds[i];
      m.onFix(pointAt(lRoute, along), speedMps: speeds[i], headingDeg: 0, now: i.toDouble(), alongM: along);
      for (var k = 0; k < 60; k++) {
        final t = i + k / 60;
        braking[t] = m.tick(t)!.braking;
      }
    }
    expect(braking[2.5], isFalse); // cruising
    expect(braking[4.5], isTrue); // just slowed from 54 to 36 km/h
    expect(braking[6.0], isTrue);
    expect(braking[8.0], isFalse); // steady again
  });
}
