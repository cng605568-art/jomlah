import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_info.dart';
import '../../../core/l10n/language.dart';
import '../../map/application/map_style_provider.dart';
import '../../update/application/update_providers.dart';
import '../../map/application/traffic_providers.dart';
import '../../routing/application/route_prefs_provider.dart';
import '../../routing/domain/route_prefs.dart';
import '../../voice/application/voice_providers.dart';
import '../../voice/domain/voice_packs.dart';
import '../../../core/app_theme.dart';
import '../../map/presentation/overlays.dart';
import '../application/language_choice.dart';

class SettingsButton extends ConsumerWidget {
  const SettingsButton({super.key, this.glass = false});

  /// true: a floating button over the map (while driving); false: the small round button inside
  /// the search bar.
  final bool glass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(voiceSettingsProvider.select((s) => s.muted));
    final icon = muted ? Icons.volume_off_rounded : Icons.tune_rounded;
    if (glass) {
      return MapButton(icon: icon, onPressed: () => _openSheet(context), tooltip: context.s.settings);
    }
    return Tooltip(
      message: context.s.settings,
      child: Material(
        color: AppColors.raised,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _openSheet(context),
          child: SizedBox(width: 42, height: 42, child: Icon(icon, color: Colors.white, size: 22)),
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final voice = ref.watch(voiceSettingsProvider);
          final voiceCtl = ref.read(voiceSettingsProvider.notifier);
          final prefs = ref.watch(routePrefsProvider);
          final prefsCtl = ref.read(routePrefsProvider.notifier);
          final night = ref.watch(nightModeProvider);
          final orientation = ref.watch(mapOrientationProvider);
          final language = ref.watch(languageProvider);
          final s = context.s;
          // Voices in the app's language first, then the others.
          final packs = [
            ...kVoicePacks.where((p) => voiceLanguage(p) == language),
            ...kVoicePacks.where((p) => voiceLanguage(p) != language),
          ];

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Heading(s.languageTitle),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final l in AppLanguage.values)
                            ChoiceChip(
                              label: Text(l.nativeName),
                              selected: l == language,
                              onSelected: (_) => chooseLanguage(ref, l),
                            ),
                        ],
                      ),
                    ),
                    _Heading(s.route),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<Vehicle>(
                        segments: [
                          for (final v in Vehicle.values)
                            ButtonSegment(value: v, label: Text(v == Vehicle.car ? s.car : s.motorcycle)),
                        ],
                        selected: {prefs.vehicle},
                        onSelectionChanged: (s) => prefsCtl.setVehicle(s.first),
                      ),
                    ),
                    SwitchListTile(
                      title: Text(s.avoidTolls),
                      subtitle: Text(s.avoidTollsHint),
                      value: prefs.avoidTolls,
                      onChanged: prefsCtl.setAvoidTolls,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(s.fromNextRoute, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ),
                    _Heading(s.mapDirection),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<MapOrientation>(
                        segments: [
                          for (final m in MapOrientation.values)
                            ButtonSegment(
                              value: m,
                              label: Text(m == MapOrientation.headingUp ? s.headingUp : s.northUp),
                            ),
                        ],
                        selected: {orientation},
                        onSelectionChanged: (s) =>
                            ref.read(mapOrientationProvider.notifier).set(s.first),
                      ),
                    ),
                    _Heading(s.nightMap),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<NightMode>(
                        segments: [
                          for (final m in NightMode.values)
                            ButtonSegment(
                              value: m,
                              label: Text(switch (m) {
                                NightMode.auto => s.auto,
                                NightMode.always => s.on,
                                NightMode.never => s.off,
                              }),
                            ),
                        ],
                        selected: {night},
                        onSelectionChanged: (s) =>
                            ref.read(nightModeProvider.notifier).set(s.first),
                      ),
                    ),
                    _Heading(s.mapStyle),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<MapLook>(
                        segments: [
                          ButtonSegment(value: MapLook.vector, label: Text(s.mapNew)),
                          ButtonSegment(value: MapLook.classic, label: Text(s.mapClassic)),
                        ],
                        selected: {ref.watch(mapLookProvider)},
                        onSelectionChanged: (s) => ref.read(mapLookProvider.notifier).set(s.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Text(s.mapStyleHint, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ),
                    if (!kDemoMode) ...[
                      _Heading(s.liveTraffic),
                      SwitchListTile(
                        title: Text(s.shareTraffic),
                        subtitle: Text(s.shareTrafficHint),
                        value: ref.watch(trafficSharingProvider),
                        onChanged: ref.read(trafficSharingProvider.notifier).set,
                      ),
                    ],
                    _Heading(s.voice),
                    SwitchListTile(
                      title: Text(s.muteVoice),
                      value: voice.muted,
                      onChanged: (_) => voiceCtl.toggleMute(),
                    ),
                    for (final p in packs)
                      ListTile(
                        leading: Icon(
                          p.id == voice.pack.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(p.name),
                        subtitle: Text('${p.tagline} · ${voiceLanguage(p).nativeName}'),
                        onTap: () {
                          voiceCtl.setPack(p);
                          ref.read(voiceEngineProvider).preview(); // plays a sample
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(s.voiceNeedsTts, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ),
                    const Divider(),
                    if (kPrivacyUrl.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: Text(s.privacy),
                        subtitle: Text(s.privacyHint),
                        onTap: () => _open(kPrivacyUrl),
                      ),
                    if (kFeedbackUrl.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.bug_report_outlined),
                        title: Text(s.feedback),
                        subtitle: Text(s.opensOnGithub),
                        onTap: () => _open(kFeedbackUrl),
                      ),
                    if (ref.watch(updateProvider).valueOrNull case final update?)
                      ListTile(
                        leading: const Icon(Icons.system_update_rounded, color: AppColors.go),
                        title: Text(s.updateAvailable(update.tag)),
                        subtitle: Text(s.updateHint),
                        onTap: openDownloadPage,
                      ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text('Jomlah $kAppVersion'),
                      subtitle: Text(
                        kDemoMode ? s.demoMode : s.connectedToAlerts,
                      ),
                    ),
                    if (kRepo.isNotEmpty)
                      SwitchListTile(
                        title: Text(s.checkUpdates),
                        subtitle: Text(s.checkUpdatesHint),
                        value: ref.watch(updateCheckProvider),
                        onChanged: ref.read(updateCheckProvider.notifier).set,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}
