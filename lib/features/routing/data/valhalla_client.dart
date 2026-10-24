import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../domain/route_plan.dart';
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

  Future<RoutePlan> route(LatLng from, LatLng to) async {
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
              'costing': 'auto',
              'directions_options': {'units': 'kilometers', 'language': 'en-US'},
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

    final trip = (jsonDecode(res.body) as Map<String, dynamic>)['trip']
        as Map<String, dynamic>;
    final leg = (trip['legs'] as List).first as Map<String, dynamic>;
    final summary = trip['summary'] as Map<String, dynamic>;

    return RoutePlan(
      shape: decodePolyline(leg['shape'] as String),
      maneuvers: [
        for (final m in leg['maneuvers'] as List)
          Maneuver.fromJson(m as Map<String, dynamic>),
      ],
      distanceKm: (summary['length'] as num).toDouble(),
      durationSec: (summary['time'] as num).toDouble(),
    );
  }
}
