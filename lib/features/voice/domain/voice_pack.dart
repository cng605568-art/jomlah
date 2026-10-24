import 'dart:math';

/// Everything the voice can be asked to say.
enum Cue {
  start,
  turnLeft,
  turnRight,
  keepLeft,
  keepRight,
  exitLeft,
  exitRight,
  uTurn,
  roundabout,
  merge,
  arrive,
  recalculating,
  police,
  camera,
  flood,
  pothole,
  lorry,
  jam,
  crash,
}

/// A personality. Lines may use {d} (spoken distance) and {street}.
/// Later, each line can map to a recorded clip; today they go through the phone's TTS.
class VoicePack {
  const VoicePack({
    required this.id,
    required this.name,
    required this.tagline,
    required this.locale,
    required this.meter,
    required this.km,
    required this.advance,
    this.now = const {},
  });

  final String id;
  final String name;
  final String tagline;
  final String locale; // TTS language, e.g. ms-MY
  final String meter; // spoken unit words
  final String km;
  final Map<Cue, List<String>> advance; // "in 300 metres, turn left"
  final Map<Cue, List<String>> now; // "turn left now" (optional per cue)
}

/// Valhalla maneuver type -> cue. Null means "say nothing" (straight on, start, arrival...).
Cue? cueForManeuver(int type) {
  switch (type) {
    case 14:
    case 15:
      return Cue.turnLeft;
    case 10:
    case 11:
      return Cue.turnRight;
    case 16:
    case 24:
      return Cue.keepLeft;
    case 9:
    case 23:
      return Cue.keepRight;
    case 21:
    case 19:
      return Cue.exitLeft;
    case 20:
    case 18:
      return Cue.exitRight;
    case 12:
    case 13:
      return Cue.uTurn;
    case 26:
      return Cue.roundabout;
    case 25:
      return Cue.merge;
    default:
      return null;
  }
}

/// "500 metres", "1.2 kilometres" (words come from the pack so TTS reads them naturally).
String spokenDistance(double m, VoicePack pack) {
  final rounded = max(50, (m / 50).round() * 50);
  if (rounded < 1000) return '$rounded ${pack.meter}';
  return '${((m / 100).round() / 10).toStringAsFixed(1)} ${pack.km}';
}

/// Picks a random line, avoiding the last one used and any {street} line when we have no street.
({String text, int index})? pickLine(
  List<String>? lines, {
  required String distance,
  required String street,
  required Random rng,
  int avoidIndex = -1,
}) {
  if (lines == null || lines.isEmpty) return null;
  final usable = <int>[
    for (var i = 0; i < lines.length; i++)
      if (street.isNotEmpty || !lines[i].contains('{street}')) i,
  ];
  if (usable.isEmpty) return null;
  var candidates = usable.where((i) => i != avoidIndex).toList();
  if (candidates.isEmpty) candidates = usable;
  final i = candidates[rng.nextInt(candidates.length)];
  final text = lines[i].replaceAll('{d}', distance).replaceAll('{street}', street);
  return (text: text, index: i);
}
