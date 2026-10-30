import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jomlah/features/routing/domain/lanes.dart';
import 'package:jomlah/features/routing/domain/route_plan.dart';
import 'package:jomlah/features/routing/presentation/nav_banner.dart';
import 'package:jomlah/features/map/presentation/overlays.dart';

// The answer's shape matches what valhalla1.openstreetmap.de sent for real KL routes (Oct 2026):
// /trace_route with format "osrm" gives matchings -> legs -> steps, one step per turn, and the first
// intersection of a step lists the lanes on the way into that turn, left to right.

final _shape = [
  LatLng(3.1000, 101.7000),
  LatLng(3.1050, 101.7000),
  LatLng(3.1100, 101.7000),
  LatLng(3.1150, 101.7000),
];

Maneuver _turn(int type, int begin) => Maneuver(
      type: type,
      instruction: '',
      lengthKm: 0.5,
      beginIndex: begin,
      endIndex: begin + 1,
      streetNames: const [],
    );

final _plan = RoutePlan(
  shape: _shape,
  maneuvers: [_turn(1, 0), _turn(24, 1), _turn(23, 2), _turn(4, 3)],
  distanceKm: 1.7,
  durationSec: 120,
);

Map<String, dynamic> _lane(List<String> arrows, {bool valid = false, bool active = false, String? ours}) => {
      'indications': arrows,
      'valid': valid,
      'active': active,
      if (ours != null) 'valid_indication': ours,
    };

Map<String, dynamic> _step(LatLng at, List<Map<String, dynamic>>? lanes) => {
      'maneuver': {
        'location': [at.longitude, at.latitude],
        'type': 'fork',
      },
      'intersections': [
        {
          'location': [at.longitude, at.latitude],
          if (lanes != null) 'lanes': lanes,
        },
      ],
    };

String _answer(List<Map<String, dynamic>> steps) => jsonEncode({
      'code': 'Ok',
      'matchings': [
        {
          'legs': [
            {'steps': steps},
          ],
        },
      ],
    });

void main() {
  test('lanes are matched to the turn they lead into', () {
    final body = _answer([
      _step(_shape[0], null),
      _step(_shape[1], [
        _lane(['slight left'], valid: true, active: true, ours: 'slight left'),
        _lane(['slight left', 'straight'], valid: true, ours: 'slight left'),
        _lane(['straight']),
      ]),
      _step(_shape[2], [
        _lane(['left']),
        _lane(['straight'], valid: true, active: true),
      ]),
      _step(_shape[3], null),
    ]);
    final lanes = parseLanes(body, _plan);
    expect(lanes.keys, unorderedEquals([1, 2]));
    final fork = lanes[1]!;
    expect(fork.map((l) => l.use), [LaneUse.best, LaneUse.ok, LaneUse.no]);
    expect(fork[1].shown, 'slight left'); // the arrow that matches our turn, not the first painted
    expect(fork[2].shown, 'straight');
  });

  test('lanes that all lead our way say nothing, so they are left out', () {
    final body = _answer([
      _step(_shape[1], [
        _lane(['straight'], valid: true, active: true),
        _lane(['straight'], valid: true, active: true),
      ]),
    ]);
    expect(parseLanes(body, _plan), isEmpty);
  });

  test('a single lane, or lanes far from any turn, are ignored', () {
    final body = _answer([
      _step(_shape[1], [_lane(['left'], valid: true, active: true)]),
      _step(LatLng(3.2, 101.8), [
        _lane(['left'], valid: true, active: true),
        _lane(['straight']),
      ]),
    ]);
    expect(parseLanes(body, _plan), isEmpty);
  });

  test('broken or unexpected answers give no lanes instead of an error', () {
    expect(parseLanes('not json', _plan), isEmpty);
    expect(parseLanes('[]', _plan), isEmpty);
    expect(parseLanes('{"code":"NoMatch"}', _plan), isEmpty);
    expect(parseLanes('{"matchings":[{"legs":[{"steps":[{"maneuver":{}}]}]}]}', _plan), isEmpty);
  });

  test('lane arrows map to icons, with U-turns to the right (we drive on the left)', () {
    final arrows = laneArrows(const [
      Lane(arrows: ['left'], use: LaneUse.no),
      Lane(arrows: ['straight', 'right'], use: LaneUse.best, ourArrow: 'right'),
      Lane(arrows: ['uturn'], use: LaneUse.ok),
      Lane(arrows: [], use: LaneUse.no),
    ]);
    expect(arrows.map((a) => a.look), [LaneLook.off, LaneLook.best, LaneLook.ok, LaneLook.off]);
    expect(arrows[1].icon, Icons.turn_right);
    expect(arrows[2].icon, Icons.u_turn_right);
    expect(arrows[3].icon, laneIcon('straight')); // no arrow painted: straight on
  });

  test('pointAlong walks the route, and practice alerts sit a third and two thirds along it', () {
    final plan = _plan;
    expect(pointAlong(plan, -5), _shape.first);
    expect(pointAlong(plan, plan.totalM + 5), _shape.last);
    final mid = pointAlong(plan, plan.cumulativeM[1] / 2);
    expect(mid.latitude, closeTo(3.1025, 1e-6));

    final spots = practiceAlertSpots(plan);
    expect(spots.map((s) => s.$1), ['camera', 'police']);
    expect(spots[0].$2.latitude, closeTo(3.1000 + 0.0150 / 3, 1e-5));
    expect(spots[1].$2.latitude, closeTo(3.1000 + 0.0150 * 2 / 3, 1e-5));

    final short = RoutePlan(shape: _shape.take(2).toList(), maneuvers: const [], distanceKm: 0.5, durationSec: 60);
    expect(practiceAlertSpots(short), isEmpty); // too short to hear anything
  });
}
