import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';

class CarPose {
  const CarPose(this.position, this.headingDeg, {this.speedMps = 0, this.braking = false});
  final LatLng position;
  final double headingDeg;
  final double speedMps;
  final bool braking; // slowing down hard: brake lights on
}

/// Makes the car glide between GPS fixes, which only arrive about once a second.
///
/// * On a route (a fix snapped onto the road, with its distance along the route), the car is moved
///   ALONG THE ROAD between fixes, so it follows bends and corners instead of cutting across them,
///   and it turns with the road. It never slides backwards while driving.
/// * Off the route it keeps moving along its last velocity, for up to [maxCoastSec].
/// * Either way it never jumps: when a fix disagrees with where the car is drawn, the difference is
///   blended away over a fraction of a second.
///
/// Call [setRoute] with the road being followed (or null), [onFix] for every cleaned-up fix and
/// [tick] on every frame.
class CarMotion {
  static const maxCoastSec = 2.0; // keep moving this long after the last fix, then stop
  static const _catchUpSec = 0.5; // how quickly a gap along the road is made up
  static const _blendSec = 0.35; // how quickly a sideways mismatch is blended away
  static const _jumpM = 150.0; // further than this is a real jump (app resumed): no gliding

  // Route mode
  List<LatLng>? _shape;
  List<double>? _cum;
  int _hint = 0;
  bool _onRoute = false;
  double _alongFix = 0; // metres along the route at the last fix
  double _alongShown = 0; // metres along the route where the car is drawn

  // Free mode
  LatLng? _fixPos;
  double _ve = 0, _vn = 0; // m/s east / north

  double _speed = 0;
  double _fixAt = 0;
  double _lastTick = 0;

  LatLng? _shown; // where the car was last drawn
  double _offE = 0, _offN = 0; // drawn = base + offset (metres); the offset shrinks to zero
  double _heading = 0;
  double _targetHeading = 0;

  double? _prevSpeed;
  double _prevSpeedAt = 0;
  double _brakeUntil = -1;

  /// The road being followed while navigating, or null. A new route is joined smoothly at the next fix.
  void setRoute(List<LatLng>? shape, List<double>? cumulativeM) {
    if (identical(shape, _shape)) return;
    if (_onRoute && _shape != null) {
      // Coast on from where the car is now; the next fix will put it on the new road.
      final h = _targetHeading * math.pi / 180;
      _fixPos = _pointAt(_alongShown);
      _ve = _speed * math.sin(h);
      _vn = _speed * math.cos(h);
      _fixAt = _lastTick;
      _onRoute = false;
    }
    final ok = shape != null &&
        cumulativeM != null &&
        shape.length >= 2 &&
        cumulativeM.length == shape.length;
    _shape = ok ? shape : null;
    _cum = ok ? cumulativeM : null;
    _hint = 0;
  }

  /// A cleaned-up fix. [alongM] is its distance along the route from [setRoute], when it was snapped
  /// onto that road; leave it null when off the route or not navigating.
  void onFix(
    LatLng position, {
    required double speedMps,
    required double headingDeg,
    required double now,
    double? alongM,
  }) {
    _updateBrakes(speedMps, now);
    final speed = math.max(0.0, speedMps);

    if (alongM != null && _shape != null) {
      if (!_onRoute || (alongM - _alongShown).abs() > _jumpM) _alongShown = alongM;
      _onRoute = true;
      _alongFix = alongM;
    } else {
      _onRoute = false;
      _fixPos = position;
      final h = headingDeg * math.pi / 180;
      _ve = speed * math.sin(h);
      _vn = speed * math.cos(h);
      _targetHeading = headingDeg;
    }
    _speed = speed;
    _fixAt = now;

    final base = _base(now);
    final shown = _shown;
    if (shown == null || haversineM(shown, base) > _jumpM) {
      // First fix, or a real jump: put the car straight there.
      _offE = 0;
      _offN = 0;
      _shown = base;
      _heading = _onRoute ? _roadHeading() : headingDeg;
      _targetHeading = _heading;
    } else {
      // Keep drawing the car where it is and blend the difference away over the next frames.
      final (e, n) = _metres(base, shown);
      _offE = e;
      _offN = n;
    }
  }

