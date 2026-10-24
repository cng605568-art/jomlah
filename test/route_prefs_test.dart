import 'package:flutter_test/flutter_test.dart';
import 'package:jomlah/features/routing/domain/route_prefs.dart';

void main() {
  test('car default asks Valhalla for the auto model with default tolls', () {
    const p = RoutePrefs();
    expect(p.vehicle.costing, 'auto');
    expect(p.costingOptions, {
      'auto': {'use_tolls': 0.5},
    });
  });

  test('motorcycle with avoid tolls uses the motorcycle model and 0 toll appetite', () {
    const p = RoutePrefs(vehicle: Vehicle.motorcycle, avoidTolls: true);
    expect(p.vehicle.costing, 'motorcycle');
    expect(p.costingOptions, {
      'motorcycle': {'use_tolls': 0.0},
    });
  });
}
