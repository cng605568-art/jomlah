import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../domain/report.dart';
import 'report_repository.dart';

/// Talks to server/api. Sends an anonymous, weekly-rotating device id, nothing else.
class HttpReportRepository implements ReportRepository {
  HttpReportRepository({
    required this.baseUrl,
    required this.deviceId,
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String baseUrl;
  final String Function() deviceId;
  final http.Client _http;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Device-Id': deviceId(),
        'User-Agent': 'Jomlah/0.1 (beta)',
      };

  static const _timeout = Duration(seconds: 10);

  @override
  Future<Report> submit(ReportType type, LatLng at) async {
    final res = await _send(() => _http.post(
          Uri.parse('$baseUrl/v1/reports'),
          headers: _headers,
          body: jsonEncode({'type': type.name, 'lat': at.latitude, 'lng': at.longitude}),
        ));
    if (res.statusCode == 429) {
      throw ReportException('Too many reports (429)', tooMany: true);
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ReportException('Alamak, laporan tak masuk (${res.statusCode}).');
    }
    return _reportFrom(res);
  }

  @override
  Future<List<Report>> nearby(LatLng center, {double radiusKm = 10}) async {
    final uri = Uri.parse('$baseUrl/v1/reports').replace(queryParameters: {
      'lat': center.latitude.toStringAsFixed(5),
      'lng': center.longitude.toStringAsFixed(5),
      'r': radiusKm.toString(),
    });
    final res = await _send(() => _http.get(uri, headers: _headers));
    if (res.statusCode != 200) {
      throw ReportException('Tak dapat ambil laporan (${res.statusCode}).');
    }
    final list = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['reports'] as List;
    return [for (final r in list) Report.fromJson(r as Map<String, dynamic>)];
  }

  @override
  Future<Report?> vote(String id, {required bool stillThere}) async {
    final res = await _send(() => _http.post(
          Uri.parse('$baseUrl/v1/reports/$id/vote'),
          headers: _headers,
          body: jsonEncode({'vote': stillThere ? 'confirm' : 'deny'}),
        ));
    if (res.statusCode == 404) return null; // already expired or removed
    if (res.statusCode != 200) {
      throw ReportException('Undi tak masuk (${res.statusCode}).');
    }
    final report = _reportFrom(res);
    return report.isExpired ? null : report;
  }

  Report _reportFrom(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return Report.fromJson(body['report'] as Map<String, dynamic>);
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } catch (_) {
      throw ReportException('Tak dapat hubungi server. Cuba lagi.');
    }
  }
}
