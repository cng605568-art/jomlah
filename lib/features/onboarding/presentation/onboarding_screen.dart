import 'package:flutter/material.dart';
import '../../../core/app_info.dart';
import '../../../core/app_theme.dart';

/// Shown once, before the first location permission prompt.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Jom! 🚗', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Sebelum gerak, 3 perkara penting.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    const _Point(
                      icon: Icons.phone_android,
                      title: 'Selamat dulu',
                      body: 'Letak telefon di pemegang. Jangan menaip semasa memandu. '
                          'Kalau tak selamat, berhenti dulu.\n'
                          'Mount your phone, never type while driving, and pull over if '
                          'it is not safe.',
                    ),
                    const _Point(
                      icon: Icons.gavel,
                      title: 'Panduan sahaja',
                      body: 'Ikut papan tanda dan undang-undang jalan raya. Aplikasi ini '
                          'boleh tersilap, terutama di persimpangan rumit.\n'
                          'Guidance only. Road signs and the law come first. This beta can '
                          'be wrong, especially at complex junctions.',
                    ),
                    const _Point(
                      icon: Icons.lock_outline,
                      title: 'Privasi',
                      body: 'Tiada akaun. Lokasi digunakan untuk laluan dan amaran sahaja. '
                          'Semasa navigasi, lokasi dijejak di latar dengan notifikasi. Pelayan peta, '
                          'carian dan laluan percuma boleh nampak alamat IP dan koordinat yang '
                          'anda minta. Butiran penuh ada di Tetapan.\n'
                          'No account. During a trip, location is tracked in the background '
                          '(with a notification). Free map, search and routing servers can see '
                          'your IP address and the coordinates you ask for. Details are in Settings.',
                    ),
                    if (kDemoMode)
                      const _Point(
                        icon: Icons.science_outlined,
                        title: 'Versi demo',
                        body: 'Amaran (polis, banjir dll.) dalam versi ini hanyalah contoh dan '
                            'belum dikongsi antara pengguna.\n'
                            'Alerts in this build are samples and are not shared between users yet.',
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton(
                  onPressed: onDone,
                  child: const Text('Faham. Jom!', style: TextStyle(fontSize: 18)),
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
