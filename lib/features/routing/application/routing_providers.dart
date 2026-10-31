import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';
import '../data/valhalla_client.dart';
import '../domain/route_plan.dart';
import 'route_prefs_provider.dart';

final valhallaClientProvider =
    Provider<ValhallaClient>((ref) => ValhallaClient());

/// The car's position pulled onto the road we are following.
class RouteSnap {
  const RouteSnap({
    required this.point,
    required this.bearingDeg,
    required this.distanceM,
    required this.alongM,
  });
  final LatLng point;
  final double bearingDeg; // direction of travel along the road here
  final double distanceM; // how far the GPS position was from the road
  final double alongM; // metres from the start of the route to [point]
}

class NavState {
  const NavState({
    this.destination,
    this.plan,
    this.candidates = const [],
    this.selected = 0,
    this.segment = 0,
    this.previewing = false,
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
  final RoutePlan? plan; // the chosen route
  final List<RoutePlan> candidates; // options shown while previewing
  final int selected;
  final int segment; // index of the route segment the car is on
  final bool previewing; // choosing a route, trip not started yet
  final bool loading;
  final bool rerouting;
  final RouteError? error;
  final Maneuver? next; // the upcoming maneuver
  final double distanceToNextM;
  final double remainingM;
  final bool arrived;

  /// Goes up by one on every completed automatic reroute.
  final int rerouteCount;

  /// A trip is underway: voice, background tracking and keep-awake all key off this.
  bool get navigating => plan != null && !previewing && !loading && !arrived;

  NavState copyWith({
    RoutePlan? plan,
    int? selected,
    int? segment,
    bool? previewing,
    bool? rerouting,
    Maneuver? next,
    double? distanceToNextM,
    double? remainingM,
    bool? arrived,
  }) =>
      NavState(
        destination: destination,
        plan: plan ?? this.plan,
        candidates: candidates,
        selected: selected ?? this.selected,
        segment: segment ?? this.segment,
        previewing: previewing ?? this.previewing,
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
  LatLng? _origin; // where the trip was planned from
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  NavState build() => const NavState();

  /// Plans the trip and shows the options. Nothing is spoken until [begin].
  Future<void> start(LatLng from, LatLng to) async {
    _seg = 0;
    _offRouteM = 0;
    _origin = from;
    state = NavState(destination: to, loading: true);
    try {
      final routes = await ref.read(valhallaClientProvider).routes(
            from,
            to,
            prefs: ref.read(routePrefsProvider),
            alternates: 2,
          );
      if (state.destination != to) return; // cancelled while waiting
      state = _track(
        NavState(destination: to, plan: routes.first, candidates: routes, previewing: true),
        from,
      );
    } on RoutingException catch (e) {
      state = NavState(destination: to, error: e.kind);
    } catch (_) {
      state = NavState(destination: to, error: RouteError.problem);
    }
  }

  /// Pick one of the previewed routes.
  void choose(int i) {
    final s = state;
    final origin = _origin;
    if (!s.previewing || origin == null || i < 0 || i >= s.candidates.length) return;
    _seg = 0;
    state = _track(
      NavState(
        destination: s.destination,
        plan: s.candidates[i],
        candidates: s.candidates,
        selected: i,
        previewing: true,
      ),
      origin,
    );
  }

  /// "Jom!" Start the trip.
  void begin() {
    if (!state.previewing) return;
    state = state.copyWith(previewing: false);
  }

  void cancel() {
    _seg = 0;
    state = const NavState();
  }

  /// Call on every GPS fix. Pass [headingDeg] when the car is clearly moving (it keeps the car on
  /// the side of the road it is really driving on; see [_nearest]).
  void onPosition(LatLng here, {double? headingDeg}) {
    final s = state;
    if (s.plan == null || s.loading || s.previewing || s.arrived) return;
    state = _track(s, here, headingDeg: headingDeg);
    final cooledDown = DateTime.now().difference(_lastReroute) > _rerouteCooldown;
    if (_offRouteM > _offRouteThresholdM && !s.rerouting && cooledDown) {
      _reroute(here);
    }
  }

  /// Pulls [p] onto the route when it is within [maxDistanceM] of it (GPS drifts a few metres, roads do
  /// not). Returns null when not navigating or when the car is clearly somewhere else.
  RouteSnap? snap(LatLng p, {double maxDistanceM = 30, double? headingDeg}) {
    final plan = state.plan;
    if (!state.navigating || plan == null || plan.shape.length < 2) return null;
    final shape = plan.shape;
    final first = math.min(_seg, shape.length - 2);
    final last = math.min(shape.length - 2, _seg + 40); // only look just ahead
    final best = _nearest(shape, p, first, last, headingDeg);
    if (best.dist > maxDistanceM) return null;
    final a = shape[best.seg];
    final b = shape[best.seg + 1];
    final cum = plan.cumulativeM;
    return RouteSnap(
      point: LatLng(
        a.latitude + best.t * (b.latitude - a.latitude),
        a.longitude + best.t * (b.longitude - a.longitude),
      ),
      bearingDeg: bearingDeg(a, b),
      distanceM: best.dist,
      alongM: cum[best.seg] + best.t * (cum[best.seg + 1] - cum[best.seg]),
    );
  }

  /// The route segment between [first] and [last] closest to [p]. With [headingDeg], segments that
  /// point against the direction of travel are skipped: on Malaysian U-turn routes the way back runs
  /// right beside the way out, and the car must stay on the side it is really driving on (otherwise
  /// the U-turn instruction would be skipped). If every nearby segment points the other way, the
  /// heading is ignored.
  ({int seg, double t, double dist}) _nearest(
    List<LatLng> shape,
    LatLng p,
    int first,
    int last,
    double? headingDeg,
  ) {
    var best = (seg: first, t: 0.0, dist: double.infinity);
    for (var i = first; i <= last; i++) {
      if (headingDeg != null && _against(shape[i], shape[i + 1], headingDeg)) continue;
      final r = _project(p, shape[i], shape[i + 1]);
      if (r.dist < best.dist) best = (seg: i, t: r.t, dist: r.dist);
    }
    if (best.dist == double.infinity && headingDeg != null) {
      return _nearest(shape, p, first, last, null);
    }
    return best;
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
      final routes = await ref.read(valhallaClientProvider).routes(
            here,
            dest,
            prefs: ref.read(routePrefsProvider),
          );
      if (state.destination != dest) return; // cancelled while waiting
      _seg = 0;
      state = _track(
        NavState(
          destination: dest,
          plan: routes.first,
          rerouteCount: state.rerouteCount + 1,
        ),
        here,
      );
    } catch (_) {
      state = state.copyWith(rerouting: false); // keep the old route, try again later
    }
  }

  /// Works out where we are on the route, the next maneuver and the distances.
  NavState _track(NavState s, LatLng here, {double? headingDeg}) {
    final plan = s.plan!;
    final shape = plan.shape;
    if (shape.length < 2 || plan.maneuvers.isEmpty) return s;

    // Highways have vertices kilometres apart, so measure to segments, not points.
    final first = math.min(math.max(0, _seg - 3), shape.length - 2);
    final last = math.min(shape.length - 2, _seg + 400);
    final best = _nearest(shape, here, first, last, headingDeg);
    final bestSeg = best.seg;
    final bestT = best.t;
    final bestD = best.dist;
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
      segment: bestSeg,
      next: next,
      distanceToNextM: math.max(0.0, nextAt - along),
      remainingM: remaining,
      arrived: !s.previewing && remaining < 30 && bestD < _offRouteThresholdM,
    );
  }
}

final routingProvider =
    NotifierProvider<RoutingNotifier, NavState>(RoutingNotifier.new);

/// True when segment a-b points more than 100 degrees away from [headingDeg].
bool _against(LatLng a, LatLng b, double headingDeg) {
  if (haversineM(a, b) < 1) return false; // too short to have a direction
  final diff = ((bearingDeg(a, b) - headingDeg + 540) % 360) - 180;
  return diff.abs() > 100;
}

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
