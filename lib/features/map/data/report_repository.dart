import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../domain/report.dart';

class ReportException implements Exception {
  ReportException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class ReportRepository {
  /// Creates a report. The server may merge it into an existing alert nearby.
  Future<Report> submit(ReportType type, LatLng at);
  Future<List<Report>> nearby(LatLng center, {double radiusKm = 10});

  /// "Masih ada?". Returns the updated alert, or null if it is gone.
  Future<Report?> vote(String id, {required bool stillThere});
}

/// Demo mode: in memory, used when the app is built without API_URL.
class MockReportRepository implements ReportRepository {
  final List<Report> _store = [
    Report(
      id: 'seed-1',
      type: ReportType.police,
      position: LatLng(3.1478, 101.6953),
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Report(
      id: 'seed-2',
      type: ReportType.pothole,
      position: LatLng(3.1390, 101.6869),
      createdAt: DateTime.now().subtract(const Duration(hours: 20)),
    ),
  ];

  @override
  Future<Report> submit(ReportType type, LatLng at) async {
    await Future<void>.delayed(const Duration(milliseconds: 300)); // fake network
    final report = Report(
      id: const Uuid().v4(),
      type: type,
      position: at,
      createdAt: DateTime.now(),
    );
    _store.add(report);
    return report;
  }

  @override
  Future<List<Report>> nearby(LatLng center, {double radiusKm = 10}) async {
    const distance = Distance();
    return _store
        .where((r) => !r.isExpired)
        .where((r) =>
            distance.as(LengthUnit.Kilometer, center, r.position) <= radiusKm)
        .toList();
  }

  @override
  Future<Report?> vote(String id, {required bool stillThere}) async {
    final i = _store.indexWhere((r) => r.id == id);
    if (i < 0) return null;
    final r = _store[i];
    if (!stillThere) {
      _store.removeAt(i);
      return null;
    }
    final updated = Report(
      id: r.id,
      type: r.type,
      position: r.position,
      createdAt: r.createdAt,
      expiresAt: r.expiresAt,
      confirms: r.confirms + 1,
      denies: r.denies,
    );
    _store[i] = updated;
    return updated;
  }
}
