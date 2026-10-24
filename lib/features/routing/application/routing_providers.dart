import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../data/valhalla_client.dart';
import '../domain/route_plan.dart';

final valhallaClientProvider =
    Provider<ValhallaClient>((ref) => ValhallaClient());

class NavState {
  const NavState({
    this.destination,
    this.plan,
    this.loading = false,
    this.rerouting = false,
    this.error,
    this.next,
    this.distanceToNextM = 0,
    this.remainingM = 0,
    this.arrived = false,
    this.rerouteCount = 0,
  });

  final LatLng? destination;
  final RoutePlan? plan;
  final bool loading;
  final bool rerouting;
  final String? error;
  final Maneuver? next; // the upcoming maneuver
  final double distanceToNextM;
  final double remainingM;
  final bool arrived;

  /// Goes up by one on every completed automatic reroute.
  final int rerouteCount;

  NavState copyWith({
    bool? rerouting,
    Maneuver? next,
    double? distanceToNextM,
    double? remainingM,
    bool? arrived,
  }) =>
      NavState(
        destination: destination,
        plan: plan,
        loading: loading,
        rerouting: rerouting ?? this.rerouting,
        error: error,
        next: next ?? this.next,
        distanceToNextM: distanceToNextM ?? this.distanceToNextM,
        remainingM: remainingM ?? this.remainingM,
        arrived: arrived ?? this.arrived,
        rerouteCount: rerouteCount,
      );
}

class RoutingNotifier extends Notifier<NavState> {
  static const _offRouteThresholdM = 60.0;
  static const _rerouteCooldown = Duration(seconds: 10); // also keeps us polite to the server

  int _seg = 0; // shape segment we are on; never moves backwards
  double _offRouteM = 0; // distance from the route at the last GPS fix
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  NavState build() => const NavState();

  Future<void> start(LatLng from, LatLng to) async {
    _seg = 0;
    _offRouteM = 0;
    state = NavState(destination: to, loading: true);
    try {
      final plan = await ref.read(valhallaClientProvider).route(from, to);
      if (state.destination != to) return; // cancelled while waiting
      state = _track(NavState(destination: to, plan: plan), from);
    } on RoutingException catch (e) {
      state = NavState(destination: to, error: e.message);
    } catch (_) {
      state = NavState(destination: to, error: 'Alamak, ada masalah. Cuba lagi.');
    }
  }

  void cancel() {
    _seg = 0;
    state = const NavState();
  }

  /// Call on every GPS fix.
  void onPosition(LatLng here) {
    final s = state;
    if (s.plan == null || s.loading || s.arrived) return;
    state = _track(s, here);
    final cooledDown = DateTime.now().difference(_lastReroute) > _rerouteCooldown;
    if (_offRouteM > _offRouteThresholdM && !s.rerouting && cooledDown) {
      _reroute(here);
    }
  }

  /// Metres from [p] to the part of the route still ahead of us, or null with no route.
  /// Used to ignore road alerts that are on a parallel street.
  double? distanceFromRoute(LatLng p) {
    final plan = state.plan;
    if (plan == null || plan.shape.length < 2) return null;
    final first = math.min(_seg, plan.shape.length - 2);
    final last = math.min(plan.shape.length - 2, _seg + 400);
    var best = double.infinity;
    for (var i = first; i <= last; i++) {
      best = math.min(best, _project(p, plan.shape[i], plan.shape[i + 1]).dist);
    }
    return best;
  }

  Future<void> _reroute(LatLng here) async {
    final dest = state.destination;
    if (dest == null) return;
    _lastReroute = DateTime.now();
    state = state.copyWith(rerouting: true);
    try {
      final plan = await ref.read(valhallaClientProvider).route(here, dest);
      if (state.destination != dest) return; // cancelled while waiting
      _seg = 0;
      state = _track(
        NavState(
          destination: dest,
          plan: plan,
          rerouteCount: state.rerouteCount + 1,
        ),
        here,
      );
    } catch (_) {
      state = state.copyWith(rerouting: false); // keep the old route, try again later
    }
  }

  /// Works out where we are on the route, the next maneuver and the distances.
  NavState _track(NavState s, LatLng here) {
    final plan = s.plan!;
    final shape = plan.shape;
    if (shape.length < 2 || plan.maneuvers.isEmpty) return s;

    // Highways have vertices kilometres apart, so measure to segments, not points.
    final first = math.max(0, _seg - 3);
    final last = math.min(shape.length - 2, _seg + 400);
    var bestSeg = math.min(_seg, shape.length - 2);
    var bestT = 0.0;
    var bestD = double.infinity;
    for (var i = first; i <= last; i++) {
      final p = _project(here, shape[i], shape[i + 1]);
      if (p.dist < bestD) {
        bestD = p.dist;
        bestSeg = i;
        bestT = p.t;
      }
    }
    _seg = bestSeg;
    _offRouteM = bestD;

    final cum = plan.cumulativeM;
    final along = cum[bestSeg] + bestT * (cum[bestSeg + 1] - cum[bestSeg]);
    final remaining = math.max(0.0, plan.totalM - along);
    final next = plan.maneuvers.firstWhere(
      (m) => m.beginIndex > bestSeg,
      orElse: () => plan.maneuvers.last,
    );
    final nextAt = cum[math.min(next.beginIndex, cum.length - 1)];

    return s.copyWith(
      next: next,
      distanceToNextM: math.max(0.0, nextAt - along),
      remainingM: remaining,
      arrived: remaining < 30 && bestD < _offRouteThresholdM,
    );
  }
}

final routingProvider =
    NotifierProvider<RoutingNotifier, NavState>(RoutingNotifier.new);

/// Distance from point [p] to segment a-b in metres, plus how far along it (0..1).
/// Flat-earth maths is plenty accurate at street scale.
({double dist, double t}) _project(LatLng p, LatLng a, LatLng b) {
  const k = 111320.0; // metres per degree of latitude
  final cosLat = math.cos(p.latitude * math.pi / 180);
  final ax = (a.longitude - p.longitude) * k * cosLat;
  final ay = (a.latitude - p.latitude) * k;
  final bx = (b.longitude - p.longitude) * k * cosLat;
  final by = (b.latitude - p.latitude) * k;
  final dx = bx - ax;
  final dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : math.min(1.0, math.max(0.0, (-ax * dx - ay * dy) / len2));
  final px = ax + t * dx;
  final py = ay + t * dy;
  return (dist: math.sqrt(px * px + py * py), t: t);
}
