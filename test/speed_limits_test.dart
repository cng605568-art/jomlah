import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jomlah/features/routing/domain/speed_limits.dart';

void main() {
  group('SpeedLimits.fromEdges', () {
    final edges = [
      {'length': 0.2, 'speed_limit': 50},
      {'length': 0.3, 'speed_limit': 50},
      {'length': 0.1}, // the map does not know this one
      {'length': 0.4, 'speed_limit': 80},
    ];

    test('turns edges into zones, joining neighbours with the same limit', () {
      final limits = SpeedLimits.fromEdges(edges);
      expect(limits.zones.length, 2);
      expect(limits.zones[0].kph, 50);
      expect(limits.zones[0].startM, closeTo(0, 1e-6));
      expect(limits.zones[0].endM, closeTo(500, 1e-6));
      expect(limits.zones[1].kph, 80);
      expect(limits.zones[1].startM, closeTo(600, 1e-6));
      expect(limits.zones[1].endM, closeTo(1000, 1e-6));
    });

    test('limitAt answers inside zones and null where the limit is unknown', () {
      final limits = SpeedLimits.fromEdges(edges);
      expect(limits.limitAt(0), 50);
      expect(limits.limitAt(499), 50);
      expect(limits.limitAt(550), isNull); // the unknown stretch: show nothing, never guess
      expect(limits.limitAt(600), 80);
      expect(limits.limitAt(999), 80);
      expect(limits.limitAt(1000), isNull); // past the end
      expect(limits.limitAt(-5), isNull);
    });

    test('lines zone positions up with the app\'s own route length', () {
      final limits = SpeedLimits.fromEdges([
        {'length': 0.5, 'speed_limit': 60},
        {'length': 0.5, 'speed_limit': 90},
      ], routeLengthM: 1010);
      expect(limits.zones[1].startM, closeTo(505, 1e-6));
      expect(limits.zones[1].endM, closeTo(1010, 1e-6));
    });

    test('ignores a route length that clearly belongs to something else', () {
      final limits = SpeedLimits.fromEdges([
        {'length': 1.0, 'speed_limit': 60},
      ], routeLengthM: 5000);
      expect(limits.zones.single.endM, closeTo(1000, 1e-6));
    });

    test('treats 0, 255 and odd values as unknown', () {
      final limits = SpeedLimits.fromEdges([
        {'length': 0.1, 'speed_limit': 0},
        {'length': 0.1, 'speed_limit': 255},
        {'length': 0.1, 'speed_limit': 'unlimited'},
        {'length': 0.1, 'speed_limit': null},
        {'length': 0.1},
        'not an edge',
      ]);
      expect(limits.isEmpty, isTrue);
      expect(limits.limitAt(50), isNull);
    });
  });

  test('parseTraceAttributes reads a response shaped like the public server\'s', () {
    // Trimmed from a real answer for a KL city route (lengths in kilometres).
    final body = jsonEncode({
      'units': 'kilometers',
      'edges': [
        {'road_class': 'service_other', 'length': 0.39, 'names': ['Lorong Kuda']},
        {'road_class': 'motorway', 'length': 1.2, 'speed_limit': 80, 'names': ['E12']},
        {'road_class': 'secondary', 'length': 0.4, 'speed_limit': 50, 'names': ['Jalan Sultan Ismail']},
      ],
    });
    final limits = parseTraceAttributes(body);
    expect(limits.limitAt(100), isNull);
    expect(limits.limitAt(1000), 80);
    expect(limits.limitAt(1700), 50);
  });

  test('parseTraceAttributes copes with miles and with junk', () {
    final miles = parseTraceAttributes(jsonEncode({
      'units': 'miles',
      'edges': [
        {'length': 1.0, 'speed_limit': 50},
      ],
    }));
    expect(miles.zones.single.endM, closeTo(1609.344, 1e-6));
    expect(parseTraceAttributes('[]').isEmpty, isTrue);
    expect(parseTraceAttributes(jsonEncode({'edges': 'nope'})).isEmpty, isTrue);
  });

  group('SpeedWarner', () {
    final t0 = DateTime(2026, 1, 1, 8);
    DateTime at(int s) => t0.add(Duration(seconds: s));

    test('stays quiet when under the limit plus the 5 km/h margin', () {
      final w = SpeedWarner();
      for (var s = 0; s < 20; s++) {
        expect(w.update(limitKph: 80, speedKph: 84, now: at(s)), isFalse);
      }
    });

    test('warns after 3 seconds over, and only once on the same stretch', () {
      final w = SpeedWarner();
      final said = [for (var s = 0; s < 120; s++) w.update(limitKph: 80, speedKph: 95, now: at(s))];
      expect(said.where((x) => x).length, 1);
      expect(said.indexOf(true), 3);
    });

    test('one wobbly GPS reading is not speeding', () {
      final w = SpeedWarner();
      expect(w.update(limitKph: 60, speedKph: 90, now: at(0)), isFalse);
      expect(w.update(limitKph: 60, speedKph: 55, now: at(1)), isFalse);
      expect(w.update(limitKph: 60, speedKph: 90, now: at(2)), isFalse);
      expect(w.update(limitKph: 60, speedKph: 90, now: at(4)), isFalse); // only 2 s over so far
      expect(w.update(limitKph: 60, speedKph: 90, now: at(5)), isTrue);
    });

    test('a new limit can warn again, but not within the cooldown', () {
      final w = SpeedWarner();
      for (var s = 0; s <= 3; s++) {
        w.update(limitKph: 80, speedKph: 100, now: at(s)); // warned at 3 s
      }
      // Straight into a 60 zone, still fast: quiet until 60 s after the last warning.
      final soon = [for (var s = 4; s < 60; s++) w.update(limitKph: 60, speedKph: 100, now: at(s))];
      expect(soon.contains(true), isFalse);
      expect(w.update(limitKph: 60, speedKph: 100, now: at(63)), isTrue);
    });

    test('an unknown limit is never speeding', () {
      final w = SpeedWarner();
      for (var s = 0; s < 10; s++) {
        expect(w.update(limitKph: null, speedKph: 150, now: at(s)), isFalse);
      }
      expect(w.isOver(null, 150), isFalse);
      expect(w.isOver(80, 85), isTrue);
      expect(w.isOver(80, 84.9), isFalse);
    });

    test('reset forgets everything', () {
      final w = SpeedWarner();
      for (var s = 0; s <= 3; s++) {
        w.update(limitKph: 80, speedKph: 100, now: at(s));
      }
      w.reset();
      for (var s = 10; s <= 12; s++) {
        expect(w.update(limitKph: 80, speedKph: 100, now: at(s)), isFalse);
      }
      expect(w.update(limitKph: 80, speedKph: 100, now: at(13)), isTrue);
    });
  });
}
