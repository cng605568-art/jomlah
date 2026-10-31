import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jomlah/core/app_theme.dart';
import 'package:jomlah/core/l10n/language.dart';
import 'package:jomlah/core/l10n/strings.dart';
import 'package:jomlah/core/prefs.dart';
import 'package:jomlah/features/map/presentation/car_marker.dart';
import 'package:jomlah/features/map/presentation/overlays.dart';
import 'package:jomlah/features/onboarding/presentation/onboarding_screen.dart';
import 'package:jomlah/features/search/presentation/search_box.dart';
import 'package:jomlah/features/settings/presentation/settings_button.dart';

// Draws the main screens from the real widgets into PNG pictures, to check the look without a phone.
// Off by default. The "UI previews" workflow runs it with UI_PREVIEW=1 and --update-goldens and puts
// the pictures on the ui-previews branch. The map underneath is a simple drawing, not real tiles, and
// the layout numbers mirror MapScreen.

final _enabled = Platform.environment['UI_PREVIEW'] == '1';

Future<void> _loadFonts() async {
  final jakarta = FontLoader('PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    jakarta.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await jakarta.load();
  final iconsPath = Platform.environment['MATERIAL_ICONS'] ?? '';
  if (iconsPath.isNotEmpty && File(iconsPath).existsSync()) {
    final bytes = File(iconsPath).readAsBytesSync();
    final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)));
    await icons.load();
  }
  // Phones bring their own Chinese font; the test machine does not, so the workflow fetches one.
  final cjkPath = Platform.environment['CJK_FONT'] ?? '';
  if (cjkPath.isNotEmpty && File(cjkPath).existsSync()) {
    final bytes = File(cjkPath).readAsBytesSync();
    final cjk = FontLoader('NotoSansSC')..addFont(Future.value(ByteData.sublistView(bytes)));
    await cjk.load();
  }
}

/// The app's theme and language setup, as in main.dart, plus the Chinese test font as a fallback.
Widget _app(Widget home, {AppLanguage lang = AppLanguage.ms}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(fontFallback: const ['NotoSansSC']),
    locale: lang.locale,
    supportedLocales: [for (final l in AppLanguage.values) l.locale],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => StringsScope(strings: AppStrings(lang), child: child!),
    home: home,
  );
}

/// A plain street map: blocks, a park, a river and roads, plus an optional route line.
class _FakeMap extends CustomPainter {
  const _FakeMap({this.route = const [], this.altRoute = const []});
  final List<Offset> route;
  final List<Offset> altRoute;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEDE9E1));
    final block = Paint()..color = const Color(0xFFE3DFD6);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 150, 190), block);
    canvas.drawRect(const Rect.fromLTWH(190, 230, 210, 160), block);
    canvas.drawRect(const Rect.fromLTWH(230, 620, 170, 240), block);
    canvas.drawRect(const Rect.fromLTWH(20, 430, 150, 150), Paint()..color = const Color(0xFFD9EAD0));
    final river = Path()
      ..moveTo(-10, 610)
      ..cubicTo(120, 560, 260, 640, 400, 590);
    canvas.drawPath(river, Paint()..color = const Color(0xFFAAD3DF)..style = PaintingStyle.stroke..strokeWidth = 22);
    final roads = [
      [const Offset(175, -10), const Offset(175, 860)],
      [const Offset(-10, 410), const Offset(400, 410)],
      [const Offset(-10, 210), const Offset(400, 120)],
      [const Offset(60, 860), const Offset(330, -10)],
    ];
    for (final pass in [(const Color(0xFFD4CFC6), 30.0), (const Color(0xFFFFFFFF), 24.0)]) {
      final p = Paint()
        ..color = pass.$1
        ..strokeWidth = pass.$2
        ..style = PaintingStyle.stroke;
      for (final r in roads) {
        canvas.drawLine(r[0], r[1], p);
      }
    }
    void line(List<Offset> pts, Color edge, Color fill, double w) {
      if (pts.length < 2) return;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      for (final pass in [(edge, w + 5), (fill, w)]) {
        canvas.drawPath(
          path,
          Paint()
            ..color = pass.$1
            ..strokeWidth = pass.$2
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    line(altRoute, const Color(0xFF33415E), AppColors.routeOption, 6);
    line(route, AppColors.routeBorder, AppColors.route, 8);
  }

  @override
  bool shouldRepaint(_FakeMap oldDelegate) => false;
}

Widget _phone(
  Widget overlay, {
  List<Offset> route = const [],
  List<Offset> alt = const [],
  Offset car = const Offset(175, 410),
  AppLanguage lang = AppLanguage.ms,
}) =>
    _app(
      Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _FakeMap(route: route, altRoute: alt))),
            Positioned(left: car.dx - 36, top: car.dy - 36, child: const SizedBox(width: 72, height: 72, child: CarMarker(headingDeg: 0))),
            Positioned.fill(child: overlay),
          ],
        ),
      ),
      lang: lang,
    );

