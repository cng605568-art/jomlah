import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
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

    // Knows the destination: both lines are options, and the placeholder is filled in.
    final first = pickLine(lines, distance: '300 metres', street: '', toward: 'Putrajaya', rng: _Pick(0))!;
    final second = pickLine(lines, distance: '300 metres', street: '', toward: 'Putrajaya', rng: _Pick(1))!;
    expect(first.text, 'In 300 metres, exit.');
    expect(second.text, 'In 300 metres, exit towards Putrajaya.');
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
