import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';
import '../../../core/prefs.dart';
import '../../map/application/providers.dart';
import '../../map/domain/report.dart';
import '../../routing/application/routing_providers.dart';
import '../data/speaker.dart';
import '../domain/voice_pack.dart';
import '../domain/voice_packs.dart';
import '../domain/voice_settings.dart';
import 'voice_engine.dart';

class VoiceSettingsNotifier extends Notifier<VoiceSettings> {
  @override
  VoiceSettings build() {
    final prefs = ref.read(sharedPrefsProvider);
    final id = prefs.getString('voice.pack');
    return VoiceSettings(
      pack: kVoicePacks.firstWhere((p) => p.id == id, orElse: () => kMamakBoss),
      muted: prefs.getBool('voice.muted') ?? false,
    );
  }

  void setPack(VoicePack p) {
    state = state.copyWith(pack: p);
    ref.read(sharedPrefsProvider).setString('voice.pack', p.id);
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

/// Wires the engine to navigation + GPS. Watch this provider once (MapScreen does)
/// and it keeps listening for as long as the app is open.
final voiceEngineProvider = Provider<VoiceEngine>((ref) {
  final engine = VoiceEngine(
    speaker: ref.watch(speakerProvider),
    settings: () => ref.read(voiceSettingsProvider),
  );

  ref.listen<NavState>(routingProvider, (prev, next) => engine.onNav(prev, next));

  ref.listen(locationProvider, (_, next) {
    next.whenData((pos) {
      engine.onSpeed(pos.speed < 0 ? 0 : pos.speed);

      // Road alerts: only while navigating and moving (>7 km/h), within 500 m,
      // roughly in front of us, and near our route (not on a parallel road).
      final nav = ref.read(routingProvider);
      if (!nav.navigating || pos.speed < 2) return;
      final here = LatLng(pos.latitude, pos.longitude);
      for (final r in ref.read(reportsProvider).reports) {
        final cue = _alertCues[r.type];
        if (cue == null || r.isExpired) continue;
        final d = haversineM(here, r.position);
        if (d > 500 || d < 20) continue;
        if (pos.heading >= 0) {
          var diff = (bearingDeg(here, r.position) - pos.heading) % 360;
          if (diff > 180) diff -= 360;
          if (diff.abs() > 60) continue;
        }
        final off = ref.read(routingProvider.notifier).distanceFromRoute(r.position);
        if (off == null || off > 60) continue;
        engine.alert(r.id, cue, math.max(d, 50));
      }
    });
  });

  return engine;
});
