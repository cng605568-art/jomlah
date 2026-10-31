import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../domain/traffic.dart';

/// Live traffic: sends speed readings and fetches average speeds near the driver.
abstract class TrafficRepository {
  Future<List<TrafficSegment>> near(LatLng at);
  Future<void> send(List<SpeedSample> samples);
}

/// Builds without an alerts server: no traffic, nothing sent.
class NoTraffic implements TrafficRepository {
  @override
  Future<List<TrafficSegment>> near(LatLng at) async => const [];
  @override
  Future<void> send(List<SpeedSample> samples) async {}
}

/// Talks to the alerts server (worker/): POST /v1/speeds and GET /v1/traffic. Never throws: traffic
/// is a nice-to-have, a missed update just means older colours on the map.
class HttpTrafficRepository implements TrafficRepository {
  HttpTrafficRepository({required this.baseUrl, required this.deviceId, http.Client? client})
      : _http = client ?? http.Client();

  final String baseUrl;
  final String Function() deviceId;
  final http.Client _http;

  @override
  Future<List<TrafficSegment>> near(LatLng at) async {
    // Privacy: only the rough area (about 1 km), like alerts.
    final uri = Uri.parse('$baseUrl/v1/traffic').replace(queryParameters: {
      'lat': at.latitude.toStringAsFixed(2),
      'lng': at.longitude.toStringAsFixed(2),
      'r': '11',
    });
    try {
      final res = await _http.get(uri, headers: {'User-Agent': 'Jomlah/0.1 (beta)'}).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      final list = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['segments'] as List? ?? const [];
      return [for (final s in list) if (s is Map<String, dynamic>) TrafficSegment.fromJson(s)];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> send(List<SpeedSample> samples) async {
    if (samples.isEmpty) return;
    try {
      await _http
          .post(
            Uri.parse('$baseUrl/v1/speeds'),
            headers: {
              'Content-Type': 'application/json',
              'X-Device-Id': deviceId(), // only for the server's spam limit; never stored
              'User-Agent': 'Jomlah/0.1 (beta)',
            },
            body: jsonEncode({'samples': [for (final s in samples) s.toJson()]}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
