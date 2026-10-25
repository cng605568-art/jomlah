import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';

class CarPose {
  const CarPose(this.position, this.headingDeg);
  final LatLng position;
  final double headingDeg;
}

/// Makes the car glide. GPS only arrives about once a second, so between fixes we keep moving
/// the car along its velocity (up to 2.5 s), and ease towards each new fix instead of jumping.
/// Call [onFix] when a cleaned-up fix arrives and [tick] on every frame.
class CarMotion {
  LatLng? _target; // latest position, as of _fixAt
  LatLng? _shown; // where the car is drawn right now
  double _ve = 0, _vn = 0; // m/s east / north
  double _fixAt = 0;
  double _lastTick = 0;
  double _shownHeading = 0;
  double _targetHeading = 0;

  void onFix(LatLng position, {required double speedMps, required double headingDeg, required double now}) {
    _target = position;
    _fixAt = now;
    final h = headingDeg * math.pi / 180;
    _ve = speedMps * math.sin(h);
    _vn = speedMps * math.cos(h);
    _targetHeading = headingDeg;
    final shown = _shown;
    if (shown == null || haversineM(shown, position) > 150) {
      _shown = position; // first fix, or a real jump (resumed from background): do not glide
      _shownHeading = headingDeg;
    }
  }

  /// [now] is seconds on any steady clock. Returns null until the first fix.
  CarPose? tick(double now) {
    final target = _target;
    final shown = _shown;
    if (target == null || shown == null) return null;

    final dt = math.min(math.max(now - _lastTick, 0.0), 0.1);
    _lastTick = now;

    // Where the car should be by now if it kept going.
    final ahead = math.min(math.max(now - _fixAt, 0.0), 2.5);
    final predicted = offsetM(target, _ve * ahead, _vn * ahead);

    // Glide towards it (about 0.2 s to close the gap).
    final a = 1 - math.exp(-dt / 0.2);
    _shown = LatLng(
      shown.latitude + (predicted.latitude - shown.latitude) * a,
      shown.longitude + (predicted.longitude - shown.longitude) * a,
    );

    // Turn the short way round.
    final diff = ((_targetHeading - _shownHeading + 540) % 360) - 180;
    _shownHeading = (_shownHeading + diff * (1 - math.exp(-dt / 0.3)) + 360) % 360;

    return CarPose(_shown!, _shownHeading);
  }
}
