import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jomlah/features/routing/data/valhalla_client.dart';

// Three points near KLCC, encoded with Valhalla's precision-6 polyline format.
const _shape = r'wwv_E_n~~`EgbC_XowHo}@';

Map<String, dynamic> _trip({required double km, required double sec}) => {
      'summary': {'length': km, 'time': sec},
      'legs': [
        {
          'shape': _shape,
          'maneuvers': [
            {
              'type': 1,
              'instruction': 'Drive north on Jalan Ampang.',
              'length': 0.5,
              'begin_shape_index': 0,
              'end_shape_index': 1,
              'street_names': ['Jalan Ampang'],
            },
            {
              'type': 4,
              'instruction': 'You have arrived at your destination.',
              'length': 0.0,
              'begin_shape_index': 2,
              'end_shape_index': 2,
            },
          ],
        },
      ],
    };

void main() {
  test('parses the main route and its alternates, main first', () {
    final body = jsonEncode({
      'trip': _trip(km: 10.0, sec: 600),
      'alternates': [
        {'trip': _trip(km: 12.5, sec: 540)},
      ],
    });
    final plans = parseValhallaRoutes(body);
    expect(plans.length, 2);
    expect(plans[0].distanceKm, 10.0);
    expect(plans[1].durationSec, 540);
    expect(plans[0].shape.length, 3);
    expect(plans[0].shape.first.latitude, closeTo(3.1579, 1e-6));
    expect(plans[0].shape.last.longitude, closeTo(101.7130, 1e-6));
    expect(plans[0].maneuvers.length, 2);
    expect(plans[0].maneuvers.first.streetNames, ['Jalan Ampang']);
    expect(plans[0].totalM, greaterThan(500));
  });

  test('works when there are no alternates', () {
    final plans = parseValhallaRoutes(jsonEncode({'trip': _trip(km: 3.0, sec: 200)}));
    expect(plans.length, 1);
  });
}
