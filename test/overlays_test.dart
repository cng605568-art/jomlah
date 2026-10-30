import 'package:flutter_test/flutter_test.dart';
import 'package:jomlah/features/map/domain/report.dart';
import 'package:jomlah/features/map/presentation/overlays.dart';
import 'package:jomlah/features/routing/domain/route_plan.dart';
import 'package:jomlah/features/routing/presentation/nav_banner.dart';

void main() {
  test('arrival time is shown as a 24-hour clock', () {
    expect(formatClock(DateTime(2026, 10, 30, 21, 52)), '21:52');
    expect(formatClock(DateTime(2026, 10, 30, 7, 5)), '07:05');
  });

  test('exit sign text joins number, road and destinations', () {
    expect(
      signText(const ExitSign(number: ['205'], branch: ['SUKE'], toward: ['Putrajaya', 'Cyberjaya'])),
      'Keluar 205 · SUKE · ke Putrajaya / Cyberjaya',
    );
    expect(signText(null), isNull);
    expect(signText(const ExitSign()), isNull);
  });

  test('every report type has its own icon and colour', () {
    final icons = {for (final t in ReportType.values) t.icon};
    final colours = {for (final t in ReportType.values) t.color};
    expect(icons.length, ReportType.values.length);
    expect(colours.length, ReportType.values.length);
  });
}
