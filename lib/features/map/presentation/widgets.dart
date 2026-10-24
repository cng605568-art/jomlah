import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../application/providers.dart';
import '../domain/report.dart';

/// The user's car. North-up map for the MVP, so we rotate by GPS heading.
class HatchAvatar extends StatelessWidget {
  const HatchAvatar({super.key, required this.headingDeg});
  final double headingDeg; // degrees clockwise from north, -1 if unknown

  @override
  Widget build(BuildContext context) {
    final angle = (headingDeg < 0 ? 0.0 : headingDeg) * math.pi / 180;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x40C8FF3D), // soft neon halo
          ),
        ),
        Transform.rotate(
          angle: angle,
          child: Image.asset(
            'assets/avatar/hatch_top.png',
            width: 40,
            errorBuilder: (context, error, stack) =>
                const Icon(Icons.directions_car_filled, size: 40),
          ),
        ),
      ],
    );
  }
}

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
            border: Border.all(color: const Color(0xFFFF4F8B), width: 3),
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
        color: Color(0xF2171C36),
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
                  style: FilledButton.styleFrom(minimumSize: const Size(88, 64)),
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
