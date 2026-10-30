import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jomlah/core/geo.dart';
import 'package:jomlah/features/routing/domain/route_plan.dart';
import 'package:jomlah/features/voice/application/voice_engine.dart';
import 'package:jomlah/features/voice/application/voice_providers.dart';
import 'package:jomlah/features/voice/domain/voice_pack.dart';
import 'package:jomlah/features/voice/domain/voice_packs.dart';

void main() {
  test('spokenDistance rounds sensibly', () {
    expect(spokenDistance(480, kSerious), '500 metres');
    expect(spokenDistance(10, kSerious), '50 metres');
    expect(spokenDistance(1234, kSerious), '1.2 kilometres');
  });

  test('pickLine skips {street} lines when there is no street', () {
    final lines = ['In {d}, go.', 'In {d}, go onto {street}.'];
    for (var i = 0; i < 30; i++) {
      final p = pickLine(lines, distance: '200 metres', street: '', rng: Random(i))!;
      expect(p.text, 'In 200 metres, go.');
    }
    final withStreet = pickLine(
      lines,
      distance: '200 metres',
      street: 'Jalan Duta',
      rng: Random(3),
    )!;
    expect(withStreet.text.contains('{'), isFalse);
  });

  test('pickLine only uses {toward} lines when it knows where the exit goes', () {
    final lines = ['In {d}, exit.', 'In {d}, exit towards {toward}.'];

    // No idea where the exit goes: the {toward} line is never an option, whatever the dice say.
    for (var n = 0; n < 5; n++) {
      final p = pickLine(lines, distance: '300 metres', street: '', rng: _Pick(n))!;
      expect(p.text, 'In 300 metres, exit.');
    }

    // Knows the destination: the line that says it wins, whatever the dice say.
    for (var n = 0; n < 5; n++) {
      final p = pickLine(lines, distance: '300 metres', street: '', toward: 'Putrajaya', rng: _Pick(n))!;
      expect(p.text, 'In 300 metres, exit towards Putrajaya.');
    }
  });

  test('pickLine says as much about an exit as it knows', () {
    final lines = ['Exit.', 'Exit to {toward}.', 'Take {exit}.', 'Take {exit} to {toward}.'];
    String say({String toward = '', String exit = ''}) =>
        pickLine(lines, distance: '', street: '', toward: toward, exit: exit, rng: _Pick(1))!.text;
    expect(say(), 'Exit.');
    expect(say(toward: 'Klang'), 'Exit to Klang.');
    expect(say(exit: 'exit 2 0 9'), 'Take exit 2 0 9.');
    expect(say(exit: 'exit 2 0 9', toward: 'Klang'), 'Take exit 2 0 9 to Klang.');
  });

  test('exit numbers are read one character at a time, with the interchange name', () {
    expect(spokenExit(const ExitSign(number: ['209'], name: ['UPM'])), 'exit 2 0 9, UPM');
    expect(spokenExit(const ExitSign(number: ['3306C'])), 'exit 3 3 0 6 C');
    expect(spokenExit(const ExitSign(name: ['Salak'])), 'exit Salak');
    expect(spokenExit(const ExitSign(toward: ['Klang'])), '');
    expect(spokenExit(null), '');
  });

  test('destinations are spoken with commas, without route codes when there are names', () {
    expect(spokenToward(const ExitSign(toward: ['E26', 'Kajang', 'Putrajaya', 'Banting'])), 'Kajang, Putrajaya');
    expect(spokenToward(const ExitSign(toward: ['Seremban'])), 'Seremban');
    expect(spokenToward(const ExitSign(toward: ['E7', '1'])), 'E7'); // only codes: say the first
    expect(spokenToward(const ExitSign(number: ['5'])), '');
    expect(spokenToward(const ExitSign(toward: ['Pandan-Tebrau'])).contains('/'), isFalse);
    // Real PLUS exit 218: named Seremban, signed to Seremban and Labu. Say Seremban once.
    const exit218 = ExitSign(number: ['218'], name: ['Seremban'], toward: ['Seremban', 'Labu']);
    expect(spokenExit(exit218), 'exit 2 1 8, Seremban');
    expect(spokenToward(exit218), 'Labu');
    expect(spokenToward(const ExitSign(name: ['Seremban'], toward: ['Seremban'])), '');
  });

  test('roundabout exits are counted in each voice', () {
    for (final pack in kVoicePacks) {
      final nth = spokenOrdinal(2, pack);
      expect(nth, isNotEmpty, reason: pack.id);
      final p = pickLine(pack.advance[Cue.roundabout], distance: '200', street: '', nth: nth, rng: _Pick(0))!;
      expect(p.text, contains(nth), reason: pack.id);
      expect(p.text.contains('{'), isFalse, reason: pack.id);
    }
    expect(spokenOrdinal(0, kSerious), '');
    expect(spokenOrdinal(99, kSerious), '');
    expect(spokenOrdinal(null, kSerious), '');
  });

  test('every voice names the exit and where it goes, when the sign says', () {
    for (final pack in kVoicePacks) {
      for (final cue in [Cue.exitLeft, Cue.exitRight, Cue.keepLeft, Cue.keepRight]) {
        final p = pickLine(pack.advance[cue], distance: '500', street: '', exit: 'exit 2 0 9, UPM', toward: 'Serdang', rng: _Pick(0))!;
        expect(p.text, contains('exit 2 0 9, UPM'), reason: '${pack.id} ${cue.name}');
        expect(p.text, contains('Serdang'), reason: '${pack.id} ${cue.name}');
        expect(p.text.contains('{'), isFalse, reason: '${pack.id} ${cue.name}');
      }
    }
  });

  test('a turn right after another is announced together with it', () {
    // Three turns: a fork, a keep-left 150 m later, then a right turn 1 km after that, then arrival.
    final start = LatLng(3.1000, 101.7000);
    final shape = [start, for (final n in [400.0, 550.0, 1550.0, 1600.0]) offsetM(start, 0, n)];
    Maneuver turn(int type, int begin) =>
        Maneuver(type: type, instruction: '', lengthKm: 0, beginIndex: begin, endIndex: begin, streetNames: const []);
    final plan = RoutePlan(
      shape: shape,
      maneuvers: [turn(1, 0), turn(21, 1), turn(24, 2), turn(10, 3), turn(4, 4)],
      distanceKm: 1.6,
      durationSec: 200,
    );
    final m = plan.maneuvers;
    expect(thenPhrase(plan, m[1], kMamakBoss), 'Lepas tu terus ambil kiri.');
    expect(thenPhrase(plan, m[1], kSerious), 'Then keep left.');
    expect(thenPhrase(plan, m[2], kSerious), ''); // the right turn is 1 km on
    expect(thenPhrase(plan, m[2], kSerious, speedMps: 100), 'Then turn right.'); // very fast: it comes soon
    expect(thenPhrase(plan, m[3], kSerious), ''); // arriving is not a turn
    expect(thenPhrase(plan, m[4], kSerious), ''); // nothing after the last one
  });

  test('road alerts are announced only when ahead and in range', () {
    final here = LatLng(3.1000, 101.7000);
    final ahead = offsetM(here, 0, 300);
    expect(alertAheadM(here, 0, ahead), closeTo(300, 2));
    expect(alertAheadM(here, 180, ahead), isNull); // behind us
    expect(alertAheadM(here, null, ahead), closeTo(300, 2)); // heading unknown: distance only
    expect(alertAheadM(here, 0, offsetM(here, 0, 700)), isNull); // too far
    expect(alertAheadM(here, 0, offsetM(here, 0, 10)), isNull); // already on it
  });

  test('pickLine avoids repeating the previous line', () {
    final lines = ['A', 'B'];
    for (var i = 0; i < 20; i++) {
      final p = pickLine(lines, distance: '', street: '', rng: Random(i), avoidIndex: 0)!;
      expect(p.index, 1);
    }
  });

  test('maneuver types map to cues', () {
    expect(cueForManeuver(15), Cue.turnLeft);
    expect(cueForManeuver(10), Cue.turnRight);
    expect(cueForManeuver(4), isNull);
  });

  test('pickLine fills in {limit}, and skips such lines when there is no limit', () {
    final lines = ['Slow down.', 'Limit {limit}. Slow down.'];
    for (var n = 0; n < 4; n++) {
      expect(pickLine(lines, distance: '', street: '', rng: _Pick(n))!.text, 'Slow down.');
    }
    final withLimit = pickLine(lines, distance: '', street: '', limit: '80', rng: _Pick(1))!;
    expect(withLimit.text, 'Limit 80. Slow down.');
  });

  test('every pack says the actual limit when warning about speeding', () {
    for (final pack in kVoicePacks) {
      final lines = pack.advance[Cue.speeding];
      for (var n = 0; n < (lines?.length ?? 0); n++) {
        final p = pickLine(lines, distance: '', street: '', limit: '90', rng: _Pick(n))!;
        expect(p.text, contains('90'), reason: pack.id);
        expect(p.text.contains('{'), isFalse, reason: pack.id);
      }
    }
  });

  test('every pack can say every cue', () {
    for (final pack in kVoicePacks) {
      for (final cue in Cue.values) {
        expect(pack.advance[cue], isNotEmpty, reason: '${pack.id} is missing ${cue.name}');
      }
    }
  });
}

/// A "random" source that always answers n, so the test never depends on a seed.
class _Pick implements Random {
  _Pick(this.n);
  final int n;

  @override
  int nextInt(int max) => n % max;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}
