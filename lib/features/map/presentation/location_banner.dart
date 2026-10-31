import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../application/providers.dart';
import '../../../core/app_theme.dart';
import '../../../core/l10n/language.dart';

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
        color: AppColors.overlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_off, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(serviceOff ? context.s.gpsOff : context.s.needLocationPermission),
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
                    child: Text(context.s.openSettings),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(locationProvider),
                    child: Text(context.s.tryAgain),
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
          color: AppColors.overlay,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gps_not_fixed, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(child: Text(context.s.gpsStale)),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: Geolocator.openAppSettings,
                  child: Text(context.s.openAppSettings),
                ),
              ],
            ),
          ),
        ),
      );
}
