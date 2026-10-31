import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/app_info.dart';
import '../../../core/device_id.dart';
import '../../../core/l10n/language.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/prefs.dart';
import '../../routing/application/routing_providers.dart';
import '../../routing/domain/route_plan.dart';
import '../data/http_report_repository.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  if (kDemoMode) return MockReportRepository(); // no API_URL: fake alerts in memory
  final prefs = ref.read(sharedPrefsProvider);
  return HttpReportRepository(
    baseUrl: kApiUrl,
    deviceId: () => currentDeviceId(prefs),
  );
});

LocationSettings _locationSettings({required bool navigating, required AppStrings s}) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: navigating ? 0 : 5, // metres; 0 = a fix every interval while driving
      intervalDuration: const Duration(seconds: 1),
      // While a trip is running, Android keeps us alive with a notification, so directions
      // and voice keep working with the screen off or another app on top.
      foregroundNotificationConfig: navigating
          ? ForegroundNotificationConfig(
              notificationTitle: s.notificationTitle,
              notificationText: s.notificationText,
              notificationChannelName: s.notificationChannel,
              enableWakeLock: true,
            )
          : null,
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 5,
  );
}

/// Live GPS stream. Asks for permission once, surfaces failures as AsyncError.
/// Restarts (briefly) when a trip starts or ends so the background service matches.
final locationProvider = StreamProvider<Position>((ref) async* {
  final navigating = ref.watch(routingProvider.select((s) => s.navigating));
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    throw Exception('Location permission denied');
  }
  yield* Geolocator.getPositionStream(
    locationSettings: _locationSettings(navigating: navigating, s: ref.read(stringsProvider)),
  );
});

class ReportsState {
  const ReportsState({
    this.reports = const [],
    this.submitting = false,
    this.toast,
  });
  final List<Report> reports;
  final bool submitting;
  final String? toast;

  ReportsState copyWith({
    List<Report>? reports,
    bool? submitting,
    String? toast, // omitting it clears the toast on purpose
  }) =>
      ReportsState(
        reports: reports ?? this.reports,
        submitting: submitting ?? this.submitting,
        toast: toast,
      );
}

String _errorText(Object e, String fallback, AppStrings s) =>
    e is ReportException && e.tooMany ? s.reportTooMany : fallback;

class ReportsNotifier extends Notifier<ReportsState> {
  @override
  ReportsState build() => const ReportsState();

  AppStrings get _s => ref.read(stringsProvider); // messages in the app's language

  /// Replaces the list with what the server says is active near [center].
  /// Quiet on failure: a missed refresh should not nag a driver.
  Future<void> refresh(LatLng center) async {
    try {
      final list = await ref.read(reportRepositoryProvider).nearby(center);
      state = ReportsState(
        reports: list,
        submitting: state.submitting,
        toast: state.toast, // do not swallow a message that has not been shown yet
      );
    } catch (_) {}
  }

  Future<void> report(ReportType type, LatLng at) async {
    if (state.submitting) return;
    state = state.copyWith(reports: state.reports, submitting: true);
    try {
      final saved = await ref.read(reportRepositoryProvider).submit(type, at);
      // The reporter does not need to be asked "still there?" about their own report.
      ref.read(votePromptProvider.notifier).markSeen(saved.id);
      state = state.copyWith(
        reports: [
          for (final r in state.reports)
            if (r.id != saved.id) r,
          saved, // may replace an existing alert the server merged us into
        ],
        submitting: false,
        toast: _s.reported(_s.reportLabel(type)),
      );
    } catch (e) {
      state = state.copyWith(
        reports: state.reports,
        submitting: false,
        toast: _errorText(e, _s.reportFailed, _s),
      );
    }
  }

  /// "Masih ada?" answer.
  Future<void> vote(String id, {required bool stillThere}) async {
    try {
      final updated = await ref
          .read(reportRepositoryProvider)
          .vote(id, stillThere: stillThere);
      state = ReportsState(
        reports: [
          for (final r in state.reports)
            if (r.id != id)
              r
            else if (updated != null)
              updated,
        ],
        submitting: state.submitting,
        toast: stillThere ? _s.voteConfirmed : _s.voteGone,
      );
    } catch (e) {
      state = state.copyWith(
        reports: state.reports,
        toast: _errorText(e, _s.voteFailed, _s),
      );
    }
  }

  void clearToast() => state = state.copyWith(reports: state.reports);

  /// Simulasi in demo mode: a speed camera and a police alert along the pretend route, so the alert
  /// voices can be heard without a car. Kept in this phone's memory only and never sent to a real
  /// server: with a server (API_URL set) this does nothing.
  void addPracticeAlerts(RoutePlan plan) {
    final repo = ref.read(reportRepositoryProvider);
    if (repo is! MockReportRepository) return;
    final now = DateTime.now();
    final practice = [
      for (final (kind, at) in practiceAlertSpots(plan))
        Report(
          id: '$kPracticeIdPrefix$kind',
          type: kind == 'camera' ? ReportType.camera : ReportType.police,
          position: at,
          createdAt: now,
        ),
    ];
    repo.addPractice(practice);
    state = ReportsState(
      reports: [
        for (final r in state.reports)
          if (!r.id.startsWith(kPracticeIdPrefix)) r,
        ...practice,
      ],
      submitting: state.submitting,
      toast: state.toast,
    );
  }

  void clearPracticeAlerts() {
    final repo = ref.read(reportRepositoryProvider);
    if (repo is! MockReportRepository) return;
    repo.removePractice();
    state = ReportsState(
      reports: [
        for (final r in state.reports)
          if (!r.id.startsWith(kPracticeIdPrefix)) r,
      ],
      submitting: state.submitting,
      toast: state.toast,
    );
  }
}

final reportsProvider =
    NotifierProvider<ReportsNotifier, ReportsState>(ReportsNotifier.new);

/// The "Masih ada?" card. Shows one alert at a time and hides itself after 10 seconds.
class VotePromptNotifier extends Notifier<Report?> {
  Timer? _timer;
  final Set<String> _seen = {};

  @override
  Report? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void markSeen(String id) => _seen.add(id);

  /// Called as the car passes an alert. Asks once per alert.
  void maybePrompt(Report r) {
    if (state != null || !_seen.add(r.id)) return;
    show(r);
  }

  /// Also used when the driver taps a pin.
  void show(Report r) {
    _timer?.cancel();
    state = r;
    _timer = Timer(const Duration(seconds: 10), dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    state = null;
  }
}

final votePromptProvider =
    NotifierProvider<VotePromptNotifier, Report?>(VotePromptNotifier.new);
