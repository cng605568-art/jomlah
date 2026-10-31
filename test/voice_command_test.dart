import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jomlah/core/l10n/language.dart';
import 'package:jomlah/core/prefs.dart';
import 'package:jomlah/features/map/domain/report.dart';
import 'package:jomlah/features/voice/data/speech_input.dart';
import 'package:jomlah/features/voice/domain/voice_command.dart';
import 'package:jomlah/features/voice/presentation/voice_report_sheet.dart';

// Voice reports: what drivers say, in Malay, English, Chinese or a mix, becomes the right alert.

ReportType? hear(String s) => reportFromSpeech([s]);

/// Pretends to be the phone's speech recogniser.
class _FakeSpeech implements SpeechInput {
  _FakeSpeech({this.available = true, this.says = const []});
  final bool available;
  final List<String> says;
  int starts = 0;
  bool stopped = false;

  @override
  Future<bool> init() async => available;

  @override
  Future<void> start({
    required AppLanguage language,
    required void Function(List<String> heard, bool isFinal) onWords,
    required void Function() onDone,
  }) async {
    starts++;
    scheduleMicrotask(() {
      for (var i = 0; i < says.length; i++) {
        onWords([says[i]], i == says.length - 1);
      }
      onDone();
    });
  }

  @override
  Future<void> stop() async => stopped = true;
}

void main() {
  test('Malay', () {
    expect(hear('Ada polis kat depan'), ReportType.police);
    expect(hear('abang polis buat sekatan jalan raya'), ReportType.police);
    expect(hear('kamera AES'), ReportType.camera);
    expect(hear('Banjir!'), ReportType.flood);
    expect(hear('ada lubang besar'), ReportType.pothole);
    expect(hear('lori rosak tepi jalan'), ReportType.brokenLorry);
    expect(hear('jem teruk gila'), ReportType.jam);
    expect(hear('jalan sesak'), ReportType.jam);
    expect(hear('kemalangan'), ReportType.crash);
  });

  test('English', () {
    expect(hear('Police ahead'), ReportType.police);
    expect(hear('speed camera'), ReportType.camera);
    expect(hear('the road is flooded'), ReportType.flood);
    expect(hear('big potholes here'), ReportType.pothole);
    expect(hear('broken down truck'), ReportType.brokenLorry);
    expect(hear('heavy traffic'), ReportType.jam);
    expect(hear('accident'), ReportType.crash);
  });

  test('Chinese', () {
    expect(hear('前面有警察'), ReportType.police);
    expect(hear('有测速相机'), ReportType.camera);
    expect(hear('水灾'), ReportType.flood);
    expect(hear('这里有路洞'), ReportType.pothole);
    expect(hear('罗里抛锚了'), ReportType.brokenLorry);
    expect(hear('塞车很严重'), ReportType.jam);
    expect(hear('前面有车祸'), ReportType.crash);
  });

  test('mixed, the Malaysian way', () {
    expect(hear('前面有polis'), ReportType.police);
    expect(hear('ada accident kat depan'), ReportType.crash);
    expect(hear('jalan jem, 塞车'), ReportType.jam);
  });

  test('the first alert word wins, and longer phrases beat their parts', () {
    expect(hear('polis, lepas tu jem'), ReportType.police);
    expect(hear('jem sebab polis'), ReportType.jam);
    expect(hear('jalan rosak'), ReportType.pothole); // not "rosak" = broken-down vehicle
    expect(hear('police camera'), ReportType.police);
  });

  test('words inside other words do not count, and nothing heard is nothing', () {
    expect(hear('jambatan'), isNull); // has "jam" inside
    expect(hear('selamat pagi'), isNull);
    expect(hear(''), isNull);
    expect(reportFromSpeech(const []), isNull);
  });

  test('the recogniser\'s second guess is used when the first one has no alert', () {
    expect(reportFromSpeech(['a dah polish', 'ada polis']), ReportType.police);
  });

  test('cancel words', () {
    expect(isCancel(['batal']), isTrue);
    expect(isCancel(['cancel cancel']), isTrue);
    expect(isCancel(['算了']), isTrue);
    expect(isCancel(['ada polis']), isFalse);
  });

  test('the recogniser language follows the app, Malaysian first', () {
    expect(pickSpeechLocale(['en_US', 'ms_MY', 'zh_CN'], AppLanguage.ms), 'ms_MY');
    expect(pickSpeechLocale(['en-US', 'en-MY'], AppLanguage.en), 'en-MY');
    expect(pickSpeechLocale(['en_US', 'cmn_Hans_CN'], AppLanguage.zh), 'cmn_Hans_CN');
    expect(pickSpeechLocale(['en_US', 'zh_TW'], AppLanguage.zh), 'zh_TW');
    expect(pickSpeechLocale(['en_US'], AppLanguage.ms), isNull);
  });

  group('the listening sheet', () {
    Future<VoiceReportResult?> run(WidgetTester tester, _FakeSpeech speech, Future<void> Function() act) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      VoiceReportResult? result;
      var closed = false;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          speechInputProvider.overrideWithValue(speech),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showVoiceReport(context);
                    closed = true;
                  },
                  child: const Text('mic'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await act();
      expect(closed, isTrue, reason: 'the sheet should have closed');
      return result;
    }

    testWidgets('saying "ada polis" reports police', (tester) async {
      final speech = _FakeSpeech(says: ['ada', 'ada polis']);
      final r = await run(tester, speech, () async {
        expect(find.text('Abang Polis'), findsOneWidget); // shows what it understood
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 300));
      });
      expect(r?.type, ReportType.police);
      expect(speech.stopped, isTrue);
    });

    testWidgets('not understood: try again, or pick from the grid', (tester) async {
      final speech = _FakeSpeech(says: ['selamat pagi']);
      final r = await run(tester, speech, () async {
        expect(find.textContaining('Tak faham'), findsOneWidget);
        await tester.tap(find.text('Cuba lagi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(speech.starts, 2);
        await tester.tap(find.text('Pilih sendiri'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });
      expect(r?.pick, isTrue);
    });

    testWidgets('no speech recogniser: says so, and offers the grid', (tester) async {
      final r = await run(tester, _FakeSpeech(available: false), () async {
        expect(find.textContaining('Pengecaman suara'), findsOneWidget);
        await tester.tap(find.text('Pilih sendiri'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });
      expect(r?.pick, isTrue);
    });

    testWidgets('"batal" closes without reporting', (tester) async {
      final r = await run(tester, _FakeSpeech(says: ['batal']), () async {
        await tester.pump(const Duration(milliseconds: 300));
      });
      expect(r, isNull);
    });
  });
}
