import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_info.dart';
import '../../map/application/map_style_provider.dart';
import '../../routing/application/route_prefs_provider.dart';
import '../../routing/domain/route_prefs.dart';
import '../../voice/application/voice_providers.dart';
import '../../voice/domain/voice_packs.dart';

class SettingsButton extends ConsumerWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(voiceSettingsProvider.select((s) => s.muted));
    return IconButton.filled(
      tooltip: 'Tetapan',
      onPressed: () => _openSheet(context),
      icon: Icon(muted ? Icons.volume_off : Icons.tune),
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

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Heading('Laluan'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<Vehicle>(
                        segments: [
                          for (final v in Vehicle.values)
                            ButtonSegment(value: v, label: Text(v.label)),
                        ],
                        selected: {prefs.vehicle},
                        onSelectionChanged: (s) => prefsCtl.setVehicle(s.first),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Kurangkan tol'),
                      subtitle: const Text('Cuba elak jalan bertol. Tak dijamin kalau tiada pilihan lain.'),
                      value: prefs.avoidTolls,
                      onChanged: prefsCtl.setAvoidTolls,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Berkuat kuasa pada laluan seterusnya.',
                          style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ),
                    const _Heading('Arah peta semasa memandu'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<MapOrientation>(
                        segments: [
                          for (final m in MapOrientation.values)
                            ButtonSegment(value: m, label: Text(m.label)),
                        ],
                        selected: {orientation},
                        onSelectionChanged: (s) =>
                            ref.read(mapOrientationProvider.notifier).set(s.first),
                      ),
                    ),
                    const _Heading('Peta malam'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<NightMode>(
                        segments: [
                          for (final m in NightMode.values)
                            ButtonSegment(value: m, label: Text(m.label)),
                        ],
                        selected: {night},
                        onSelectionChanged: (s) =>
                            ref.read(nightModeProvider.notifier).set(s.first),
                      ),
                    ),
                    const _Heading('Suara'),
                    SwitchListTile(
                      title: const Text('Senyapkan suara'),
                      value: voice.muted,
                      onChanged: (_) => voiceCtl.toggleMute(),
                    ),
                    for (final p in kVoicePacks)
                      ListTile(
                        leading: Icon(
                          p.id == voice.pack.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(p.name),
                        subtitle: Text(p.tagline),
                        onTap: () {
                          voiceCtl.setPack(p);
                          ref.read(voiceEngineProvider).preview(); // plays a sample
                        },
                      ),
                    const Divider(),
                    if (kPrivacyUrl.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Privasi'),
                        subtitle: const Text('Apa yang kami simpan dan tidak simpan'),
                        onTap: () => _open(kPrivacyUrl),
                      ),
                    if (kFeedbackUrl.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.bug_report_outlined),
                        title: const Text('Lapor masalah / cadangan'),
                        subtitle: const Text('Dibuka di GitHub'),
                        onTap: () => _open(kFeedbackUrl),
                      ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text('Jomlah $kAppVersion'),
                      subtitle: Text(
                        kDemoMode ? 'Mod demo: amaran contoh sahaja' : 'Disambung ke pelayan amaran',
                      ),
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
