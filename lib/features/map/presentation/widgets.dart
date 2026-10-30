import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../application/providers.dart';
import '../domain/report.dart';
import '../../../core/app_theme.dart';

// The driver's car is drawn by CarMarker (car_marker.dart).

class ReportPin extends StatelessWidget {
  const ReportPin({super.key, required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: report.type.label,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.warning, width: 3),
          ),
          child: Text(report.type.emoji, style: const TextStyle(fontSize: 24)),
        ),
      );
}

class ReportBar extends ConsumerWidget {
  const ReportBar({super.key, required this.at});
  final LatLng? at; // null until we have a GPS fix

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitting = ref.watch(reportsProvider.select((s) => s.submitting));
    final enabled = at != null && !submitting;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      decoration: const BoxDecoration(
        color: AppColors.overlay,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in ReportType.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 64),
                    backgroundColor: AppColors.raised,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: enabled
                      ? () {
                          HapticFeedback.mediumImpact();
                          ref.read(reportsProvider.notifier).report(t, at!);
                        }
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 22)),
                      Text(t.label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
