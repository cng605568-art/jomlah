/// Shown in Settings as Kereta / Motosikal (see AppStrings).
enum Vehicle {
  car('auto'),
  motorcycle('motorcycle');

  const Vehicle(this.costing);
  final String costing; // Valhalla costing model name
}

class RoutePrefs {
  const RoutePrefs({this.vehicle = Vehicle.car, this.avoidTolls = false});
  final Vehicle vehicle;
  final bool avoidTolls;

  RoutePrefs copyWith({Vehicle? vehicle, bool? avoidTolls}) => RoutePrefs(
        vehicle: vehicle ?? this.vehicle,
        avoidTolls: avoidTolls ?? this.avoidTolls,
      );

  /// 0 = strongly avoid tolls, 0.5 = Valhalla's default. A 0 is a strong hint, not a guarantee:
  /// some trips cannot be done without a toll road.
  Map<String, dynamic> get costingOptions => {
        vehicle.costing: {'use_tolls': avoidTolls ? 0.0 : 0.5},
      };
}
