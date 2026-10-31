import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_info.dart';
import '../../../core/app_theme.dart';
import '../../../core/l10n/language.dart';
import '../../settings/application/language_choice.dart';

/// Shown once, before the first location permission prompt. The language comes first, so
/// everyone can read the rest.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final language = ref.watch(languageProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
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
              const SizedBox(height: 20),
              Text(s.onboardingTitle, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(s.onboardingSubtitle, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _Point(icon: Icons.phone_android, title: s.safetyTitle, body: s.safetyBody),
                    _Point(icon: Icons.gavel, title: s.guidanceTitle, body: s.guidanceBody),
                    _Point(icon: Icons.lock_outline, title: s.privacy, body: s.privacyBody),
                    if (kDemoMode)
                      _Point(icon: Icons.science_outlined, title: s.demoTitle, body: s.demoBody)
                    else
                      _Point(icon: Icons.campaign_outlined, title: s.sharedAlertsTitle, body: s.sharedAlertsBody),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton(
                  onPressed: onDone,
                  child: Text(s.gotIt, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: AppColors.sky),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}
