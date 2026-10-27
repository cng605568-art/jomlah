import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jomlah/core/geo.dart';
import 'package:jomlah/features/map/domain/jam_detector.dart';
import 'package:jomlah/features/map/domain/trip_stats.dart';

final origin = LatLng(3.1390, 101.6869);
final t0 = DateTime.utc(2026, 10, 24, 8);
DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

void main() {
  test('TripStats adds up distance, average and top speed', () {
    final stats = TripStats();
    stats.begin(t0);
    var p = origin;
    for (var i = 0; i <= 10; i++) {
      stats.add(p, 15); // 15 m/s = 54 km/h
      p = offsetM(p, 0, 15);
    }
    final s = stats.summary(at(10));
    expect(s.distanceKm, closeTo(0.150, 0.002));
    expect(s.duration.inSeconds, 10);
    expect(s.avgKmh, closeTo(54, 1.0));
    expect(s.maxKmh, closeTo(54, 0.1));
  });

  test('TripStats ignores GPS jumps and anything before the trip starts', () {
    final stats = TripStats();
    stats.add(origin, 10); // before begin(): ignored
    stats.begin(t0);
    stats.add(origin, 10);
    stats.add(offsetM(origin, 0, 100), 10);
    stats.add(offsetM(origin, 5000, 0), 10); // teleport: not driving
    final s = stats.summary(at(10));
    expect(s.distanceKm, closeTo(0.100, 0.002));
  });

  test('formatDuration reads naturally', () {
    expect(formatDuration(const Duration(seconds: 45)), '45 s');
    expect(formatDuration(const Duration(seconds: 125)), '2 min');
    expect(formatDuration(const Duration(seconds: 3900)), '1 j 05 min');
  });

  test('JamDetector asks only after two minutes of crawling, then rests', () {
    final j = JamDetector();
    expect(j.update(now: at(0), speedMps: 15, navigating: true, remainingM: 5000), isFalse);

    for (var s = 0; s < 120; s += 10) {
      expect(j.update(now: at(s), speedMps: 1, navigating: true, remainingM: 5000), isFalse);
    }
    expect(j.update(now: at(120), speedMps: 1, navigating: true, remainingM: 5000), isTrue);

    // Still crawling, but it just asked: stay quiet through the cooldown.
    for (var s = 130; s < 300; s += 10) {
      expect(j.update(now: at(s), speedMps: 1, navigating: true, remainingM: 5000), isFalse);
    }

    // Traffic clears, then later another two minutes of crawling after the cooldown.
    expect(j.update(now: at(300), speedMps: 15, navigating: true, remainingM: 5000), isFalse);
    for (var s = 1000; s < 1120; s += 10) {
      expect(j.update(now: at(s), speedMps: 1, navigating: true, remainingM: 5000), isFalse);
    }
    expect(j.update(now: at(1120), speedMps: 1, navigating: true, remainingM: 5000), isTrue);
  });

  test('JamDetector stays quiet near the destination or when not on a trip', () {
    final j = JamDetector();
    for (var s = 0; s < 600; s += 10) {
      expect(j.update(now: at(s), speedMps: 1, navigating: true, remainingM: 100), isFalse);
      expect(j.update(now: at(s), speedMps: 1, navigating: false, remainingM: 5000), isFalse);
    }
  });
}
