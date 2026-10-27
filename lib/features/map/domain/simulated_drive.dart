import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';
import 'gps_filter.dart';

/// Pretends to be a car driving along a route, so the app can be tested and demoed at a desk.
/// It speeds up and slows down gently, slows for turns, eases to a stop at the end, and can add
/// GPS-style jitter so the filter has something to clean up.
class SimulatedDrive {
  SimulatedDrive({
    required this.shape,
    required this.cumulativeM,
    required this.targetSpeedMps,
    this.slowPointsM = const [],
    this.noiseM = 0,
    math.Random? random,
  }) : _random = random ?? math.Random();

  final List<LatLng> shape;
  final List<double> cumulativeM; // metres from the start to each shape point
  final double targetSpeedMps;
  final List<double> slowPointsM; // distances along the route where a driver would slow (turns)
  final double noiseM; // jitter to add, in metres
  final math.Random _random;

  double _alongM = 0;
  double _speedMps = 0;
  int _seg = 0;

  double get totalM => cumulativeM.isEmpty ? 0 : cumulativeM.last;
  bool get finished => _alongM >= totalM - 0.5;

  /// Moves the pretend car on by [dtSec] seconds and returns what its GPS would report.
  GpsFix step(double dtSec, DateTime now) {
    var want = targetSpeedMps;
    for (final p in slowPointsM) {
      final toTurn = p - _alongM;
      if (toTurn > -10 && toTurn < 60) want = math.min(want, 6.0); // about 22 km/h through a turn
    }
    final remaining = totalM - _alongM;
    if (remaining < 60) want = math.min(want, math.max(2.0, remaining / 6)); // ease into the stop

    final maxChange = 2.5 * dtSec; // gentle: 2.5 m/s every second
    _speedMps += math.max(-maxChange, math.min(maxChange, want - _speedMps));
    _alongM = math.min(totalM, _alongM + _speedMps * dtSec);

    while (_seg < shape.length - 2 && cumulativeM[_seg + 1] < _alongM) {
      _seg++;
    }
    final a = shape[_seg];
    final b = shape[_seg + 1];
    final segLen = cumulativeM[_seg + 1] - cumulativeM[_seg];
    final t = segLen <= 0
        ? 0.0
        : math.min(1.0, math.max(0.0, (_alongM - cumulativeM[_seg]) / segLen));
    var position = LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
    if (noiseM > 0) {
      position = offsetM(position, _gauss() * noiseM, _gauss() * noiseM);
    }
    return GpsFix(
      position: position,
      accuracyM: noiseM > 0 ? math.max(6.0, noiseM * 1.5) : 5.0,
      speedMps: _speedMps,
      headingDeg: bearingDeg(a, b),
      time: now,
    );
  }

  double _gauss() {
    final u1 = 1 - _random.nextDouble(); // never exactly 0, so log() is safe
    final u2 = _random.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}
