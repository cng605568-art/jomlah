import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/route_plan.dart';
import '../domain/speed_limits.dart';
import 'route_prefs_provider.dart';
import 'routing_providers.dart';

/// Speed limits for the route being driven. Fetched once after Jom! and again after each reroute
/// (the plan object only changes then). Nothing is fetched while just previewing routes.
final speedLimitsProvider = FutureProvider<SpeedLimits>((ref) async {
  final RoutePlan? plan = ref.watch(routingProvider.select((s) => s.navigating ? s.plan : null));
  if (plan == null) return SpeedLimits.empty;
  final costing = ref.read(routePrefsProvider).vehicle.costing;
  return ref.read(valhallaClientProvider).speedLimits(plan, costing: costing);
});

/// The legal limit where the car is now, in km/h, or null where the map does not know it
/// (or while the limits for a fresh route are still loading).
final currentSpeedLimitProvider = Provider<int?>((ref) {
  final limits = ref.watch(speedLimitsProvider);
  if (limits.isLoading) return null; // a new route: the old limits no longer line up
  final zones = limits.valueOrNull;
  if (zones == null || zones.isEmpty) return null;
  final nav = ref.watch(routingProvider);
  final plan = nav.plan;
  if (!nav.navigating || plan == null) return null;
  return zones.limitAt(plan.totalM - nav.remainingM);
});
