import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/voice_providers.dart';
import '../domain/voice_packs.dart';

class VoiceButton extends ConsumerWidget {
  const VoiceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(voiceSettingsProvider.select((s) => s.muted));
    return IconButton.filled(
      tooltip: 'Suara',
      onPressed: () => _openPicker(context),
      icon: Icon(muted ? Icons.volume_off : Icons.record_voice_over),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(voiceSettingsProvider);
          final settings = ref.read(voiceSettingsProvider.notifier);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Senyapkan suara'),
                  value: s.muted,
                  onChanged: (_) => settings.toggleMute(),
                ),
                for (final p in kVoicePacks)
                  ListTile(
                    leading: Icon(
                      p.id == s.pack.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(p.name),
                    subtitle: Text(p.tagline),
                    onTap: () {
                      settings.setPack(p);
                      ref.read(voiceEngineProvider).preview(); // plays a sample
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