/// Saved settings for a scene: the app language and nothing else.
Future<SharedPreferences> _prefs({AppLanguage lang = AppLanguage.ms}) async {
  SharedPreferences.setMockInitialValues({LanguageNotifier.key: lang.code});
  return SharedPreferences.getInstance();
}

/// Tests draw shadows as hard blocks by default; previews should look like the phone.
Future<void> _withShadows(WidgetTester tester, Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    // Every layer keeps its old picture until it is painted again, so repaint them all.
    for (final r in tester.allRenderObjects) {
      r.markNeedsPaint();
    }
    await tester.pump();
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

/// Phone-sized test screen with the usual status and gesture bars.
Future<void> _setPhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2.0;
  tester.view.padding = const FakeViewPadding(top: 80, bottom: 48);
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  const bottomInset = 24.0; // matches FakeViewPadding(bottom: 48) at 2x
  const browseBase = bottomInset + 28;
  const driveBase = TripBar.height + bottomInset + 16;

  testWidgets('1 browsing the map', (tester) async {
    await _setPhone(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: _phone(Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SearchBox(onPick: (_) {}, trailing: const SettingsButton()),
            ),
          ),
        ),
        const Positioned(left: 16, bottom: browseBase, child: SpeedCard(kmh: 0)),
        Positioned(right: 16, bottom: browseBase, child: ReportButton(onPressed: () {})),
        Positioned(
          right: 22,
          bottom: browseBase + 76,
          child: MapButton(icon: Icons.my_location_rounded, onPressed: () {}, tooltip: 'Lokasi saya'),
        ),
      ])),
    ));
    await tester.pumpAndSettle();
    await _withShadows(tester, () => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/1_browse.png')));
  }, skip: !_enabled);

  testWidgets('2 report grid', (tester) async {
    await _setPhone(tester);
    await tester.pumpWidget(_phone(Stack(children: [
      Positioned.fill(child: Container(color: const Color(0x73000000))),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 34, 18, 18 + bottomInset),
          child: ReportGrid(onPick: (_) {}, onVoice: () {}),
        ),
      ),
    ])));
    await tester.pumpAndSettle();
    await _withShadows(tester, () => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/2_report.png')));
  }, skip: !_enabled);

  testWidgets('3 choosing a route', (tester) async {
    await _setPhone(tester);
    await tester.pumpWidget(_phone(
      Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TopBackBar(title: 'Mid Valley Megamall', onBack: () {}),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: RouteOptionsPanel(
            options: const [
              RouteOption(minutes: 18, km: 12.4, fastest: true, toll: true),
              RouteOption(minutes: 22, km: 10.9),
            ],
            selected: 0,
            onSelect: (_) {},
            onGo: () {},
            simulate: const SimulateButtonFace(),
          ),
        ),
      ]),
      car: const Offset(175, 470),
      route: const [Offset(175, 470), Offset(175, 160), Offset(330, 130), Offset(360, 300)],
      alt: const [Offset(175, 470), Offset(175, 410), Offset(330, 410), Offset(360, 300)],
    ));
    await tester.pumpAndSettle();
    await _withShadows(tester, () => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/3_choose.png')));
  }, skip: !_enabled);

  testWidgets('4 driving', (tester) async {
    await _setPhone(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: _phone(
        Stack(children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TurnCard(
                  icon: Icons.fork_left,
                  distance: '510 m',
                  title: 'Lebuhraya Utara-Selatan',
                  sign: 'Keluar 209 · ke Serdang / Seri Kembangan',
                  lanes: [
                    LaneArrow(Icons.turn_slight_left, LaneLook.best),
                    LaneArrow(Icons.turn_slight_left, LaneLook.ok),
                    LaneArrow(Icons.straight, LaneLook.off),
                    LaneArrow(Icons.straight, LaneLook.off),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TripBar(minutes: 12, detail: '4.3 km · tiba 21:52', onReport: () {}, onEnd: () {}, onVoice: () {}),
          ),
          const Positioned(left: 16, bottom: driveBase, child: SpeedCard(kmh: 62)),
          const Positioned(left: 92, bottom: driveBase + 4, child: SpeedLimitSign(kph: 60)),
          const Positioned(right: 16, bottom: driveBase, child: SettingsButton(glass: true)),
        ]),
        car: const Offset(175, 600),
        route: const [Offset(175, 600), Offset(175, 300), Offset(400, 250)],
      ),
    ));
    await tester.pumpAndSettle();
    await _withShadows(tester, () => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/4_drive.png')));
  }, skip: !_enabled);

  testWidgets('5 over the speed limit', (tester) async {
    await _setPhone(tester);
    await tester.pumpWidget(_phone(const Stack(children: [
      Positioned(left: 16, bottom: driveBase, child: SpeedCard(kmh: 74, over: true)),
      Positioned(left: 92, bottom: driveBase + 4, child: SpeedLimitSign(kph: 60)),
    ])));
    await tester.pumpAndSettle();
    await _withShadows(tester, () => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/5_over_limit.png')));
  }, skip: !_enabled);

  // ---- The same screens in Chinese ----
  testWidgets('6 zh first run', (tester) async {
    await _setPhone(tester);
    final prefs = await _prefs(lang: AppLanguage.zh);
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: _app(OnboardingScreen(onDone: () {}), lang: AppLanguage.zh),
    ));
    await tester.pumpAndSettle();
    await _withShadows(tester, () => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/6_zh_first_run.png')));
  }, skip: !_enabled);

  testWidgets('7 zh browsing', (tester) async {
    await _setPhone(tester);
    final prefs = await _prefs(lang: AppLanguage.zh);
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: _phone(
        Stack(children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SearchBox(onPick: (_) {}, trailing: const SettingsButton()),
              ),
            ),
          ),
          const Positioned(left: 16, bottom: browseBase, child: SpeedCard(kmh: 0)),
          Positioned(right: 16, bottom: browseBase, child: ReportButton(onPressed: () {})),
        ]),
        lang: AppLanguage.zh,
      ),
    ));
    await tester.pumpAndSettle();
    await _withShadows(tester, () => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/7_zh_browse.png')));
  }, skip: !_enabled);

  testWidgets('8 zh choosing a route', (tester) async {
    await _setPhone(tester);
    await tester.pumpWidget(_phone(
      Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TopBackBar(title: 'Mid Valley Megamall', onBack: () {}),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: RouteOptionsPanel(
            options: const [
              RouteOption(minutes: 18, km: 12.4, fastest: true, toll: true),
              RouteOption(minutes: 22, km: 10.9),
            ],
            selected: 0,
            onSelect: (_) {},
            onGo: () {},
            simulate: const SimulateButtonFace(),
          ),
        ),
      ]),
      car: const Offset(175, 470),
      route: const [Offset(175, 470), Offset(175, 160), Offset(330, 130), Offset(360, 300)],
      alt: const [Offset(175, 470), Offset(175, 410), Offset(330, 410), Offset(360, 300)],
      lang: AppLanguage.zh,
    ));
    await tester.pumpAndSettle();
    await _withShadows(tester, () => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/8_zh_choose.png')));
  }, skip: !_enabled);

  testWidgets('9 zh driving', (tester) async {
    await _setPhone(tester);
    final prefs = await _prefs(lang: AppLanguage.zh);
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: _phone(
        Stack(children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TurnCard(
                  icon: Icons.fork_left,
                  distance: '510 m',
                  title: 'Lebuhraya Utara-Selatan',
                  sign: '209 号出口 · 往 Serdang / Seri Kembangan',
                  lanes: [
                    LaneArrow(Icons.turn_slight_left, LaneLook.best),
                    LaneArrow(Icons.turn_slight_left, LaneLook.ok),
                    LaneArrow(Icons.straight, LaneLook.off),
                    LaneArrow(Icons.straight, LaneLook.off),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TripBar(minutes: 12, detail: '4.3 km · 21:52 抵达', onReport: () {}, onEnd: () {}, onVoice: () {}),
          ),
          const Positioned(left: 16, bottom: driveBase, child: SpeedCard(kmh: 62)),
          const Positioned(left: 92, bottom: driveBase + 4, child: SpeedLimitSign(kph: 60)),
          const Positioned(right: 16, bottom: driveBase, child: SettingsButton(glass: true)),
        ]),
        car: const Offset(175, 600),
        route: const [Offset(175, 600), Offset(175, 300), Offset(400, 250)],
        lang: AppLanguage.zh,
      ),
    ));
    await tester.pumpAndSettle();
    await _withShadows(tester, () => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9_zh_drive.png')));
  }, skip: !_enabled);

  testWidgets('10 zh settings', (tester) async {
    await _setPhone(tester);
    final prefs = await _prefs(lang: AppLanguage.zh);
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: _phone(
        const Stack(children: [Positioned(right: 16, bottom: driveBase, child: SettingsButton(glass: true))]),
        lang: AppLanguage.zh,
      ),
    ));
    await tester.tap(find.byType(SettingsButton));
    await tester.pumpAndSettle();
    await _withShadows(tester, () => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/10_zh_settings.png')));
  }, skip: !_enabled);
}
