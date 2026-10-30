import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../domain/route_plan.dart';
import '../domain/route_prefs.dart';
import '../domain/speed_limits.dart';
import 'polyline.dart';

const _envUrl = String.fromEnvironment('VALHALLA_URL');

/// Dev default: the public FOSSGIS demo server (fair use, rate limited, NOT for production).
/// Point the app at your own server with --dart-define=VALHALLA_URL=https://routing.yourdomain.my
String get valhallaBaseUrl =>
    _envUrl.isEmpty ? 'https://valhalla1.openstreetmap.de' : _envUrl;

class RoutingException implements Exception {
  RoutingException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ValhallaClient {
  ValhallaClient({http.Client? client, String? baseUrl})
      : _http = client ?? http.Client(),
        _base = baseUrl ?? valhallaBaseUrl;

  final http.Client _http;
  final String _base;

  /// Best route first, then up to [alternates] alternatives. Valhalla may return fewer.
  Future<List<RoutePlan>> routes(
    LatLng from,
    LatLng to, {
    RoutePrefs prefs = const RoutePrefs(),
    int alternates = 0,
  }) async {
    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$_base/route'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Jomlah/0.1 (beta)',
            },
            body: jsonEncode({
              'locations': [
                {'lat': from.latitude, 'lon': from.longitude},
                {'lat': to.latitude, 'lon': to.longitude},
              ],
              'costing': prefs.vehicle.costing,
              'costing_options': prefs.costingOptions,
              'units': 'kilometers',
              'language': 'en-US',
              if (alternates > 0) 'alternates': alternates,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw RoutingException('Alamak, tak dapat hubungi server laluan.');
    }

    if (res.statusCode != 200) {
      var msg = 'Tak jumpa laluan (${res.statusCode}).';
      try {
        final err = (jsonDecode(res.body) as Map<String, dynamic>)['error'];
        if (err is String && err.isNotEmpty) msg = err;
      } catch (_) {}
      throw RoutingException(msg);
    }

    final plans = parseValhallaRoutes(utf8.decode(res.bodyBytes));
    if (plans.isEmpty) throw RoutingException('Tak jumpa laluan.');
    return plans;
  }

  /// Legal speed limits along [plan], where OpenStreetMap has them. One request per trip
  /// (and per reroute). Never throws: on any problem the trip simply has no speed-limit sign.
  Future<SpeedLimits> speedLimits(RoutePlan plan, {required String costing}) async {
    final encoded = plan.encodedShape;
    if (encoded == null || encoded.isEmpty) return SpeedLimits.empty;
    try {
      final res = await _http
          .post(
            Uri.parse('$_base/trace_attributes'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Jomlah/0.1 (beta)',
            },
            body: jsonEncode({
              'encoded_polyline': encoded,
              'costing': costing,
              // The shape came from Valhalla itself, so it can follow the exact same edges.
              'shape_match': 'edge_walk',
              'filters': {
                'attributes': ['edge.speed_limit', 'edge.length'],
                'action': 'include',
              },
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return SpeedLimits.empty;
      return parseTraceAttributes(utf8.decode(res.bodyBytes), routeLengthM: plan.totalM);
    } catch (_) {
      return SpeedLimits.empty;
    }
  }
}

/// Main route first, then any alternates.
List<RoutePlan> parseValhallaRoutes(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final trips = <Map<String, dynamic>>[
    json['trip'] as Map<String, dynamic>,
    for (final a in (json['alternates'] as List? ?? const []))
      if (a is Map<String, dynamic>) (a['trip'] as Map<String, dynamic>?) ?? a,
  ];
  return [for (final t in trips) _planFromTrip(t)];
}

RoutePlan _planFromTrip(Map<String, dynamic> trip) {
  final leg = (trip['legs'] as List).first as Map<String, dynamic>;
  final summary = trip['summary'] as Map<String, dynamic>;
  final encoded = leg['shape'] as String;
  return RoutePlan(
    shape: decodePolyline(encoded),
    encodedShape: encoded,
    maneuvers: [
      for (final m in leg['maneuvers'] as List)
        Maneuver.fromJson(m as Map<String, dynamic>),
    ],
    distanceKm: (summary['length'] as num).toDouble(),
    durationSec: (summary['time'] as num).toDouble(),
    hasToll: summary['has_toll'] == true,
    hasHighway: summary['has_highway'] == true,
  );
}
