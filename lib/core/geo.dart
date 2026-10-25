import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

const _earthRadiusM = 6371000.0;

double _rad(double deg) => deg * math.pi / 180;

/// Great-circle distance in metres.
double haversineM(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Initial compass bearing from a to b, 0..360 degrees clockwise from north.
double bearingDeg(LatLng a, LatLng b) {
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// The point [eastM] metres east and [northM] metres north of [p] (flat-earth, fine at street scale).
LatLng offsetM(LatLng p, double eastM, double northM) {
  const mPerDegLat = 111320.0;
  final mPerDegLng = mPerDegLat * math.cos(_rad(p.latitude));
  return LatLng(p.latitude + northM / mPerDegLat, p.longitude + eastM / mPerDegLng);
}

/// Ground distance covered by one logical pixel on a standard 256 px web-mercator map.
double metersPerPixel(double zoom, double latitude) =>
    156543.03392 * math.cos(_rad(latitude)) / math.pow(2, zoom);

/// The point [metres] ahead of [p] when travelling in direction [headingDeg].
LatLng lookAhead(LatLng p, double headingDeg, double metres) {
  final h = _rad(headingDeg);
  return offsetM(p, metres * math.sin(h), metres * math.cos(h));
}
