import 'dart:convert';

/// A stretch of the route with one known legal speed limit.
/// Positions are metres from the start of the route, like [RoutePlan.cumulativeM].
class SpeedZone {
  const SpeedZone({required this.startM, required this.endM, required this.kph});
  final double startM;
  final double endM;
  final int kph;
}

/// Legal speed limits along one route. Gaps between zones are roads where OpenStreetMap has no
/// limit; there we show nothing rather than guess.
class SpeedLimits {
  const SpeedLimits(this.zones);

  static const empty = SpeedLimits([]);

  /// Sorted by [SpeedZone.startM], never overlapping.
  final List<SpeedZone> zones;

  bool get isEmpty => zones.isEmpty;

  /// Builds zones from Valhalla `trace_attributes` edges, in route order. Each edge has a
  /// `length` (kilometres) and, only when the map knows it, a `speed_limit` (km/h).
  /// [routeLengthM] is the app's own length of the same route; zone positions are scaled to it so
  /// they line up with the distance driven, which the app measures on the decoded shape.
  factory SpeedLimits.fromEdges(
    List<dynamic> edges, {
    double? routeLengthM,
    double metresPerUnit = 1000,
  }) {
    final raw = <SpeedZone>[];
    var at = 0.0;
    for (final e in edges) {
      if (e is! Map) continue;
      final len = e['length'];
      if (len is! num || len <= 0) continue;
      final lengthM = len.toDouble() * metresPerUnit;
      final v = e['speed_limit'];
      // 0 and 255 are Valhalla's "unknown" and "no limit"; neither is a number to show.
      final kph = (v is int && v > 0 && v < 255) ? v : null;
      if (kph != null) {
        if (raw.isNotEmpty && raw.last.kph == kph && (raw.last.endM - at).abs() < 0.5) {
          raw[raw.length - 1] = SpeedZone(startM: raw.last.startM, endM: at + lengthM, kph: kph);
        } else {
          raw.add(SpeedZone(startM: at, endM: at + lengthM, kph: kph));
        }
      }
      at += lengthM;
    }
    if (raw.isEmpty) return empty;

    // Both lengths describe the same road, so they normally agree within a fraction of a percent.
    // A big disagreement means something is off; then use the edge lengths as they are.
    var scale = 1.0;
    if (routeLengthM != null && routeLengthM > 0 && at > 0) {
      final r = routeLengthM / at;
      if (r > 0.8 && r < 1.25) scale = r;
    }
    return SpeedLimits([
      for (final z in raw) SpeedZone(startM: z.startM * scale, endM: z.endM * scale, kph: z.kph),
    ]);
  }

  /// The limit at [alongM] metres from the start, or null where it is not known.
  int? limitAt(double alongM) {
    var lo = 0;
    var hi = zones.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final z = zones[mid];
      if (alongM < z.startM) {
        hi = mid - 1;
      } else if (alongM >= z.endM) {
        lo = mid + 1;
      } else {
        return z.kph;
      }
    }
    return null;
  }
}

/// Reads a Valhalla `trace_attributes` response body.
SpeedLimits parseTraceAttributes(String body, {double? routeLengthM}) {
  final json = jsonDecode(body);
  if (json is! Map<String, dynamic>) return SpeedLimits.empty;
  final edges = json['edges'];
  if (edges is! List) return SpeedLimits.empty;
  return SpeedLimits.fromEdges(
    edges,
    routeLengthM: routeLengthM,
    metresPerUnit: json['units'] == 'miles' ? 1609.344 : 1000,
  );
}

/// Decides when to say "slow down".
///
/// It speaks only when the driver is at least [marginKph] over a known limit for [hold] in a row
/// (one wobbly GPS reading is not speeding), only once per stretch of road with the same limit,
/// and never twice within [cooldown].
class SpeedWarner {
  SpeedWarner({
    this.marginKph = 5,
    this.hold = const Duration(seconds: 3),
    this.cooldown = const Duration(seconds: 60),
  });

  final double marginKph;
  final Duration hold;
  final Duration cooldown;

  int? _zoneKph;
  bool _warnedInZone = false;
  DateTime? _overSince;
  DateTime? _lastWarning;

  /// True when [speedKph] counts as over [limitKph] for the speedometer's red colour.
  bool isOver(int? limitKph, double speedKph) =>
      limitKph != null && speedKph >= limitKph + marginKph;

  /// Call on every position update. Returns true when the warning should be spoken now.
  bool update({required int? limitKph, required double speedKph, required DateTime now}) {
    if (limitKph != _zoneKph) {
      _zoneKph = limitKph;
      _warnedInZone = false;
      _overSince = null;
    }
    if (!isOver(limitKph, speedKph)) {
      _overSince = null;
      return false;
    }
    final since = _overSince ??= now;
    if (_warnedInZone || now.difference(since) < hold) return false;
    final last = _lastWarning;
    if (last != null && now.difference(last) < cooldown) return false;
    _warnedInZone = true;
    _lastWarning = now;
    return true;
  }

  void reset() {
    _zoneKph = null;
    _warnedInZone = false;
    _overSince = null;
    _lastWarning = null;
  }
}
