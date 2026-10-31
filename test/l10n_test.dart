import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jomlah/core/app_theme.dart';
import 'package:jomlah/core/l10n/language.dart';
import 'package:jomlah/core/l10n/strings.dart';
import 'package:jomlah/core/prefs.dart';
import 'package:jomlah/features/map/domain/report.dart';
import 'package:jomlah/features/routing/application/routing_providers.dart';
import 'package:jomlah/features/routing/application/speed_limit_providers.dart';
import 'package:jomlah/features/routing/domain/route_plan.dart';
import 'package:jomlah/features/routing/presentation/nav_banner.dart';
import 'package:jomlah/features/voice/application/voice_providers.dart';
import 'package:jomlah/features/voice/domain/voice_pack.dart';
import 'package:jomlah/features/voice/domain/voice_packs.dart';

const _ms = AppStrings(AppLanguage.ms);
const _en = AppStrings(AppLanguage.en);
const _zh = AppStrings(AppLanguage.zh);

Future<ProviderContainer> _container(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('each language has its own words', () {
    expect(_ms.searchHint, 'Nak ke mana?');
    expect(_en.searchHint, 'Where to?');
    expect(_zh.searchHint, '要去哪里？');
    expect(_zh.reportLabel(ReportType.brokenLorry), '罗里抛锚');
    for (final s in [_ms, _en, _zh]) {
      final labels = {for (final t in ReportType.values) s.reportLabel(t)};
      expect(labels.length, ReportType.values.length, reason: s.language.name); // no two alike
      for (var type = 0; type <= 40; type++) {
        expect(s.maneuver(type), isNotEmpty);
      }
    }
  });

  test('filled-in texts have no {placeholders} left', () {
    for (final s in [_ms, _en, _zh]) {
      final texts = [
        s.shortcutHowTo(s.setAsHome),
        s.placeSaved(s.home),
        s.jamQuestion(s.reportLabel(ReportType.jam)),
        s.speedLimit(80),
        s.minutes(12),
        s.arriveAt('21:52'),
        s.exitNumber('209'),
        s.towards('Serdang'),
        s.reported(s.reportLabel(ReportType.police)),
        s.stillThere(s.reportLabel(ReportType.police)),
        s.duration(const Duration(minutes: 65)),
      ];
      for (final t in texts) {
        expect(t.contains('{'), isFalse, reason: '${s.language.name}: $t');
      }
    }
    expect(_zh.minutes(12), '12 分钟');
    expect(_zh.duration(const Duration(minutes: 65)), '1 小时 05 分钟');
    expect(_ms.duration(const Duration(minutes: 65)), '1 j 05 min');
    expect(_en.arriveAt('21:52'), 'arrive 21:52');
  });

  test('the exit sign line follows the language', () {
    const sign = ExitSign(number: ['205'], branch: ['SUKE'], toward: ['Putrajaya', 'Cyberjaya']);
    expect(signText(sign, _zh), '205 号出口 · SUKE · 往 Putrajaya / Cyberjaya');
    expect(signText(sign, _en), 'Exit 205 · SUKE · to Putrajaya / Cyberjaya');
  });

  test('first run follows the phone: Chinese phones get Chinese, others Malay', () {
    expect(defaultLanguage(const Locale('zh', 'CN')), AppLanguage.zh);
    expect(defaultLanguage(const Locale('zh', 'TW')), AppLanguage.zh);
    expect(defaultLanguage(const Locale('en', 'MY')), AppLanguage.ms);
    expect(defaultLanguage(const Locale('ms')), AppLanguage.ms);
  });

  test('the chosen language is remembered', () async {
    final c = await _container({LanguageNotifier.key: 'en'});
    expect(c.read(languageProvider), AppLanguage.en);
    expect(c.read(stringsProvider).searchHint, 'Where to?');
    c.read(languageProvider.notifier).set(AppLanguage.zh);
    expect(c.read(stringsProvider).searchHint, '要去哪里？');
    final prefs = c.read(sharedPrefsProvider);
    expect(prefs.getString(LanguageNotifier.key), 'zh');
  });

  test('a new user on Chinese starts with a Mandarin voice', () async {
    final c = await _container({LanguageNotifier.key: 'zh'});
    expect(c.read(voiceSettingsProvider).pack.id, kZhFriend.id);
  });

  test('changing the language changes the voice, unless it already speaks it', () async {
    final c = await _container({LanguageNotifier.key: 'ms'});
    final voice = c.read(voiceSettingsProvider.notifier);
    expect(c.read(voiceSettingsProvider).pack.id, kMamakBoss.id);

    voice.matchLanguage(AppLanguage.zh);
    expect(c.read(voiceSettingsProvider).pack.id, kZhFriend.id);

    voice.setPack(kZhPlain); // the user prefers the plain Mandarin voice
    voice.matchLanguage(AppLanguage.zh);
    expect(c.read(voiceSettingsProvider).pack.id, kZhPlain.id); // kept

    voice.matchLanguage(AppLanguage.en);
    expect(c.read(voiceSettingsProvider).pack.id, kSerious.id);
    voice.setPack(kKlite);
    voice.matchLanguage(AppLanguage.en);
    expect(c.read(voiceSettingsProvider).pack.id, kKlite.id); // also English: kept
  });

  test('every voice knows its language, and each language has one', () {
    expect(voiceLanguage(kMamakBoss), AppLanguage.ms);
    expect(voiceLanguage(kSerious), AppLanguage.en);
    expect(voiceLanguage(kZhFriend), AppLanguage.zh);
    expect(voiceLanguage(kZhPlain), AppLanguage.zh);
    for (final l in AppLanguage.values) {
      expect(voiceLanguage(defaultVoiceFor(l)), l);
    }
  });

  test('Mandarin voices say exits, distances and roundabouts in Chinese', () {
    expect(spokenExit(const ExitSign(number: ['209'], name: ['UPM']), word: kZhPlain.exitWord), '出口 2 0 9, UPM');
    expect(spokenDistance(480, kZhPlain), '500 米');
    expect(spokenDistance(1234, kZhFriend), '1.2 公里');
    expect(spokenOrdinal(2, kZhPlain), '第二');
    final line = pickLine(
      kZhPlain.advance[Cue.exitLeft],
      distance: '500 米',
      street: '',
      exit: '出口 2 0 9, UPM',
      toward: 'Serdang',
      rng: _First(),
    )!;
    expect(line.text, '500 米后从左侧出口 2 0 9, UPM驶出，往Serdang方向。');
  });

  testWidgets('the trip screens speak Chinese', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => call.method == 'requestPermissions' ? <int, int>{} : 0,
    );
    final c = await _container({LanguageNotifier.key: 'zh'});
    final turn = Maneuver(
      type: 15,
      instruction: 'Turn left.',
      lengthKm: 1,
      beginIndex: 1,
      endIndex: 2,
      streetNames: const [], // no street name: the card says the turn itself
    );
    final plan = RoutePlan(
      shape: [LatLng(3.0, 101.7), LatLng(3.02, 101.7), LatLng(3.04, 101.7)],
      maneuvers: [turn],
      distanceKm: 4.4,
      durationSec: 600,
      hasToll: true,
    );
    final container = ProviderContainer(
      parent: c,
      overrides: [
        routingProvider.overrideWith(() => _Fixed(NavState(
              destination: LatLng(3.04, 101.7),
              plan: plan,
              candidates: [plan],
              previewing: true,
              next: turn,
              distanceToNextM: 300,
              remainingM: 4300,
            ))),
        nextTurnLanesProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: AppLanguage.zh.locale,
        supportedLocales: [for (final l in AppLanguage.values) l.locale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => StringsScope(strings: _zh, child: child!),
        home: Scaffold(
          body: Column(children: [
            const NavTopArea(),
            const Spacer(),
            NavBottomArea(onReport: () {}, onSimulate: (_) {}),
          ]),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('选择路线'), findsOneWidget);
    expect(find.text('10 分钟'), findsOneWidget);
    expect(find.text('收费'), findsOneWidget);
    expect(find.text('已选目的地'), findsOneWidget);

    await tester.tap(find.text('出发！'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('左转'), findsOneWidget); // the turn card's title
    expect(find.textContaining('抵达'), findsOneWidget); // the trip bar
  });
}

class _Fixed extends RoutingNotifier {
  _Fixed(this.initial);
  final NavState initial;
  @override
  NavState build() => initial;
}

class _First implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}
