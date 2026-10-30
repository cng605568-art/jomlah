import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';

const _mPerDegLat = 111320.0;
double _mPerDegLng(double lat) => _mPerDegLat * math.cos(lat * math.pi / 180);

/// One raw GPS reading, without any plugin types so it can be unit tested.
class GpsFix {
  const GpsFix({
    required this.position,
    required this.accuracyM,
    required this.speedMps,
    required this.headingDeg,
    required this.time,
  });

  final LatLng position;
  final double accuracyM; // radius of the error circle, in metres
  final double speedMps; // negative = unknown
  final double headingDeg; // negative = unknown
  final DateTime time;
}

class FilteredFix {
  const FilteredFix({
    required this.position,
    required this.speedMps,
    required this.headingDeg,
    this.accuracyM = 10,
  });

  final LatLng position;
  final double speedMps;
  final double headingDeg;

  /// How sure the filter is about [position]: roughly the radius, in metres, it could be off by.
  final double accuracyM;
}

/// Cleans up raw GPS so the car does not jitter or jump.
///
/// 1. Throws away junk: very inaccurate fixes and sudden "teleports".
/// 2. Runs a Kalman filter that tracks position AND velocity. It uses the phone's own speed and
///    heading as extra evidence, which smooths jitter without making the car lag behind.
/// 3. Gives less say to a fix that lands far from where the car must be, even when the phone claims
///    it is accurate. Between tall buildings GPS bounces off walls and can put you 30-40 m sideways
///    for a second or two. If it keeps insisting (3 fixes in a row), it is believed again.
class GpsFilter {
  GpsFilter({this.maxAccuracyM = 35, this.maxSpeedMps = 70, double accelNoise = 2.0})
      : _q = accelNoise * accelNoise;

  final double maxAccuracyM;
  final double maxSpeedMps;
  final double _q; // how hard a car may accelerate or turn, squared

  /// 99% of honest fixes fall inside this (chi-square, 2 degrees of freedom).
  static const _gate = 9.21;
  int _outliers = 0; // fixes in a row that landed outside the gate

  LatLng? _origin; // the estimate is kept relative to this point (re-anchored every fix)
  double _px = 0, _py = 0; // metres east / north of _origin
  double _vx = 0, _vy = 0; // m/s east / north
  double _ppp = 0, _ppv = 0, _pvv = 0; // uncertainty of position and velocity (same on both axes)
  DateTime? _time;
  int _rejected = 0;
  double _heading = 0;

  void reset() {
    _origin = null;
    _time = null;
    _rejected = 0;
    _outliers = 0;
    _px = _py = _vx = _vy = 0;
  }

  void _start(GpsFix fix, double acc) {
    _origin = fix.position;
    _px = 0;
    _py = 0;
    if (fix.speedMps >= 1.0 && fix.headingDeg >= 0) {
      final h = fix.headingDeg * math.pi / 180;
      _vx = fix.speedMps * math.sin(h);
      _vy = fix.speedMps * math.cos(h);
      _heading = fix.headingDeg;
    } else {
      _vx = 0;
      _vy = 0;
      _heading = fix.headingDeg >= 0 ? fix.headingDeg : 0;
    }
    _ppp = acc * acc;
    _ppv = 0;
    _pvv = 4.0;
    _time = fix.time;
    _rejected = 0;
    _outliers = 0;
  }

