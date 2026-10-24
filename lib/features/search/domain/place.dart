import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';

class Place {
  const Place({required this.name, required this.subtitle, required this.position});
  final String name;
  final String subtitle; // e.g. "Jalan Ampang, Kuala Lumpur"
  final LatLng position;

  Map<String, dynamic> toJson() => {
        'name': name,
        'subtitle': subtitle,
        'lat': position.latitude,
        'lng': position.longitude,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String,
        subtitle: (j['subtitle'] as String?) ?? '',
        position: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
      );
}

/// Newest first. The same place (same name, within 50 m) is moved to the top, not repeated.
List<Place> pushRecent(List<Place> recents, Place p, {int max = 8}) {
  final kept = recents.where(
    (r) => !(r.name == p.name && haversineM(r.position, p.position) < 50),
  );
  return [p, ...kept].take(max).toList();
}
