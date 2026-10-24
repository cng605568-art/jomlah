import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../application/providers.dart';

/// Appears only when GPS is off or permission was refused, with a way to fix it.
class LocationBanner extends ConsumerWidget {
  const LocationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(locationProvider);
    if (!loc.hasError) return const SizedBox.shrink();
    final serviceOff = loc.error is LocationServiceDisabledException;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: const Color(0xF2171C36),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_off, color: Color(0xFFFF4F8B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      serviceOff
                          ? 'GPS dimatikan. Hidupkan lokasi supaya Jomlah boleh tunjuk jalan.'
                          : 'Jomlah perlukan kebenaran lokasi untuk tunjuk jalan.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: () => serviceOff
                        ? Geolocator.openLocationSettings()
                        : Geolocator.openAppSettings(),
                    child: const Text('Buka tetapan'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(locationProvider),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown during a trip when GPS fixes have stopped arriving, which is what "not tracking
/// in real time" looks like. Most often the phone's battery saver is stopping the app.
class StaleGpsBanner extends StatelessWidget {
  const StaleGpsBanner({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: const Color(0xF2171C36),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gps_not_fixed, color: Color(0xFFFF4F8B)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lokasi tak dikemas kini. Cari tempat terbuka. Kalau berterusan: '
                        'Tetapan > Bateri > Jomlah > Tiada had, dan benarkan notifikasi.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: Geolocator.openAppSettings,
                  child: const Text('Buka tetapan app'),
                ),
              ],
            ),
          ),
        ),
      );
}
