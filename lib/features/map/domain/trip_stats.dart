import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';
import '../../../core/l10n/language.dart';
import '../../../core/l10n/strings.dart';

class TripSummary {
  const TripSummary({
    required this.distanceKm,
    required this.duration,
    required this.avgKmh,
    required this.maxKmh,
  });

  final double distanceKm;
  final Duration duration;
  final double avgKmh;
  final double maxKmh;
}

/// Adds up what happened on a trip, on the phone only. Nothing here is stored or sent.
class TripStats {
  DateTime? _start;
  LatLng? _last;
  double _distanceM = 0;
  double _maxSpeedMps = 0;

  bool get running => _start != null;

  void begin(DateTime now) {
    _start = now;
    _last = null;
    _distanceM = 0;
    _maxSpeedMps = 0;
  }

  /// Call with each cleaned-up position while driving.
  void add(LatLng position, double speedMps) {
    if (_start == null) return;
    final last = _last;
    if (last != null) {
      final d = haversineM(last, position);
      if (d < 200) _distanceM += d; // a bigger gap is a GPS jump, not driving
    }
    _last = position;
    _maxSpeedMps = math.max(_maxSpeedMps, speedMps);
  }

  TripSummary summary(DateTime now) {
    final start = _start ?? now;
    final elapsed = now.difference(start);
    final seconds = elapsed.inMilliseconds / 1000.0;
    return TripSummary(
      distanceKm: _distanceM / 1000,
      duration: elapsed,
      avgKmh: seconds > 0 ? _distanceM / seconds * 3.6 : 0,
      maxKmh: _maxSpeedMps * 3.6,
    );
  }
}

/// "45 s", "23 min", "1 j 05 min" (j = jam, hour in Malay); other languages via [s].
String formatDuration(Duration d, [AppStrings s = const AppStrings(AppLanguage.ms)]) => s.duration(d);
