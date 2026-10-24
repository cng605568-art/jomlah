import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';

/// One step of the route, straight from Valhalla's `maneuvers` list.
class Maneuver {
  const Maneuver({
    required this.type,
    required this.instruction,
    required this.lengthKm,
    required this.beginIndex,
    required this.endIndex,
    required this.streetNames,
  });

  /// Valhalla maneuver type: 10 right, 15 left, 4-6 destination, 26 roundabout...
  /// Voice packs will key off this number, not the English text.
  final int type;
  final String instruction;
  final double lengthKm;
  final int beginIndex; // index into RoutePlan.shape where this maneuver starts
  final int endIndex;
  final List<String> streetNames;

  factory Maneuver.fromJson(Map<String, dynamic> j) => Maneuver(
        type: j['type'] as int,
        instruction: (j['instruction'] as String?) ?? '',
        lengthKm: (j['length'] as num).toDouble(),
        beginIndex: j['begin_shape_index'] as int,
        endIndex: j['end_shape_index'] as int,
        streetNames: ((j['street_names'] as List?) ?? const []).cast<String>(),
      );
}

class RoutePlan {
  RoutePlan({
    required this.shape,
    required this.maneuvers,
    required this.distanceKm,
    required this.durationSec,
  }) : cumulativeM = _cumulative(shape);

  final List<LatLng> shape;
  final List<Maneuver> maneuvers;
  final double distanceKm;
  final double durationSec;

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
