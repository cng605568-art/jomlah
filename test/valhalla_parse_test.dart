import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jomlah/features/routing/data/valhalla_client.dart';

// Three points near KLCC, encoded with Valhalla's precision-6 polyline format.
const _shape = r'wwv_E_n~~`EgbC_XowHo}@';

Map<String, dynamic> _trip({required double km, required double sec, bool toll = false}) => {
      'summary': {'length': km, 'time': sec, 'has_toll': toll},
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
              'sign': {
                'exit_number_elements': [
                  {'text': '205'},
                ],
                'exit_toward_elements': [
                  {'text': 'Putrajaya'},
                  {'text': 'Cyberjaya'},
                ],
              },
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
      'trip': _trip(km: 10.0, sec: 600, toll: true),
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
    // Kept exactly as sent, so speed limits can be asked for along the very same roads.
    expect(plans[0].encodedShape, _shape);
  });

  test('reads highway exit signs and the toll flag', () {
    final body = jsonEncode({
      'trip': _trip(km: 10.0, sec: 600, toll: true),
      'alternates': [
        {'trip': _trip(km: 12.5, sec: 540)},
      ],
    });
    final plans = parseValhallaRoutes(body);
    final sign = plans[0].maneuvers.first.sign!;
    expect(sign.numberText, '205');
    expect(sign.towardText, 'Putrajaya / Cyberjaya');
    expect(sign.isEmpty, isFalse);
    expect(plans[0].maneuvers.last.sign, isNull); // arrival has no sign
    expect(plans[0].hasToll, isTrue);
    expect(plans[1].hasToll, isFalse);
  });

  test('works when there are no alternates', () {
    final plans = parseValhallaRoutes(jsonEncode({'trip': _trip(km: 3.0, sec: 200)}));
    expect(plans.length, 1);
  });
}