  /// The cleaned-up reading, or null when this fix was judged to be junk and ignored.
  FilteredFix? accept(GpsFix fix) {
    final acc = math.max(fix.accuracyM, 5.0); // some phones claim 1 m; never believe that
    final origin = _origin;
    final last = _time;
    if (origin == null || last == null) {
      _start(fix, acc);
      return _output();
    }

    final dt = fix.time.difference(last).inMicroseconds / 1e6;
    if (dt <= 0) return null; // out of order

    // Junk 1: too inaccurate. Give up ignoring after 5 in a row (tunnel, parking building).
    if (fix.accuracyM > maxAccuracyM && _rejected < 5) {
      _rejected++;
      return null;
    }
    // Junk 2: teleport. If it keeps insisting (3 in a row), believe it and start again there.
    final jump = haversineM(origin, fix.position);
    if (jump > 50 && jump / dt > maxSpeedMps) {
      _rejected++;
      if (_rejected >= 3) {
        _start(fix, acc);
        return _output();
      }
      return null;
    }
    _rejected = 0;

    // Predict: carry on at the current velocity; uncertainty grows.
    _px += _vx * dt;
    _py += _vy * dt;
    final dt2 = dt * dt;
    var ppp = _ppp + dt * (2 * _ppv + dt * _pvv) + _q * dt2 * dt2 / 4;
    var ppv = _ppv + dt * _pvv + _q * dt2 * dt / 2;
    var pvv = _pvv + _q * dt2;

    // Update 1: where GPS says we are.
    final zx = (fix.position.longitude - origin.longitude) * _mPerDegLng(origin.latitude);
    final zy = (fix.position.latitude - origin.latitude) * _mPerDegLat;
    final yx = zx - _px;
    final yy = zy - _py;
    var r = acc * acc;
    var s = ppp + r;
    // Far outside what the track allows: trust it only as much as the edge of the gate.
    final d2 = (yx * yx + yy * yy) / s;
    if (d2 > _gate && _outliers < 3) {
      _outliers++;
      r *= d2 / _gate;
      s = ppp + r;
    } else {
      _outliers = 0;
    }
    final kp = ppp / s;
    final kv = ppv / s;
    _px += kp * yx;
    _vx += kv * yx;
    _py += kp * yy;
    _vy += kv * yy;
    final ppv0 = ppv;
    ppp = ppp - kp * ppp;
    ppv = ppv0 - kp * ppv0;
    pvv = pvv - kv * ppv0;

    // Update 2: how fast and which way GPS says we are moving (or that we are standing still).
    double? zvx;
    double? zvy;
    double? rv;
    if (fix.speedMps >= 1.0 && fix.headingDeg >= 0) {
      final h = fix.headingDeg * math.pi / 180;
      zvx = fix.speedMps * math.sin(h);
      zvy = fix.speedMps * math.cos(h);
      rv = 1.5 * 1.5;
    } else if (fix.speedMps >= 0 && fix.speedMps < 0.5) {
      zvx = 0;
      zvy = 0;
      rv = 0.5 * 0.5;
    }
    if (rv != null && zvx != null && zvy != null) {
      final sv = pvv + rv;
      final kp2 = ppv / sv;
      final kv2 = pvv / sv;
      final yvx = zvx - _vx;
      final yvy = zvy - _vy;
      _px += kp2 * yvx;
      _vx += kv2 * yvx;
      _py += kp2 * yvy;
      _vy += kv2 * yvy;
      final ppv1 = ppv;
      final pvv1 = pvv;
      ppp = ppp - kp2 * ppv1;
      ppv = ppv1 - kv2 * ppv1;
      pvv = pvv1 - kv2 * pvv1;
    }

    // Re-anchor at the new estimate so the flat-earth maths stays accurate on long trips.
    _origin = LatLng(
      origin.latitude + _py / _mPerDegLat,
      origin.longitude + _px / _mPerDegLng(origin.latitude),
    );
    _px = 0;
    _py = 0;
    _ppp = ppp;
    _ppv = ppv;
    _pvv = pvv;
    _time = fix.time;
    return _output();
  }

  FilteredFix _output() {
    final speed = math.sqrt(_vx * _vx + _vy * _vy);
    if (speed > 1.5) {
      _heading = (math.atan2(_vx, _vy) * 180 / math.pi + 360) % 360;
    }
    return FilteredFix(
      position: _origin!,
      speedMps: speed,
      headingDeg: _heading,
      accuracyM: math.max(3.0, math.sqrt(_ppp)),
    );
  }
}
