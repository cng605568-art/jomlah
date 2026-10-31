import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';
import '../../../core/l10n/language.dart';
import '../../../core/prefs.dart';
import '../../map/application/providers.dart';
import '../../map/domain/report.dart';
import '../../routing/application/routing_providers.dart';
import '../data/speaker.dart';
import '../domain/voice_pack.dart';
import '../domain/voice_packs.dart';
import '../domain/voice_settings.dart';
import 'voice_engine.dart';

/// The language a voice speaks, from its text-to-speech locale ("zh-CN" -> 中文).
AppLanguage voiceLanguage(VoicePack pack) => AppLanguage.fromCode(pack.locale.split('-').first) ?? AppLanguage.ms;

/// The voice a language starts with.
VoicePack defaultVoiceFor(AppLanguage language) => switch (language) {
      AppLanguage.ms => kMamakBoss,
      AppLanguage.en => kSerious,
      AppLanguage.zh => kZhFriend,
    };

class VoiceSettingsNotifier extends Notifier<VoiceSettings> {
  @override
  VoiceSettings build() {
    final prefs = ref.read(sharedPrefsProvider);
    final id = prefs.getString('voice.pack');
    final fallback = defaultVoiceFor(ref.read(languageProvider)); // first run: the app's language
    return VoiceSettings(
      pack: kVoicePacks.firstWhere((p) => p.id == id, orElse: () => fallback),
      muted: prefs.getBool('voice.muted') ?? false,
    );
  }

  void setPack(VoicePack p) {
    state = state.copyWith(pack: p);
    ref.read(sharedPrefsProvider).setString('voice.pack', p.id);
  }

  /// After the app's language changes: switch to that language's voice, unless the current voice
  /// already speaks it.
  void matchLanguage(AppLanguage language) {
    if (voiceLanguage(state.pack) != language) setPack(defaultVoiceFor(language));
  }

  void toggleMute() {
    state = state.copyWith(muted: !state.muted);
    ref.read(sharedPrefsProvider).setBool('voice.muted', state.muted);
  }
}

final voiceSettingsProvider =
    NotifierProvider<VoiceSettingsNotifier, VoiceSettings>(VoiceSettingsNotifier.new);

final speakerProvider = Provider<Speaker>((ref) {
  final speaker = TtsSpeaker();
  speaker.init();
  ref.onDispose(speaker.stop);
  return speaker;
});

const _alertCues = <ReportType, Cue>{
  ReportType.police: Cue.police,
  ReportType.camera: Cue.camera,
  ReportType.flood: Cue.flood,
  ReportType.pothole: Cue.pothole,
  ReportType.brokenLorry: Cue.lorry,
  ReportType.jam: Cue.jam,
  ReportType.crash: Cue.crash,
};

/// Wires the engine to navigation. Watch this provider once (MapScreen does) and it keeps
/// listening for as long as the app is open. Positions come in through [voiceFeedProvider].
final voiceEngineProvider = Provider<VoiceEngine>((ref) {
  final engine = VoiceEngine(
    speaker: ref.watch(speakerProvider),
    settings: () => ref.read(voiceSettingsProvider),
  );
  ref.listen<NavState>(routingProvider, (prev, next) => engine.onNav(prev, next));
  return engine;
});

/// Hands each cleaned-up position to the voice: the speed (faster means earlier turn warnings)
/// and road alerts ahead. MapScreen calls it for real GPS and Simulasi alike, so alerts are
/// spoken during a pretend drive too.
final voiceFeedProvider = Provider<VoiceFeed>((ref) => VoiceFeed(ref, ref.watch(voiceEngineProvider)));

class VoiceFeed {
  VoiceFeed(this._ref, this._engine);
  final Ref _ref;
  final VoiceEngine _engine;

  void onFix(LatLng here, {required double speedMps, double? headingDeg}) {
    _engine.onSpeed(speedMps < 0 ? 0 : speedMps);

    // Road alerts: only while navigating and moving (>7 km/h), within 500 m,
    // roughly in front of us, and near our route (not on a parallel road).
    final nav = _ref.read(routingProvider);
    if (!nav.navigating || speedMps < 2) return;
    final routing = _ref.read(routingProvider.notifier);
    for (final r in _ref.read(reportsProvider).reports) {
      final cue = _alertCues[r.type];
      if (cue == null || r.isExpired) continue;
      final d = alertAheadM(here, headingDeg, r.position);
      if (d == null) continue;
      final off = routing.distanceFromRoute(r.position);
      if (off == null || off > 60) continue;
      _engine.alert(r.id, cue, math.max(d, 50));
    }
  }
}

/// Metres to an alert at [at] when it is worth announcing from [here]: 20 to 500 m away and,
/// when the heading is known, within 60 degrees of straight ahead. Null otherwise.
double? alertAheadM(LatLng here, double? headingDeg, LatLng at) {
  final d = haversineM(here, at);
  if (d > 500 || d < 20) return null;
  if (headingDeg != null && headingDeg >= 0) {
    var diff = (bearingDeg(here, at) - headingDeg) % 360;
    if (diff > 180) diff -= 360;
    if (diff.abs() > 60) return null;
  }
  return d;
}
