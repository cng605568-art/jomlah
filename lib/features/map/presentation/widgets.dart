import 'package:flutter/material.dart';
import '../domain/report.dart';
import 'overlays.dart';

// The driver's car is drawn by CarMarker (car_marker.dart). Reporting is the orange button and its
// grid (overlays.dart).

/// A road alert on the map: the report's icon badge with a white ring, so it stands out on any map.
class ReportPin extends StatelessWidget {
  const ReportPin({super.key, required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: report.type.label,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: ReportBadge(type: report.type, size: 40),
        ),
      );
}
