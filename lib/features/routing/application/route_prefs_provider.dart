import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/prefs.dart';
import '../domain/route_prefs.dart';

class RoutePrefsNotifier extends Notifier<RoutePrefs> {
  @override
  RoutePrefs build() {
    final p = ref.read(sharedPrefsProvider);
    final v = p.getString('route.vehicle');
    return RoutePrefs(
      vehicle: Vehicle.values.firstWhere((e) => e.name == v, orElse: () => Vehicle.car),
      avoidTolls: p.getBool('route.avoidTolls') ?? false,
    );
  }

  void setVehicle(Vehicle v) {
    state = state.copyWith(vehicle: v);
    ref.read(sharedPrefsProvider).setString('route.vehicle', v.name);
  }

  void setAvoidTolls(bool v) {
    state = state.copyWith(avoidTolls: v);
    ref.read(sharedPrefsProvider).setBool('route.avoidTolls', v);
  }
}

final routePrefsProvider =
    NotifierProvider<RoutePrefsNotifier, RoutePrefs>(RoutePrefsNotifier.new);
