import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';

/// The green highway sign for an exit or fork: exit number, road, and where it leads.
/// Valhalla fills this from OpenStreetMap tags, so it only appears where the map has them.
class ExitSign {
  const ExitSign({
    this.number = const [],
    this.branch = const [],
    this.toward = const [],
    this.name = const [],
  });

  final List<String> number; // exit number, e.g. 205
  final List<String> branch; // the road you join, e.g. SUKE
  final List<String> toward; // destinations on the sign, e.g. Putrajaya
  final List<String> name; // interchange name

  bool get isEmpty => number.isEmpty && branch.isEmpty && toward.isEmpty && name.isEmpty;

  String? get numberText => number.isEmpty ? null : number.first;
  String? get branchText => branch.isEmpty ? null : branch.first;
  String? get towardText => toward.isEmpty ? null : toward.take(3).join(' / ');

  factory ExitSign.fromJson(Map<String, dynamic> j) {
    List<String> texts(String key) => [
          for (final e in (j[key] as List? ?? const []))
            if (e is Map && e['text'] is String) e['text'] as String,
        ];
    return ExitSign(
      number: texts('exit_number_elements'),
      branch: texts('exit_branch_elements'),
      toward: texts('exit_toward_elements'),
      name: texts('exit_name_elements'),
    );
  }
}

/// One step of the route, straight from Valhalla's `maneuvers` list.
class Maneuver {
  const Maneuver({
    required this.type,
    required this.instruction,
    required this.lengthKm,
    required this.beginIndex,
    required this.endIndex,
    required this.streetNames,
    this.sign,
  });

  /// Valhalla maneuver type: 10 right, 15 left, 4-6 destination, 26 roundabout...
  /// Voice packs will key off this number, not the English text.
  final int type;
  final String instruction;
  final double lengthKm;
  final int beginIndex; // index into RoutePlan.shape where this maneuver starts
  final int endIndex;
  final List<String> streetNames;
  final ExitSign? sign; // highway sign info, when the map has it

  factory Maneuver.fromJson(Map<String, dynamic> j) => Maneuver(
        type: j['type'] as int,
        instruction: (j['instruction'] as String?) ?? '',
        lengthKm: (j['length'] as num).toDouble(),
        beginIndex: j['begin_shape_index'] as int,
        endIndex: j['end_shape_index'] as int,
        streetNames: ((j['street_names'] as List?) ?? const []).cast<String>(),
        sign: j['sign'] is Map<String, dynamic>
            ? ExitSign.fromJson(j['sign'] as Map<String, dynamic>)
            : null,
      );
}

class RoutePlan {
  RoutePlan({
    required this.shape,
    required this.maneuvers,
    required this.distanceKm,
    required this.durationSec,
    this.hasToll = false,
    this.hasHighway = false,
    this.encodedShape,
  }) : cumulativeM = _cumulative(shape);

  final List<LatLng> shape;

  /// The route line exactly as Valhalla sent it (precision-6 polyline). Sending it back unchanged
  /// lets Valhalla walk the very same roads when we ask for their speed limits.
  final String? encodedShape;
  final List<Maneuver> maneuvers;
  final double distanceKm;
  final double durationSec;
  final bool hasToll; // the route uses at least one toll segment
  final bool hasHighway;

  /// cumulativeM[i] = metres from the start of the route to shape[i].
  final List<double> cumulativeM;
  double get totalM => cumulativeM.isEmpty ? 0 : cumulativeM.last;

  static List<double> _cumulative(List<LatLng> s) {
    final out = List<double>.filled(s.length, 0);
    for (var i = 1; i < s.length; i++) {
      out[i] = out[i - 1] + haversineM(s[i - 1], s[i]);
    }
    return out;
  }
}

/// The part of the route still ahead of the car, starting at [from] (the car) when given.
/// [segment] is the shape segment the car is on, so earlier points are dropped.
List<LatLng> remainingShape(List<LatLng> shape, int segment, {LatLng? from}) {
  if (shape.isEmpty) return const [];
  final start = math.min(math.max(segment + 1, 0), shape.length - 1);
  return [if (from != null) from, ...shape.sublist(start)];
}