  /// [now] is seconds on any steady clock. Returns null until the first fix.
  CarPose? tick(double now) {
    if (_shown == null) return null;
    final dt = math.min(math.max(now - _lastTick, 0.0), 0.1);
    _lastTick = now;
    final coasting = now - _fixAt < maxCoastSec;

    if (_onRoute) {
      final total = _cum!.last;
      final ahead = math.min(math.max(now - _fixAt, 0.0), maxCoastSec);
      final predicted = math.min(total, _alongFix + _speed * ahead);
      final gap = predicted - _alongShown;
      // Move at the car's own speed, and close any gap gently.
      var step = (coasting ? _speed : 0.0) * dt + gap * (1 - math.exp(-dt / _catchUpSec));
      if (step < 0) {
        // Never slide backwards while driving; when stopped, creep back at most 1 m/s.
        step = _speed > 0.5 ? 0.0 : math.max(step, -1.0 * dt);
      }
      _alongShown = math.min(total, math.max(0.0, _alongShown + step));
      _targetHeading = _roadHeading();
    }

    final base = _base(now);
    final k = math.exp(-dt / _blendSec);
    _offE *= k;
    _offN *= k;
    final drawn = offsetM(base, _offE, _offN);
    _shown = drawn;

    // Turn the short way round; quicker on a route, where the road's own bearing is smooth already.
    final diff = ((_targetHeading - _heading + 540) % 360) - 180;
    _heading = (_heading + diff * (1 - math.exp(-dt / (_onRoute ? 0.15 : 0.3))) + 360) % 360;

    return CarPose(drawn, _heading, speedMps: coasting ? _speed : 0, braking: now < _brakeUntil);
  }

  /// Where the car would be right now before any blending.
  LatLng _base(double now) {
    if (_onRoute) return _pointAt(_alongShown);
    final p = _fixPos!;
    final ahead = math.min(math.max(now - _fixAt, 0.0), maxCoastSec);
    return offsetM(p, _ve * ahead, _vn * ahead);
  }

  /// Direction of the road around the car, measured over 10 m so corners turn smoothly.
  double _roadHeading() {
    final total = _cum!.last;
    final a = _pointAt(math.max(0.0, _alongShown - 5));
    final b = _pointAt(math.min(total, _alongShown + 5));
    if (haversineM(a, b) < 0.5) return _targetHeading;
    return bearingDeg(a, b);
  }

  /// The point [s] metres along the route.
  LatLng _pointAt(double s) {
    final shape = _shape!;
    final cum = _cum!;
    if (s <= 0) return shape.first;
    if (s >= cum.last) return shape.last;
    var i = math.min(math.max(_hint, 0), cum.length - 2);
    if (cum[i] > s || cum[i + 1] < s) {
      var lo = 0;
      var hi = cum.length - 2;
      while (lo < hi) {
        final mid = (lo + hi + 1) >> 1;
        if (cum[mid] <= s) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      i = lo;
    }
    _hint = i;
    final len = cum[i + 1] - cum[i];
    final t = len <= 0 ? 0.0 : (s - cum[i]) / len;
    final a = shape[i];
    final b = shape[i + 1];
    return LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
  }

  /// Brake lights: on for a moment whenever the car slows down hard.
  void _updateBrakes(double speedMps, double now) {
    final prev = _prevSpeed;
    final dt = now - _prevSpeedAt;
    if (prev != null && dt > 0.2 && dt < 5) {
      final decel = (prev - speedMps) / dt;
      if (decel > 1.2 && prev > 2) _brakeUntil = now + 1.5;
    }
    _prevSpeed = speedMps;
    _prevSpeedAt = now;
  }
}

/// Metres east and north from [a] to [b] (flat-earth, fine at street scale).
(double, double) _metres(LatLng a, LatLng b) {
  const mPerDegLat = 111320.0;
  return (
    (b.longitude - a.longitude) * mPerDegLat * math.cos(a.latitude * math.pi / 180),
    (b.latitude - a.latitude) * mPerDegLat,
  );
}
