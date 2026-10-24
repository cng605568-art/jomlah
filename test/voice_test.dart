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
