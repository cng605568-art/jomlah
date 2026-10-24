import 'package:flutter_test/flutter_test.dart';
import 'package:jomlah/features/map/domain/report.dart';

void main() {
  test('parses a server report, including whole-number coordinates', () {
    final r = Report.fromJson({
      'id': 'abc',
      'type': 'police',
      'lat': 3, // JSON ints must not crash the parser
      'lng': 101.6953,
      'created_at': '2026-10-24T08:00:00.000Z',
      'expires_at': '2026-10-24T08:45:00.000Z',
      'confirms': 2,
      'denies': 0,
    });
    expect(r.type, ReportType.police);
    expect(r.position.latitude, 3.0);
    expect(r.confirms, 2);
    expect(r.expiresAt, DateTime.parse('2026-10-24T08:45:00.000Z'));
  });

  test("the server's expires_at beats the built-in lifetime", () {
    final gone = Report(
      id: 'x',
      type: ReportType.camera, // normally lives 30 days
      position: Report.fromJson({
        'id': 'p', 'type': 'camera', 'lat': 3.1, 'lng': 101.6,
        'created_at': '2026-10-01T00:00:00Z',
      }).position,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
    );
    expect(gone.isExpired, isTrue);
  });

  test('without expires_at it falls back to createdAt + type lifetime', () {
    final fresh = Report.fromJson({
      'id': 'y', 'type': 'jam', 'lat': 3.1, 'lng': 101.6,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    expect(fresh.isExpired, isFalse);
  });
}
