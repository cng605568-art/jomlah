import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';
import 'route_plan.dart';

/// How a lane relates to our turn.
enum LaneUse {
  best, // the lane to be in
  ok, // also leads our way
  no, // goes somewhere else
}

/// One lane on the road before a turn, as painted: lanes are listed left to right.
class Lane {
  const Lane({required this.arrows, required this.use, this.ourArrow});

  /// Painted arrows, OSRM words: "left", "slight left", "sharp left", "straight", "right",
  /// "slight right", "sharp right", "uturn", "none" (no arrow painted).
  final List<String> arrows;
  final LaneUse use;

  /// When several arrows are painted, the one that matches our turn.
  final String? ourArrow;

  /// The arrow to draw for this lane.
  String get shown => ourArrow ?? (arrows.isEmpty ? 'none' : arrows.first);
}

/// Lane arrows for the turns of [plan], keyed by each turn's [Maneuver.beginIndex].
///
/// [body] is Valhalla's `/trace_route` answer in OSRM format for the plan's own shape. There, each
/// step starts at a turn and its first intersection lists the lanes on the way into that turn.
/// Steps are matched to our turns by position (they line up to the metre on the same shape).
/// Only turns where OpenStreetMap has lane tags appear, and only when the lanes actually say
/// something: if every lane leads our way, there is nothing to choose.
Map<int, List<Lane>> parseLanes(String body, RoutePlan plan) {
  final out = <int, List<Lane>>{};
  final Object? json;
  try {
    json = jsonDecode(body);
  } catch (_) {
    return out;
  }
  if (json is! Map<String, dynamic>) return out;
  final routes = (json['matchings'] ?? json['routes']) as List?;
  if (routes == null || routes.isEmpty || routes.first is! Map) return out;
  final legs = (routes.first as Map)['legs'] as List? ?? const [];

  for (final leg in legs) {
    if (leg is! Map) continue;
    for (final step in (leg['steps'] as List? ?? const [])) {
      if (step is! Map) continue;
      final loc = (step['maneuver'] as Map?)?['location'];
      final ints = step['intersections'];
      if (loc is! List || loc.length < 2 || ints is! List || ints.isEmpty || ints.first is! Map) continue;
      final raw = (ints.first as Map)['lanes'];
      if (raw is! List || raw.length < 2) continue;

      final lanes = [
        for (final l in raw)
          if (l is Map)
            Lane(
              arrows: [for (final a in (l['indications'] as List? ?? const [])) '$a'],
              use: l['active'] == true
                  ? LaneUse.best
                  : l['valid'] == true
                      ? LaneUse.ok
                      : LaneUse.no,
              ourArrow: l['valid_indication'] is String ? l['valid_indication'] as String : null,
            ),
      ];
      final useful = lanes.any((l) => l.use != LaneUse.no) && lanes.any((l) => l.use == LaneUse.no);
      if (!useful) continue;

      final at = LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble());
      final turn = _turnAt(plan, at);
      if (turn != null) out[turn.beginIndex] = lanes;
    }
  }
  return out;
}

/// The turn of [plan] that starts at [at] (within 30 m), if any.
Maneuver? _turnAt(RoutePlan plan, LatLng at) {
  Maneuver? best;
  var bestD = 30.0;
  for (final m in plan.maneuvers) {
    if (m.beginIndex < 0 || m.beginIndex >= plan.shape.length) continue;
    final d = haversineM(at, plan.shape[m.beginIndex]);
    if (d <= bestD) {
      bestD = d;
      best = m;
    }
  }
  return best;
}
