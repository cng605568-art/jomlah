import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jomlah/core/app_theme.dart';
import 'package:jomlah/core/prefs.dart';
import 'package:jomlah/features/map/presentation/overlays.dart';
import 'package:jomlah/features/routing/application/routing_providers.dart';
import 'package:jomlah/features/routing/application/speed_limit_providers.dart';
import 'package:jomlah/features/routing/domain/lanes.dart';
import 'package:jomlah/features/routing/domain/route_plan.dart';
import 'package:jomlah/features/routing/presentation/nav_banner.dart';

// The trip screens without a map or GPS: the route choice, "Jom!", then the turn card and trip bar.

/// Starts in a fixed state; the real begin() and cancel() still run.
class _FakeRouting extends RoutingNotifier {
  _FakeRouting(this.initial);
  final NavState initial;
  @override
  NavState build() => initial;
}

final _exit = Maneuver(
  type: 21,
  instruction: 'Take exit 209 toward Serdang.',
  lengthKm: 1,
  beginIndex: 1,
  endIndex: 2,
  streetNames: const ['Lebuhraya Utara-Selatan'],
  sign: const ExitSign(number: ['209'], name: ['UPM'], toward: ['Serdang', 'Seri Kembangan']),
);

RoutePlan _route(double km, int minutes) => RoutePlan(
      shape: [LatLng(3.0, 101.7), LatLng(3.02, 101.7), LatLng(3.04, 101.7)],
      maneuvers: [_exit],
      distanceKm: km,
      durationSec: minutes * 60.0,
      hasToll: true,
    );

final _fast = _route(12.4, 18);
final _slow = _route(10.9, 22);

NavState _choosing() => NavState(
      destination: LatLng(3.04, 101.7),
      plan: _fast,
      candidates: [_fast, _slow],
      previewing: true,
      next: _exit,
      distanceToNextM: 510,
      remainingM: 4300,
    );

const _lanes = [
  Lane(arrows: ['straight'], use: LaneUse.no),
  Lane(arrows: ['straight'], use: LaneUse.no),
  Lane(arrows: ['slight left', 'straight'], use: LaneUse.best, ourArrow: 'slight left'),
];

Future<ProviderContainer> _pump(WidgetTester tester, NavState start, {List<Lane>? lanes}) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    routingProvider.overrideWith(() => _FakeRouting(start)),
    nextTurnLanesProvider.overrideWith((ref) => ref.watch(routingProvider).navigating ? lanes : null),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Column(
          children: [
            const NavTopArea(placeName: 'Mid Valley Megamall'),
            const Spacer(),
            NavBottomArea(onReport: () {}, onSimulate: (_) {}),
          ],
        ),
      ),
    ),
  ));
  await tester.pump();
  return container;
}

void main() {
  testWidgets('choosing a route shows both options, then Jom! starts the trip', (tester) async {
    final container = await _pump(tester, _choosing(), lanes: _lanes);

    expect(find.text('Mid Valley Megamall'), findsOneWidget);
    expect(find.text('18 min'), findsOneWidget);
    expect(find.text('22 min'), findsOneWidget);
    expect(find.text('Terpantas'), findsOneWidget); // only the quicker one
    expect(find.byType(TurnCard), findsNothing);

    await tester.tap(find.text('Jom!'));
    await tester.pump();
    await tester.pump();

    expect(container.read(routingProvider).navigating, isTrue);
    expect(find.byType(TurnCard), findsOneWidget);
    expect(find.text('510 m'), findsOneWidget);
    expect(find.text('Lebuhraya Utara-Selatan'), findsOneWidget);
    expect(find.textContaining('Keluar 209'), findsOneWidget);
    expect(find.byType(LaneRow), findsOneWidget);
    expect(find.byType(TripBar), findsOneWidget);
    expect(find.textContaining('4.3 km'), findsOneWidget);
  });

  testWidgets('no lane row where the map has no lane arrows', (tester) async {
    await _pump(tester, _choosing().copyWith(previewing: false));
    expect(find.byType(TurnCard), findsOneWidget);
    expect(find.byType(LaneRow), findsNothing);
  });

  testWidgets('while recalculating, the card says so and hides the old lanes', (tester) async {
    await _pump(tester, _choosing().copyWith(previewing: false, rerouting: true), lanes: _lanes);
    expect(find.text('Mengira semula…'), findsWidgets);
    expect(find.byType(LaneRow), findsNothing);
  });

  testWidgets('ending the trip from the trip bar goes back to no route', (tester) async {
    final container = await _pump(tester, _choosing().copyWith(previewing: false));
    await tester.tap(find.byTooltip('Tamat perjalanan'));
    await tester.pump();
    expect(container.read(routingProvider).destination, isNull);
    expect(find.byType(TurnCard), findsNothing);
    expect(find.byType(TripBar), findsNothing);
  });

  testWidgets('looking for a route shows a waiting card that can be closed', (tester) async {
    final container = await _pump(tester, NavState(destination: LatLng(3.04, 101.7), loading: true));
    expect(find.text('Mencari laluan…'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(container.read(routingProvider).destination, isNull);
  });
}
