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
    expect(snap.alongM, closeTo(300, 1.5)); // metres from the start, for the car animation
  });

  test('on a U-turn route, stays on the side of the road it is really driving on', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Out 300 m north, U-turn across a 12 m divider, back 300 m south: the way back is very close.
    final plan = RoutePlan(
      shape: [origin, offsetM(origin, 0, 300), offsetM(origin, 12, 300), offsetM(origin, 12, 0)],
      maneuvers: const [
        Maneuver(
          type: 1,
          instruction: 'Drive north.',
          lengthKm: 0.3,
          beginIndex: 0,
          endIndex: 1,
          streetNames: [],
        ),
        Maneuver(
          type: 12,
          instruction: 'Make a U-turn.',
          lengthKm: 0.31,
          beginIndex: 1,
          endIndex: 3,
          streetNames: [],
        ),
        Maneuver(
          type: 4,
          instruction: 'You have arrived.',
          lengthKm: 0,
          beginIndex: 3,
          endIndex: 3,
          streetNames: [],
        ),
      ],
      distanceKm: 0.612,
      durationSec: 60,
    );
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      valhallaClientProvider.overrideWithValue(_FakeClient(plan)),
    ]);
    addTearDown(container.dispose);

    final routing = container.read(routingProvider.notifier);
    await routing.start(origin, offsetM(origin, 12, 0));
    routing.begin();

    // 150 m out, drifted 7 m towards the divider: 5 m from the way back, 7 m from the way out.
    final p = offsetM(origin, 7, 150);
    routing.onPosition(p, headingDeg: 0); // driving north
    final nav = container.read(routingProvider);
    expect(nav.segment, 0);
    expect(nav.next!.type, 12); // the U-turn is still ahead, not skipped
    expect(nav.distanceToNextM, closeTo(150, 2));

    final snap = routing.snap(p, headingDeg: 0)!;
    expect(snap.bearingDeg, closeTo(0, 1));
    expect(snap.point.longitude, closeTo(origin.longitude, 1e-6));
    expect(snap.alongM, closeTo(150, 1.5));
  });
}
