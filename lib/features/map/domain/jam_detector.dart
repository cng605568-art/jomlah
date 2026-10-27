/// Notices when a driver has been crawling for a while and it is worth offering a one-tap
/// "Jem Teruk" report. Pure logic, so the timing is easy to test.
class JamDetector {
  JamDetector({
    this.slowMps = 3.0, // about 11 km/h
    this.minSlow = const Duration(seconds: 120), // long red lights last less than this
    this.cooldown = const Duration(minutes: 15),
  });

  final double slowMps;
  final Duration minSlow;
  final Duration cooldown;

  DateTime? _slowSince;
  DateTime? _lastAsk;

  void reset() {
    _slowSince = null;
    _lastAsk = null;
  }

  /// Feed every GPS fix. Returns true once, when it is time to ask.
  bool update({
    required DateTime now,
    required double speedMps,
    required bool navigating,
    required double remainingM,
  }) {
    // Not on a trip, nearly there, or moving normally: nothing to ask.
    if (!navigating || remainingM < 300 || speedMps >= slowMps) {
      _slowSince = null;
      return false;
    }
    _slowSince ??= now;
    final slowLongEnough = now.difference(_slowSince!) >= minSlow;
    final last = _lastAsk;
    final cooledDown = last == null || now.difference(last) >= cooldown;
    if (slowLongEnough && cooledDown) {
      _lastAsk = now;
      _slowSince = null;
      return true;
    }
    return false;
  }
}
