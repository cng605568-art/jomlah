import 'package:flutter_tts/flutter_tts.dart';

/// The one place that makes sound. Swap TtsSpeaker for a ClipSpeaker (recorded audio)
/// later without touching the engine.
abstract class Speaker {
  Future<void> init();
  Future<void> setLocale(String locale);
  Future<void> speak(String text); // interrupts whatever is playing
  Future<void> stop();
  bool get isSpeaking;
}

class TtsSpeaker implements Speaker {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<void> init() async {
    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((_) => _speaking = false);
    try {
      // Android: ducks music and routes through the navigation audio channel.
      await _tts.setAudioAttributesForNavigation();
    } catch (_) {}
  }

  @override
  Future<void> setLocale(String locale) async {
    try {
      final ok = await _tts.isLanguageAvailable(locale);
      if (ok == true || ok == 1) await _tts.setLanguage(locale);
    } catch (_) {}
  }

  @override
  Future<void> speak(String text) async {
    _speaking = true; // set now so priority checks see it immediately
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      _speaking = false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
  }
}
