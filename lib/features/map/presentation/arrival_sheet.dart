import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../search/application/places_provider.dart';
import '../../search/domain/place.dart';
import '../domain/trip_stats.dart';
import '../../../core/app_theme.dart';
import '../../../core/l10n/language.dart';

/// Shown when you arrive: how the trip went, and a shortcut to save the place.
Future<void> showArrivalSheet(
  BuildContext context, {
  required WidgetRef ref,
  required TripSummary summary,
  Place? place,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final s = sheetContext.s;
      return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.arrived, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            if (place != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(place.name, style: const TextStyle(fontSize: 16, color: AppColors.textMuted)),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Stat(s.distance, '${summary.distanceKm.toStringAsFixed(1)} km')),
                Expanded(child: _Stat(s.time, s.duration(summary.duration))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Stat(s.average, '${summary.avgKmh.round()} ${s.kmh}')),
                Expanded(child: _Stat(s.topSpeed, '${summary.maxKmh.round()} ${s.kmh}')),
              ],
            ),
            if (place != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.home_outlined, size: 18),
                    label: Text(s.saveAsHome),
                    onPressed: () {
                      ref.read(placesProvider.notifier).setHome(place);
                      Navigator.pop(sheetContext);
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.work_outline, size: 18),
                    label: Text(s.saveAsWork),
                    onPressed: () {
                      ref.read(placesProvider.notifier).setWork(place);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(s.done, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
    },
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      );
}
