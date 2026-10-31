import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jomlah/core/prefs.dart';
import 'package:jomlah/features/map/application/providers.dart';
import 'package:jomlah/features/map/data/report_repository.dart';
import 'package:jomlah/features/map/domain/report.dart';
import 'package:jomlah/features/routing/domain/route_plan.dart';

// Once alerts are shared, a pretend drive must never send anything to other drivers.

/// A "server" that remembers what it was asked to do.
class _RecordingServer implements ReportRepository {
  final submitted = <ReportType>[];
  final votes = <String>[];
  final List<Report> live = [
    Report(id: 'real-1', type: ReportType.flood, position: LatLng(3.10, 101.70), createdAt: DateTime.now()),
  ];

  @override
  Future<Report> submit(ReportType type, LatLng at) async {
    submitted.add(type);
    return Report(id: 'new-${submitted.length}', type: type, position: at, createdAt: DateTime.now());
  }

  @override
  Future<List<Report>> nearby(LatLng center, {double radiusKm = 10}) async => live;

  @override
  Future<Report?> vote(String id, {required bool stillThere}) async {
    votes.add(id);
    return null;
  }
}

Future<(ProviderContainer, _RecordingServer)> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final server = _RecordingServer();
  final c = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    reportRepositoryProvider.overrideWithValue(server),
  ]);
  addTearDown(c.dispose);
  return (c, server);
}

final _route = RoutePlan(
  shape: [LatLng(3.10, 101.70), LatLng(3.11, 101.70), LatLng(3.12, 101.70)],
  maneuvers: const [],
  distanceKm: 2.2,
  durationSec: 180,
);

void main() {
  test('normally, reports and votes go to the server', () async {
    final (c, server) = await _setup();
    await c.read(reportsProvider.notifier).report(ReportType.police, LatLng(3.1, 101.7));
    await c.read(reportsProvider.notifier).vote('real-1', stillThere: true);
    expect(server.submitted, [ReportType.police]);
    expect(server.votes, ['real-1']);
  });

  test('during Simulasi, reports and votes stay on the phone', () async {
    final (c, server) = await _setup();
    final reports = c.read(reportsProvider.notifier)..setSimulating(true);
    await reports.report(ReportType.jam, LatLng(3.105, 101.70));
    await reports.vote('real-1', stillThere: false); // passing a real alert on a pretend drive
    expect(server.submitted, isEmpty);
    expect(server.votes, isEmpty);
    expect(c.read(reportsProvider).reports.where((r) => r.type == ReportType.jam), hasLength(1));
    expect(c.read(reportsProvider).toast, contains('Simulasi'));
  });

  test('practice alerts sit on top of real ones, survive refreshes, and go when Simulasi ends', () async {
    final (c, _) = await _setup();
    final reports = c.read(reportsProvider.notifier)
      ..setSimulating(true)
      ..addPracticeAlerts(_route);
    await reports.refresh(LatLng(3.1, 101.7));
    final ids = c.read(reportsProvider).reports.map((r) => r.id).toList();
    expect(ids, contains('real-1'));
    expect(ids.where((id) => id.startsWith(kPracticeIdPrefix)), hasLength(2));

    reports.setSimulating(false);
    await reports.refresh(LatLng(3.1, 101.7));
    expect(c.read(reportsProvider).reports.map((r) => r.id), ['real-1']);
  });
}
