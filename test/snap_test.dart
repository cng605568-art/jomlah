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

  group('following the car along the route', () {
    Maneuver man(int type, int begin, int end) =>
        Maneuver(type: type, instruction: '', lengthKm: 0, beginIndex: begin, endIndex: end, streetNames: const []);
    RoutePlan planOf(List<LatLng> shape, List<Maneuver> maneuvers) {
      var m = 0.0;
      for (var i = 1; i < shape.length; i++) {
        m += haversineM(shape[i - 1], shape[i]);
      }
      return RoutePlan(shape: shape, maneuvers: maneuvers, distanceKm: m / 1000, durationSec: m / 10);
    }

    Future<(ProviderContainer, RoutingNotifier)> trip(RoutePlan plan) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        valhallaClientProvider.overrideWithValue(_FakeClient(plan)),
      ]);
      addTearDown(c.dispose);
      final r = c.read(routingProvider.notifier);
      await r.start(plan.shape.first, plan.shape.last);
      r.begin();
      return (c, r);
    }

    test('crawling next to a U-turn, the car is not pulled onto the way back', () async {
      // Out 300 m north, U-turn across a 12 m divider, back south.
      final plan = planOf(
        [origin, offsetM(origin, 0, 300), offsetM(origin, 12, 300), offsetM(origin, 12, 0)],
        [man(1, 0, 1), man(12, 1, 3), man(4, 3, 3)],
      );
      final (c, routing) = await trip(plan);
      routing.onPosition(offsetM(origin, 2, 100), headingDeg: 0);
      // Now crawling with no heading, and GPS drifts towards the way back: 4 m from it, 8 m from ours.
      for (var i = 0; i < 6; i++) {
        final p = offsetM(origin, 8, 102.0 + i);
        routing.onPosition(p);
        final snap = routing.snap(p)!;
        expect(snap.alongM, closeTo(102.0 + i, 2));
        expect(snap.point.longitude, closeTo(origin.longitude, 1e-6)); // still on the way out
      }
      expect(c.read(routingProvider).next!.type, 12); // the U-turn is still ahead
    });

    test('a wobbly fix near the edge does not make the car flick on and off the road', () async {
      final plan = planOf([origin, offsetM(origin, 0, 1000)], [man(1, 0, 1), man(4, 1, 1)]);
      final (_, routing) = await trip(plan);
      RouteSnap? at(double east, double north) {
        final p = offsetM(origin, east, north);
        routing.onPosition(p);
        return routing.snap(p);
      }

      expect(at(5, 100), isNotNull);
      expect(at(38, 110), isNotNull); // a bit far, but it was on the road: stays on
      expect(at(50, 120), isNull); // clearly off
      expect(at(38, 130), isNull); // must come properly close again to get back on
      expect(at(20, 140), isNotNull);
    });

    test('one stray fix near a later part of the route does not jump the car there', () async {
      // Round the block: 300 m north, 100 m east, back 300 m south.
      final plan = planOf(
        [origin, offsetM(origin, 0, 300), offsetM(origin, 100, 300), offsetM(origin, 100, 0)],
        [man(1, 0, 1), man(10, 1, 2), man(10, 2, 3), man(4, 3, 3)],
      );
      final (c, routing) = await trip(plan);
      routing.onPosition(offsetM(origin, 1, 50));
      final stray = offsetM(origin, 95, 60); // 5 m from the way back, 95 m from where we are
      routing.onPosition(stray);
      expect(routing.snap(stray), isNull); // not drawn on the far part of the route
      expect(c.read(routingProvider).segment, 0);
      routing.onPosition(offsetM(origin, 1, 62));
      expect(c.read(routingProvider).segment, 0);
      expect(c.read(routingProvider).remainingM, closeTo(700 - 62, 3));

      // Two fixes in a row there: we really did take a shortcut, so follow.
      routing.onPosition(offsetM(origin, 95, 60));
      routing.onPosition(offsetM(origin, 95, 58));
      expect(c.read(routingProvider).segment, 2);
      expect(c.read(routingProvider).remainingM, closeTo(58, 3));
    });

    test('after arriving, the car stays on the road while parking', () async {
      final plan = planOf([origin, offsetM(origin, 0, 1000)], [man(1, 0, 1), man(4, 1, 1)]);
      final (c, routing) = await trip(plan);
      for (final m in [900.0, 950.0, 985.0]) {
        routing.onPosition(offsetM(origin, 2, m), headingDeg: 0);
      }
      expect(c.read(routingProvider).arrived, isTrue);
      final p = offsetM(origin, 7, 996);
      final snap = routing.snap(p);
      expect(snap, isNotNull);
      expect(snap!.point.longitude, closeTo(origin.longitude, 1e-6));
    });

    test('off the route, the line back starts at the nearest point of the route', () {
      final shape = [origin, offsetM(origin, 0, 1000)];
      final p = closestOnSegment(shape, 0, offsetM(origin, 40, 300));
      expect(haversineM(p, offsetM(origin, 0, 300)), lessThan(0.5));
      expect(closestOnSegment(shape, 0, offsetM(origin, 5, -50)), shape.first); // before the start
    });
  });
}
