import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jomlah/core/geo.dart';
import 'package:jomlah/core/prefs.dart';
import 'package:jomlah/features/routing/application/routing_providers.dart';
import 'package:jomlah/features/routing/data/valhalla_client.dart';
import 'package:jomlah/features/routing/domain/route_plan.dart';
import 'package:jomlah/features/routing/domain/route_prefs.dart';

class _FakeClient extends ValhallaClient {
  _FakeClient(this.plan);
  final RoutePlan plan;

  @override
  Future<List<RoutePlan>> routes(
    LatLng from,
    LatLng to, {
    RoutePrefs prefs = const RoutePrefs(),
    int alternates = 0,
  }) async =>
      [plan];
}

void main() {
  final origin = LatLng(3.1390, 101.6869);

  test('snap pulls a nearby GPS point onto the road and ignores a far one', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final plan = RoutePlan(
      shape: [origin, offsetM(origin, 0, 1000)], // 1 km due north
      maneuvers: const [
        Maneuver(
          type: 1,
          instruction: 'Drive north.',
          lengthKm: 1.0,
          beginIndex: 0,
          endIndex: 1,
          streetNames: [],
        ),
        Maneuver(
          type: 4,
          instruction: 'You have arrived.',
          lengthKm: 0,
          beginIndex: 1,
          endIndex: 1,
          streetNames: [],
        ),
      ],
      distanceKm: 1.0,
      durationSec: 100,
    );
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      valhallaClientProvider.overrideWithValue(_FakeClient(plan)),
    ]);
    addTearDown(container.dispose);

    final routing = container.read(routingProvider.notifier);
    await routing.start(origin, offsetM(origin, 0, 1000));
    expect(container.read(routingProvider).previewing, isTrue);
    expect(routing.snap(origin), isNull); // still previewing, no trip yet

    routing.begin();
    expect(container.read(routingProvider).navigating, isTrue);

    final near = offsetM(origin, 20, 300); // 20 m east of the road, 300 m along
    routing.onPosition(near);
    final snap = routing.snap(near);
    expect(snap, isNotNull);
    expect(snap!.distanceM, closeTo(20, 1.5));
    expect(snap.point.longitude, closeTo(origin.longitude, 1e-6));
    expect(snap.point.latitude, closeTo(offsetM(origin, 0, 300).latitude, 1e-5));
    expect(snap.bearingDeg, closeTo(0, 1));

    expect(routing.snap(offsetM(origin, 100, 300)), isNull); // 100 m away: not on this road
  });
}
