import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/l10n/language.dart';

/// Listening for a voice report. A seam so tests can pretend to speak.
abstract class SpeechInput {
  /// False when the phone has no speech recogniser or the microphone was refused.
  Future<bool> init();

  /// Listens once (about 8 seconds at most). [onWords] gets the best guess first, then
  /// alternatives, as the words come in; [onDone] when listening stops.
  Future<void> start({
    required AppLanguage language,
    required void Function(List<String> heard, bool isFinal) onWords,
    required void Function() onDone,
  });

  Future<void> stop();
}

/// The phone's own speech recogniser (on most phones Google's), through speech_to_text.
class SttSpeechInput implements SpeechInput {
  final _stt = SpeechToText();
  bool _ready = false;
  void Function()? _onDone;

  @override
  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) _finish();
        },
        onError: (_) => _finish(),
        options: [SpeechToText.androidNoBluetooth], // no Bluetooth permission needed
      );
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  void _finish() {
    final done = _onDone;
    _onDone = null;
    done?.call();
  }

  @override
  Future<void> start({
    required AppLanguage language,
    required void Function(List<String> heard, bool isFinal) onWords,
    required void Function() onDone,
  }) async {
    _onDone = onDone;
    String? localeId;
    try {
      localeId = pickSpeechLocale([for (final l in await _stt.locales()) l.localeId], language);
    } catch (_) {}
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) => onWords(
        [r.recognizedWords, for (final a in r.alternates) a.recognizedWords],
        r.finalResult,
      ),
      localeId: localeId,
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _onDone = null;
    try {
      await _stt.stop();
    } catch (_) {}
  }
}

/// The recogniser language closest to the app's: Malaysian first, then any of that language, else
/// null (the phone's default).
String? pickSpeechLocale(List<String> available, AppLanguage language) {
  final ids = available.map((id) => id.replaceAll('-', '_')).toList();
  final preferred = switch (language) {
    AppLanguage.ms => ['ms_MY', 'ms'],
    AppLanguage.en => ['en_MY', 'en_SG', 'en_GB', 'en_US', 'en'],
    AppLanguage.zh => ['zh_CN', 'cmn_Hans_CN', 'zh_MY', 'zh_SG', 'zh', 'cmn'],
  };
  for (final p in preferred) {
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] == p) return available[i];
    }
  }
  for (final p in preferred) {
    for (var i = 0; i < ids.length; i++) {
      if (ids[i].startsWith('${p.split('_').first}_')) return available[i];
    }
  }
  return null;
}
