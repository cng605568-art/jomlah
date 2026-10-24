import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../domain/place.dart';

const _envUrl = String.fromEnvironment('PHOTON_URL');

/// Dev default: Komoot's public Photon API (free, fair use, please do not hammer it).
/// For launch, self-host Photon and pass --dart-define=PHOTON_URL=https://search.yourdomain.my
String get photonBaseUrl => _envUrl.isEmpty ? 'https://photon.komoot.io' : _envUrl;

class SearchException implements Exception {
  SearchException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PhotonClient {
  PhotonClient({http.Client? client, String? baseUrl})
      : _http = client ?? http.Client(),
        _base = baseUrl ?? photonBaseUrl;

  final http.Client _http;
  final String _base;

  /// Searches Malaysia only. [near] nudges results towards where the driver is.
  Future<List<Place>> search(String query, {LatLng? near}) async {
    final uri = Uri.parse('$_base/api').replace(queryParameters: {
      'q': query,
      'limit': '8',
      'bbox': '99.6,0.8,119.3,7.4', // minLon,minLat,maxLon,maxLat around Malaysia
      if (near != null) 'lat': near.latitude.toStringAsFixed(5),
      if (near != null) 'lon': near.longitude.toStringAsFixed(5),
    });
    try {
      final res = await _http
          .get(uri, headers: {'User-Agent': 'Jomlah/0.1 (beta)'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw SearchException('Carian gagal (${res.statusCode}).');
      }
      return parsePhotonResponse(utf8.decode(res.bodyBytes));
    } on SearchException {
      rethrow;
    } catch (_) {
      throw SearchException('Carian tak dapat disambung.');
    }
  }
}

/// Photon returns GeoJSON. We keep Malaysian results only (the bbox also covers
/// slivers of Singapore, Brunei and Indonesia).
List<Place> parsePhotonResponse(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final out = <Place>[];
  for (final f in (json['features'] as List? ?? const [])) {
    final feature = f as Map<String, dynamic>;
    final props = (feature['properties'] as Map?)?.cast<String, dynamic>() ?? {};
    if (props['countrycode'] != 'MY') continue;

    final coords = (feature['geometry'] as Map?)?['coordinates'] as List?;
    if (coords == null || coords.length < 2) continue;

    String s(String key) => (props[key] as String?)?.trim() ?? '';
    final street = s('street');
    var title = s('name');
    final titleIsAddress = title.isEmpty;
    if (titleIsAddress) {
      title = [street, s('housenumber')].where((e) => e.isNotEmpty).join(' ');
    }
    if (title.isEmpty) continue;

    final parts = <String>[
      if (!titleIsAddress) street,
      s('district'),
      s('city'),
      s('state'),
    ].where((e) => e.isNotEmpty && e != title).toList();

    out.add(Place(
      name: title,
      subtitle: parts.toSet().join(', '), // set drops "Kuala Lumpur, Kuala Lumpur"
      position: LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
    ));
  }
  return out;
}
