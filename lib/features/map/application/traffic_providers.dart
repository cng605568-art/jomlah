import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/app_info.dart';
import '../../../core/device_id.dart';
import '../../../core/prefs.dart';
import '../data/traffic_repository.dart';
import '../domain/traffic.dart';

final trafficRepositoryProvider = Provider<TrafficRepository>((ref) {
  if (kDemoMode) return NoTraffic();
  final prefs = ref.read(sharedPrefsProvider);
  return HttpTrafficRepository(baseUrl: kApiUrl, deviceId: () => currentDeviceId(prefs));
});

/// "Share my speed anonymously" in Settings. On unless the driver turns it off.
class TrafficSharingNotifier extends Notifier<bool> {
  static const key = 'traffic.share';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(key) ?? true;

  void set(bool on) {
    state = on;
    ref.read(sharedPrefsProvider).setBool(key, on);
  }
}

final trafficSharingProvider = NotifierProvider<TrafficSharingNotifier, bool>(TrafficSharingNotifier.new);

/// Average speeds near the driver, keyed by stretch. MapScreen refreshes it every minute on a trip.
class TrafficNotifier extends Notifier<Map<String, TrafficSegment>> {
  @override
  Map<String, TrafficSegment> build() => const {};

  Future<void> refresh(LatLng at) async {
    final list = await ref.read(trafficRepositoryProvider).near(at);
    state = {for (final s in list) s.key: s};
  }

  void clear() => state = const {};
}

final trafficProvider = NotifierProvider<TrafficNotifier, Map<String, TrafficSegment>>(TrafficNotifier.new);
