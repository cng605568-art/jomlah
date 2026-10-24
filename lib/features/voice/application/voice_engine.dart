import 'dart:math';
import '../../routing/application/routing_providers.dart';
import '../data/speaker.dart';
import '../domain/voice_pack.dart';
import '../domain/voice_settings.dart';

/// Decides WHEN to speak. Priorities: 3 route events, 2 turns, 1 road alerts.
/// A lower priority never cuts off a higher one that is still talking.
class VoiceEngine {
  VoiceEngine({required this.speaker, required this.settings, Random? rng})
      : _rng = rng ?? Random();

  final Speaker speaker;
  final VoiceSettings Function() settings;
  final Random _rng;

  final Set<String> _announced = {}; // "<maneuver index>:adv" / ":now" for the current route
  final Set<String> _alerted = {}; // report ids already spoken
  final Map<Cue, int> _lastIndex = {};
  double _speedMps = 0;
  int _currentPriority = 0;
  String? _locale;

  void onSpeed(double mps) => _speedMps = mps;

  /// Call on every navigation state change (every GPS fix while navigating).
  void onNav(NavState? prev, NavState next) {
    // "Underway" means a route exists and the driver has pressed Jom! (not just previewing).
    bool underway(NavState? s) => s != null && s.plan != null && !s.previewing;
    final wasUnderway = underway(prev);

    if (!underway(next)) {
      if (wasUnderway) {
        _announced.clear();
        _alerted.clear();
      }
      return;
    }

    if (!wasUnderway) {
      _announced.clear();
      _say(Cue.start, priority: 3);
      return; // let "route ready" finish before the first turn cue
    }
    if (!identical(prev?.plan, next.plan)) _announced.clear(); // rerouted

    if (!(prev?.rerouting ?? false) && next.rerouting) {
      _say(Cue.recalculating, priority: 3);
    }
    if (next.rerouting) return;

    if (!(prev?.arrived ?? false) && next.arrived) {
      _say(Cue.arrive, priority: 3);
      return;
    }
    if (next.arrived) return;

    final m = next.next;
    if (m == null) return;
    final cue = cueForManeuver(m.type);
    if (cue == null) return;

    final d = next.distanceToNextM;
    // Faster driving means we need to warn earlier.
    final advanceAt = min(1500.0, max(500.0, _speedMps * 25));
    final nowAt = min(200.0, max(80.0, _speedMps * 6));
    final advKey = '${m.beginIndex}:adv';
    final nowKey = '${m.beginIndex}:now';
    final advDone = _announced.contains(advKey);
    final nowDone = _announced.contains(nowKey);
    final street = m.streetNames.isEmpty ? '' : m.streetNames.first;

    if (d <= nowAt) {
      if (nowDone) return;
      final hasNow = settings().pack.now[cue]?.isNotEmpty ?? false;
      if (hasNow) {
        if (_say(cue, now: true, priority: 2)) _announced.addAll([advKey, nowKey]);
      } else if (!advDone) {
        if (_say(cue, distM: d, street: street, priority: 2)) {
          _announced.addAll([advKey, nowKey]);
        }
      } else {
        _announced.add(nowKey);
      }
    } else if (d <= advanceAt && !advDone) {
      if (_say(cue, distM: d, street: street, priority: 2)) _announced.add(advKey);
    }
  }

  /// A road alert (police, flood...) that is ahead of us and on our route.
  void alert(String reportId, Cue cue, double distM) {
    if (_alerted.contains(reportId)) return;
    if (_say(cue, distM: distM, priority: 1)) _alerted.add(reportId);
  }

  /// Plays a sample in the current voice (used by the picker).
  void preview() => _say(Cue.police, distM: 300, priority: 3);

  /// Returns true if the line was accepted. False means muted, no line, or outranked.
  bool _say(
    Cue cue, {
    bool now = false,
    double distM = 0,
    String street = '',
    required int priority,
  }) {
    final s = settings();
    if (s.muted) return false;
    final pack = s.pack;
    final picked = pickLine(
      now ? pack.now[cue] : pack.advance[cue],
      distance: spokenDistance(distM, pack),
      street: street,
      rng: _rng,
      avoidIndex: _lastIndex[cue] ?? -1,
    );
    if (picked == null) return false;
    if (speaker.isSpeaking && priority < _currentPriority) return false;

    _lastIndex[cue] = picked.index;
    _currentPriority = priority;
    _speak(pack, picked.text);
    return true;
  }

  Future<void> _speak(VoicePack pack, String text) async {
    if (_locale != pack.locale) {
      _locale = pack.locale;
      await speaker.setLocale(pack.locale);
    }
    await speaker.speak(text);
  }
}
