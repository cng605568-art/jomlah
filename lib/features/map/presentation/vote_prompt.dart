import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/providers.dart';
import '../../../core/app_theme.dart';

/// "Masih ada Abang Polis?" Two big buttons, gone after 10 seconds.
class VotePrompt extends ConsumerWidget {
  const VotePrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(votePromptProvider);
    if (report == null) return const SizedBox.shrink();

    void answer(bool stillThere) {
      HapticFeedback.selectionClick();
      ref.read(votePromptProvider.notifier).dismiss();
      ref.read(reportsProvider.notifier).vote(report.id, stillThere: stillThere);
    }

    return Material(
      color: AppColors.overlay,
      elevation: 6,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${report.type.emoji} Masih ada ${report.type.label}?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(72, 56)),
              onPressed: () => answer(true),
              child: const Text('Ada'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(72, 56)),
              onPressed: () => answer(false),
              child: const Text('Tak ada'),
            ),
          ],
        ),
      ),
    );
  }
}
