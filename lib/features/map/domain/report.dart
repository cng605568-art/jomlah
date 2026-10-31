import 'package:latlong2/latlong.dart';

enum ReportType {
  police('Abang Polis', '👮', Duration(minutes: 45)),
  camera('Kamera AES', '📸', Duration(days: 30)),
  flood('Banjir', '🌊', Duration(hours: 3)),
  pothole('Lubang', '🕳️', Duration(days: 7)),
  brokenLorry('Lori Rosak', '🚛', Duration(hours: 2)),
  jam('Jem Teruk', '🐌', Duration(minutes: 30)),
  crash('Kemalangan', '💥', Duration(hours: 1));

  const ReportType(this.label, this.emoji, this.ttl);
  final String label; // the Malay name; screens use AppStrings.reportLabel for the app's language
  final String emoji;
  final Duration ttl; // fallback lifetime; the server's expires_at wins when present
}

class Report {
  const Report({
    required this.id,
    required this.type,
    required this.position,
    required this.createdAt,
    this.expiresAt,
    this.confirms = 0,
    this.denies = 0,
  });

  final String id;
  final ReportType type;
  final LatLng position;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int confirms;
  final int denies;

  bool get isExpired => DateTime.now().isAfter(expiresAt ?? createdAt.add(type.ttl));

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'lat': position.latitude,
        'lng': position.longitude,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        id: j['id'] as String,
        type: ReportType.values.byName(j['type'] as String),
        position: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        createdAt: DateTime.parse(j['created_at'] as String),
        expiresAt:
            j['expires_at'] == null ? null : DateTime.parse(j['expires_at'] as String),
        confirms: (j['confirms'] as num?)?.toInt() ?? 0,
        denies: (j['denies'] as num?)?.toInt() ?? 0,
      );
}
