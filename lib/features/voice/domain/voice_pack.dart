import 'dart:math';
import '../../routing/domain/route_plan.dart';

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
  speeding, // over the legal limit; lines use {limit}
}

/// A personality. Lines may use {d} (spoken distance), {street}, {toward} (where an exit leads),
/// {exit} (exit number and interchange name, e.g. "exit 2 0 9, UPM"), {nth} (which roundabout
/// exit, e.g. "kedua") and {limit} (the speed limit in km/h).
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
    this.then = '',
    this.short = const {},
    this.ordinals = const [],
    this.exitWord = 'exit',
  });

  final String id;
  final String name;
  final String tagline;
  final String locale; // TTS language, e.g. ms-MY
  final String meter; // spoken unit words
  final String km;
  final Map<Cue, List<String>> advance; // "in 300 metres, turn left"
  final Map<Cue, List<String>> now; // "turn left now" (optional per cue)

  /// Added when a second turn follows right after the first: "Lepas tu, {next}." where {next} is
  /// the [short] phrase for that second turn.
  final String then;
  final Map<Cue, String> short; // "belok kiri", "keep right"...
  final List<String> ordinals; // first, second, third... for roundabout exits

  /// The word before an exit number in {exit}: "exit 2 0 9", or "出口 2 0 9".
  final String exitWord;
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

/// Picks a line, avoiding the last one used and any line needing a {street}, {toward}, {exit},
/// {nth} or {limit} we lack. Lines that say more about the exit ({exit}, {toward}, {nth}) win over
/// plainer ones, because at a busy interchange the details are what the driver needs; among
/// equally detailed lines the pick is random.
({String text, int index})? pickLine(
  List<String>? lines, {
  required String distance,
  required String street,
  String toward = '',
  String exit = '',
  String nth = '',
  String limit = '',
  required Random rng,
  int avoidIndex = -1,
}) {
  if (lines == null || lines.isEmpty) return null;
  final values = {
    '{street}': street,
    '{toward}': toward,
    '{exit}': exit,
    '{nth}': nth,
    '{limit}': limit,
  };
  bool fits(String line) => values.entries.every((e) => e.value.isNotEmpty || !line.contains(e.key));
  int detail(String line) =>
      (line.contains('{exit}') ? 2 : 0) + (line.contains('{toward}') ? 1 : 0) + (line.contains('{nth}') ? 2 : 0);

  final usable = <int>[for (var i = 0; i < lines.length; i++) if (fits(lines[i])) i];
  if (usable.isEmpty) return null;
  final most = usable.map((i) => detail(lines[i])).reduce(max);
  final richest = usable.where((i) => detail(lines[i]) == most).toList();
  var candidates = richest.where((i) => i != avoidIndex).toList();
  if (candidates.isEmpty) candidates = richest;
  final i = candidates[rng.nextInt(candidates.length)];
  var text = lines[i].replaceAll('{d}', distance);
  values.forEach((k, v) => text = text.replaceAll(k, v));
  return (text: text, index: i);
}

/// Where an exit leads, for speaking: the first two places, skipping route codes such as "E26"
/// when there are real names, and skipping the exit's own name (already said by {exit}: "exit
/// 2 1 8, Seremban, ke arah Labu", not "... Seremban, ke arah Seremban"). Joined with a comma
/// (a "/" would be read out as "slash").
String spokenToward(ExitSign? sign) {
  if (sign == null || sign.toward.isEmpty) return '';
  final code = RegExp(r'^([A-Z]{1,3}\s?)?\d+[A-Z]?$'); // E26, B13, FT2, or a bare number
  final exitName = sign.name.isEmpty ? '' : sign.name.first.trim().toLowerCase();
  final names = sign.toward.where((t) => !code.hasMatch(t.trim())).toList();
  if (names.isEmpty) return sign.toward.first; // only route codes: say the first one
  return names.where((t) => t.trim().toLowerCase() != exitName).take(2).join(', ');
}

/// The exit as said out loud: "exit 2 0 9, UPM", "exit 3 3 0 6 C", or "exit Salak". The number
/// is read one character at a time, as people read exit numbers off the sign; a text-to-speech
/// voice would otherwise say "one thousand two hundred and three".
String spokenExit(ExitSign? sign, {String word = 'exit'}) {
  if (sign == null) return '';
  final number = sign.numberText?.trim() ?? '';
  final name = sign.name.isEmpty ? '' : sign.name.first.trim();
  if (number.isEmpty && name.isEmpty) return '';
  final digits = number.split('').where((c) => c.trim().isNotEmpty).join(' ');
  return [if (digits.isNotEmpty) '$word $digits' else '$word $name', if (digits.isNotEmpty && name.isNotEmpty) name]
      .join(', ');
}

/// "kedua" / "second" for a roundabout's 2nd exit, or '' when the pack has no word for it.
String spokenOrdinal(int? n, VoicePack pack) =>
    n == null || n < 1 || n > pack.ordinals.length ? '' : pack.ordinals[n - 1];
