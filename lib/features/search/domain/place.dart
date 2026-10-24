import 'package:latlong2/latlong.dart';

class Place {
  const Place({required this.name, required this.subtitle, required this.position});
  final String name;
  final String subtitle; // e.g. "Jalan Ampang, Kuala Lumpur"
  final LatLng position;
}
