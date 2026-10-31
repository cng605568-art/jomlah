import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';
import '../../routing/domain/route_plan.dart';

// Live traffic, the phone's side. Same stretch rules as the server (worker/src/logic.js): a stretch is
// a 0.0015 degree square (about 165 m) plus one of 8 directions, so each side of a road is separate.

const kSegDeg = 0.0015;

/// 0 = north, 1 = north-east ... 7 = north-west.
int dirOf(double headingDeg) => (((headingDeg % 360) + 360) % 360 / 45).round() % 8;

/// The stretch a point and heading belong to: "row:col:dir".
String stretchKey(LatLng p, double headingDeg) =>
    '${(p.latitude / kSegDeg).floor()}:${(p.longitude / kSegDeg).floor()}:${dirOf(headingDeg)}';

/// The centre of the square a point is in.
LatLng stretchCentre(LatLng p) => LatLng(
      ((p.latitude / kSegDeg).floor() + 0.5) * kSegDeg,
      ((p.longitude / kSegDeg).floor() + 0.5) * kSegDeg,
    );

/// The average speed on one stretch, from the server.
class TrafficSegment {
  const TrafficSegment({required this.centre, required this.dir, required this.kmh, required this.n});

  final LatLng centre;
  final int dir;
  final double kmh;
  final int n; // how many readings the average comes from

  String get key => stretchKey(centre, dir * 45.0);

  factory TrafficSegment.fromJson(Map<String, dynamic> j) => TrafficSegment(
        centre: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        dir: (j['dir'] as num).toInt(),
        kmh: (j['kmh'] as num).toDouble(),
        n: (j['n'] as num).toInt(),
      );
}

/// One reading the phone shares: only the stretch's centre, its direction and the speed.
class SpeedSample {
  const SpeedSample({required this.centre, required this.headingDeg, required this.kmh});
  final LatLng centre;
  final double headingDeg; // the middle of the direction (0, 45, 90...)
  final double kmh;

  Map<String, Object> toJson() =>
      {'lat': centre.latitude, 'lng': centre.longitude, 'heading': headingDeg, 'kmh': kmh};
}

/// Picks readings while driving a trip: one every [every], never in the first or last [skipEndsM]
/// of a trip (so where people live and work is never shared), and hands them out in batches every
/// [batchEvery]. Each reading is rounded to its stretch before it leaves the phone.
class SpeedSampler {
  SpeedSampler({
    this.every = const Duration(seconds: 30),
    this.batchEvery = const Duration(minutes: 2),
    this.skipEndsM = 500,
    this.maxBatch = 10,
  });

  final Duration every;
  final Duration batchEvery;
  final double skipEndsM;
  final int maxBatch;

  DateTime? _lastSample;
  DateTime? _lastBatch;
  final _pending = <SpeedSample>[];

  void add({
    required DateTime now,
    required LatLng at,
    required double headingDeg,
    required double kmh,
    required double alongM,
    required double remainingM,
  }) {
    if (alongM < skipEndsM || remainingM < skipEndsM) return;
    if (_lastSample != null && now.difference(_lastSample!) < every) return;
    _lastSample = now;
    _lastBatch ??= now; // the batch clock starts with the first reading
    _pending.add(SpeedSample(
      centre: stretchCentre(at),
      headingDeg: dirOf(headingDeg) * 45.0,
      kmh: kmh.clamp(0, 200).roundToDouble(),
    ));
    if (_pending.length > maxBatch) _pending.removeAt(0);
  }

  /// The readings to send now, or nothing when it is not time yet.
  List<SpeedSample> takeBatch(DateTime now) {
    final since = _lastBatch;
    if (_pending.isEmpty || since == null || now.difference(since) < batchEvery) return const [];
    _lastBatch = now;
    final out = List<SpeedSample>.of(_pending);
    _pending.clear();
    return out;
  }

  void reset() {
    _lastSample = null;
    _lastBatch = null;
    _pending.clear();
  }
}

enum TrafficLevel { slow, heavy }

/// How bad a stretch is, compared with the speed the road should allow. Heavy needs 3 readings,
/// so one car waiting at a traffic light does not paint the road red.
TrafficLevel? trafficLevel(TrafficSegment s, double expectedKmh) {
  if (s.n >= 3 && (s.kmh < 10 || s.kmh < expectedKmh * 0.25)) return TrafficLevel.heavy;
  if (s.kmh < 40 && s.kmh < expectedKmh * 0.5) return TrafficLevel.slow;
  return null;
}

/// A slow part of the route, in metres from its start.
class SlowStretch {
  SlowStretch(this.startM, this.endM, this.level, this.kmh);
  final double startM;
  double endM;
  final TrafficLevel level;
  final double kmh;
}

/// The slow parts of [plan] in the [lookAheadM] after [fromM], from crowd speeds keyed by stretch.
/// The road should allow [limitAt] km/h where the speed limit is known, otherwise the route's own
/// average speed (at least 30 km/h).
List<SlowStretch> slowStretches(
  RoutePlan plan,
  double fromM,
  Map<String, TrafficSegment> byKey, {
  int? Function(double alongM)? limitAt,
  double lookAheadM = 10000,
  double stepM = 40,
}) {
  final cum = plan.cumulativeM;
  final shape = plan.shape;
  if (byKey.isEmpty || shape.length < 2) return const [];
  final routeAvg = plan.durationSec > 0 ? plan.distanceKm / (plan.durationSec / 3600) : 50.0;
  final fallback = math.max(30.0, routeAvg);
  final end = math.min(plan.totalM, fromM + lookAheadM);

  final out = <SlowStretch>[];
  var i = 1; // shape segment (i-1 .. i) we are in; only ever moves forward
  for (var m = math.max(0.0, fromM); m <= end; m += stepM) {
    while (i < cum.length - 1 && cum[i] < m) {
      i++;
    }
    final a = shape[i - 1];
    final b = shape[i];
    final len = cum[i] - cum[i - 1];
    final t = len <= 0 ? 0.0 : ((m - cum[i - 1]) / len).clamp(0.0, 1.0);
    final p = LatLng(a.latitude + t * (b.latitude - a.latitude), a.longitude + t * (b.longitude - a.longitude));
    final heading = bearingDeg(a, b);
    final seg = byKey[stretchKey(p, heading)] ??
        byKey[stretchKey(p, heading + 45)] ?? // headings near a boundary between two directions
        byKey[stretchKey(p, heading - 45)];
    if (seg == null) continue;
    final level = trafficLevel(seg, (limitAt?.call(m) ?? fallback).toDouble());
    if (level == null) continue;
    final last = out.isEmpty ? null : out.last;
    if (last != null && last.level == level && m - last.endM <= stepM * 3) {
      last.endM = m;
    } else {
      out.add(SlowStretch(m, m, level, seg.kmh));
    }
  }
  for (final s in out) {
    s.endM = math.min(plan.totalM, s.endM + stepM / 2); // cover the last sample's share of road
  }
  return out;
}
