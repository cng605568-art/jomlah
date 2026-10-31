import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/app_info.dart';
import '../../../core/app_theme.dart';
import '../../../core/geo.dart';
import '../../../core/l10n/language.dart';
import '../../../core/prefs.dart';
import '../../routing/application/routing_providers.dart';
import '../../routing/application/speed_limit_providers.dart';
import '../../routing/domain/route_plan.dart';
import '../../routing/domain/speed_limits.dart';
import '../../routing/presentation/nav_banner.dart';
import '../../search/application/search_providers.dart';
import '../../search/domain/place.dart';
import '../../voice/domain/voice_pack.dart';
import '../../search/presentation/search_box.dart';
import '../../settings/presentation/settings_button.dart';
import '../../voice/application/voice_providers.dart';
import '../application/map_style_provider.dart';
import '../application/providers.dart';
import '../application/traffic_providers.dart';
import '../domain/car_motion.dart';
import '../domain/gps_filter.dart';
import '../domain/report.dart';
import '../domain/simulated_drive.dart';
import '../domain/jam_detector.dart';
import '../domain/traffic.dart';
import '../domain/trip_stats.dart';
import 'arrival_sheet.dart';
import 'car_marker.dart';
import 'location_banner.dart';
import 'overlays.dart';
import 'vote_prompt.dart';
import 'widgets.dart';

const _tileUrl = String.fromEnvironment(
  'TILE_URL',
  // Dev only. OSM public tiles are not for production traffic. Self-host and build with:
  // flutter build apk --dart-define=TILE_URL=https://tiles.yourdomain.my/{z}/{x}/{y}.png
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);


/// Quick night mode: turns the light OSM tiles into dark navy with light labels.
const _nightFilter = ColorFilter.matrix(<double>[
  -0.17, -0.572, -0.058, 0, 218, //
  -0.17, -0.572, -0.058, 0, 222,
  -0.17, -0.572, -0.058, 0, 240,
  0, 0, 0, 1, 0,
]);

Widget _nightTiles(BuildContext context, Widget tile, TileImage image) =>
    ColorFiltered(colorFilter: _nightFilter, child: tile);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  final _controller = MapController();

  // GPS pipeline: raw fix -> junk filter + Kalman -> snap to road -> animated car.
  final _filter = GpsFilter();
  final _motion = CarMotion();
  final _pose = ValueNotifier<CarPose?>(null); // updated every frame, only the car listens
  final _clock = Stopwatch()..start();
  late final Ticker _ticker;

  LatLng? _here; // smoothed, road-snapped position, updated once per GPS fix
  double _speedMps = 0;
  double _accuracyM = 10; // how far off the position could be (shown as a circle when not navigating)

  final _stats = TripStats(); // arrival summary, on this phone only
  final _jam = JamDetector();
  final _speedWarner = SpeedWarner(); // "slow down" when clearly over a known limit
  Place? _destPlace; // the place the driver searched for, if they did
  bool _askJam = false; // showing the "Jem?" prompt
  Timer? _jamTimer;

  SimulatedDrive? _sim; // a pretend drive is running (testing and demos, no car needed)
  Timer? _simTimer;

  // Live traffic: readings picked while driving, average speeds fetched every minute, and the slow
  // parts of the route ahead worked out from them on every fix.
  final _sampler = SpeedSampler();
  Timer? _trafficTimer;
  List<SlowStretch> _slow = const [];

  double _screenHeight = 800; // logical pixels, remembered from build() for the frame loop
  bool _follow = true;
  bool _movedToFirstFix = false;
  bool _loadedReports = false;
  Timer? _poll;
  Timer? _staleTimer;
  DateTime? _lastFix; // when the last GPS fix arrived
  bool _stale = false; // trip running but no fix for a while

  double get _now => _clock.elapsedMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
    _staleTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final last = _lastFix;
      final stale = ref.read(routingProvider).navigating &&
          last != null &&
          DateTime.now().difference(last) > const Duration(seconds: 8);
      if (stale != _stale && mounted) setState(() => _stale = stale);
    });
    // Pull fresh alerts every 20 s. (Server push can replace this later.)
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      final here = _here;
      if (here != null) ref.read(reportsProvider.notifier).refresh(here);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pose.dispose();
    _poll?.cancel();
    _staleTimer?.cancel();
    _jamTimer?.cancel();
    _simTimer?.cancel();
    _trafficTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  /// True while the map should turn so the road ahead points up.
  bool get _headingUp =>
      ref.read(mapOrientationProvider) == MapOrientation.headingUp &&
      ref.read(routingProvider).navigating;

  void _resetRotation() {
    try {
      if (_controller.camera.rotation != 0) _controller.rotate(0);
    } catch (_) {} // map not ready yet
  }

  /// Runs every frame: glide the car and, when following, keep the camera on it.
  void _onFrame(Duration _) {
    final pose = _motion.tick(_now);
    if (pose == null) return;
    _pose.value = pose;
    if (!_follow) return;
    try {
      final zoom = _controller.camera.zoom;
      if (_headingUp) {
        // Turn the map so our direction of travel is up, and put the car in the lower part of
        // the screen so most of the view shows the road ahead.
        final ahead = metersPerPixel(zoom, pose.position.latitude) * _screenHeight * 0.22;
        _controller.moveAndRotate(
          lookAhead(pose.position, pose.headingDeg, ahead),
          zoom,
          -pose.headingDeg,
        );
      } else {
        _controller.move(pose.position, zoom);
      }
    } catch (_) {} // map not ready yet
  }

  /// A real GPS fix. Ignored while a pretend drive (simulation) is running.
  void _onFix(Position pos) {
    if (_sim != null) return;
    _processFix(GpsFix(
      position: LatLng(pos.latitude, pos.longitude),
      accuracyM: pos.accuracy,
      speedMps: pos.speed,
      headingDeg: pos.heading,
      time: DateTime.now(),
    ));
  }

  /// Pretend to drive the chosen route at [kmh], feeding fake GPS fixes into the very same pipeline.
  void _startSimulation(double kmh) {
    final nav = ref.read(routingProvider);
    final plan = nav.plan;
    if (plan == null || plan.shape.length < 2) return;
    _stopSimulation();
    _filter.reset(); // the first pretend fix starts the track afresh
    ref.read(routingProvider.notifier).begin();
    _sim = SimulatedDrive(
      shape: plan.shape,
      cumulativeM: plan.cumulativeM,
      targetSpeedMps: kmh / 3.6,
      // slow down for turns, exits and roundabouts, like a driver would
      slowPointsM: [
        for (final man in plan.maneuvers)
          if (cueForManeuver(man.type) != null)
            plan.cumulativeM[math.min(man.beginIndex, plan.cumulativeM.length - 1)],
      ],
      noiseM: 3, // a little jitter, so the GPS cleanup gets exercised too
    );
    ref.read(reportsProvider.notifier)
      ..setSimulating(true) // nothing from a pretend drive reaches other drivers
      ..addPracticeAlerts(plan);
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final sim = _sim;
      if (sim == null) return;
      _processFix(sim.step(1.0, DateTime.now()));
      if (sim.finished) _stopSimulation();
    });
    setState(() {});
  }

  void _stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    if (_sim != null) {
      _sim = null;
      ref.read(reportsProvider.notifier).setSimulating(false);
      _filter.reset(); // real GPS may be far from where the pretend drive ended
      if (mounted) setState(() {});
    }
  }

  /// Runs about once a second, for real and pretend fixes alike.
  void _processFix(GpsFix raw) {
    _lastFix = DateTime.now();
    final filtered = _filter.accept(raw);
    if (filtered == null) return; // junk fix, ignore it

    final routing = ref.read(routingProvider.notifier);
    // The heading is only trusted while clearly moving; standing still, GPS heading is noise.
    final heading = filtered.speedMps > 3 ? filtered.headingDeg : null;
    routing.onPosition(filtered.position, headingDeg: heading);
    final snap = routing.snap(filtered.position, headingDeg: heading);
    final at = snap?.point ?? filtered.position;

    // While navigating the car glides along the road itself, so it follows bends between fixes.
    final nav = ref.read(routingProvider);
    final plan = nav.navigating ? nav.plan : null;
    _motion.setRoute(plan?.shape, plan?.cumulativeM);
    _motion.onFix(
      at,
      speedMps: filtered.speedMps,
      headingDeg: snap?.bearingDeg ?? filtered.headingDeg,
      now: _now,
      alongM: snap?.alongM,
    );
    setState(() {
      _here = at;
      _speedMps = filtered.speedMps;
      _accuracyM = filtered.accuracyM;
    });

    ref.read(voiceFeedProvider).onFix(at, speedMps: filtered.speedMps, headingDeg: snap?.bearingDeg ?? heading);
    if (plan != null && snap != null) _trafficOnFix(plan, snap, filtered.speedMps);
    _stats.add(at, filtered.speedMps);
    _maybeAskAboutJam(at, filtered.speedMps);
    _maybeWarnSpeeding(filtered.speedMps);

    if (!_movedToFirstFix) {
      _movedToFirstFix = true;
      if (_follow) _controller.move(at, 17);
    }
    for (final r in ref.read(reportsProvider).reports) {
      if (!r.isExpired && haversineM(at, r.position) < 40) {
        ref.read(votePromptProvider.notifier).maybePrompt(r);
        break;
      }
    }
    if (!_loadedReports) {
      _loadedReports = true;
      ref.read(reportsProvider.notifier).refresh(at);
    }
  }

  /// Live traffic on every fix while driving: share a reading now and then (never during Simulasi,
  /// never when switched off), work out the slow parts ahead, and warn about heavy traffic once.
  void _trafficOnFix(RoutePlan plan, RouteSnap snap, double speedMps) {
    final now = DateTime.now();
    if (_sim == null && ref.read(trafficSharingProvider)) {
      _sampler.add(
        now: now,
        at: snap.point,
        headingDeg: snap.bearingDeg,
        kmh: speedMps * 3.6,
        alongM: snap.alongM,
        remainingM: plan.totalM - snap.alongM,
      );
      final batch = _sampler.takeBatch(now);
      if (batch.isNotEmpty) ref.read(trafficRepositoryProvider).send(batch);
    }
    final limits = ref.read(speedLimitsProvider).valueOrNull;
    _slow = slowStretches(
      plan,
      snap.alongM,
      ref.read(trafficProvider),
      limitAt: limits == null || limits.isEmpty ? null : limits.limitAt,
    );
    for (final st in _slow) {
      final ahead = st.startM - snap.alongM;
      if (st.level == TrafficLevel.heavy && ahead > 50 && ahead < 1500) {
        ref.read(voiceEngineProvider).alert('traffic:${(st.startM / 200).round()}', Cue.jam, ahead);
        break;
      }
    }
  }

  void _startTraffic() {
    _trafficTimer?.cancel();
    void refresh() {
      final here = _here;
      if (here != null) ref.read(trafficProvider.notifier).refresh(here);
    }

    refresh();
    _trafficTimer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }

  void _stopTraffic() {
    _trafficTimer?.cancel();
    _trafficTimer = null;
    _sampler.reset();
    _slow = const [];
    ref.read(trafficProvider.notifier).clear();
  }

  /// The first trip with live traffic says once that speeds are shared, and where to turn it off.
  void _maybeShowTrafficNotice() {
    final prefs = ref.read(sharedPrefsProvider);
    if (!ref.read(trafficSharingProvider) || kDemoMode || (prefs.getBool(_trafficNoticeKey) ?? false)) return;
    prefs.setBool(_trafficNoticeKey, true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: Text(context.s.trafficNotice),
      action: SnackBarAction(label: context.s.ok, onPressed: () {}),
    ));
  }

  static const _trafficNoticeKey = 'traffic.noticeSeen';

  /// Offers a one-tap "Jem Teruk" report after a couple of minutes of crawling.
  void _maybeAskAboutJam(LatLng at, double speedMps) {
    final nav = ref.read(routingProvider);
    final shouldAsk = _jam.update(
      now: DateTime.now(),
      speedMps: speedMps,
      navigating: nav.navigating,
      remainingM: nav.remainingM,
    );
    if (!shouldAsk) return;
    final alreadyReported = ref.read(reportsProvider).reports.any(
          (r) => r.type == ReportType.jam && !r.isExpired && haversineM(at, r.position) < 300,
        );
    if (alreadyReported) return;
    _jamTimer?.cancel();
    setState(() => _askJam = true);
    _jamTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _askJam = false);
    });
  }

  /// Says "slow down" when over a known limit for a few seconds; once per stretch of road.
  /// Works in Simulasi too, because pretend fixes come through here as well.
  void _maybeWarnSpeeding(double speedMps) {
    final limit = ref.read(currentSpeedLimitProvider);
    final warn = _speedWarner.update(
      limitKph: limit,
      speedKph: speedMps * 3.6,
      now: DateTime.now(),
    );
    if (warn && limit != null) ref.read(voiceEngineProvider).speeding(limit);
  }

  void _reportJam() {
    final here = _here;
    _jamTimer?.cancel();
    setState(() => _askJam = false);
    if (here != null) ref.read(reportsProvider.notifier).report(ReportType.jam, here);
  }

  void _showArrival() {
    final summary = _stats.summary(DateTime.now());
    final place = _destPlace;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showArrivalSheet(context, ref: ref, summary: summary, place: place).whenComplete(() {
        if (mounted) ref.read(routingProvider.notifier).cancel(); // back to the search bar
      });
    });
  }

  void _pickDestination(LatLng point, {Place? place}) {
    _destPlace = place;
    final raw = ref.read(locationProvider).valueOrNull;
    final from = _here ?? (raw == null ? null : LatLng(raw.latitude, raw.longitude));
    if (from == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s.waitForGps)),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    ref.read(routingProvider.notifier).start(from, point);
  }

  void _recenter(LatLng here) {
    setState(() => _follow = true);
    _controller.move(here, 17);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(voiceEngineProvider); // starts the voice engine (it listens on its own)

    ref.listen(locationProvider, (_, next) => next.whenData(_onFix));

    ref.listen(reportsProvider.select((s) => s.toast), (_, toast) {
      if (toast == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
      ref.read(reportsProvider.notifier).clearToast();
    });

    // Keep the screen on only while a trip is in progress.
    ref.listen(routingProvider.select((s) => s.navigating), (_, active) {
      WakelockPlus.toggle(enable: active);
      if (active) {
        _startTraffic();
        _maybeShowTrafficNotice();
      }
      if (!active) {
        _stopTraffic();
        _resetRotation(); // trip over: back to north-up
        _stopSimulation();
        _speedWarner.reset();
      }
    });

    // Show every route option when a brand-new plan arrives (not on rerouting or choosing).
    ref.listen(routingProvider.select((s) => s.plan), (prev, next) {
      if (next == null || prev != null) return;
      _follow = false; // build() re-runs because it watches routingProvider
      final all = ref.read(routingProvider).candidates;
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([
            for (final c in (all.isEmpty ? [next] : all)) ...c.shape,
          ]),
          padding: const EdgeInsets.fromLTRB(32, 230, 32, 170),
        ),
      );
    });

    // Arrived: show how the trip went.
    ref.listen(routingProvider.select((s) => s.arrived), (prev, now) {
      if (now && prev != true) _showArrival();
    });

    // "Jom!" pressed: start counting the trip and switch to following the car.
    ref.listen(routingProvider.select((s) => s.previewing), (prev, now) {
      if (prev == true && !now) {
        _stats.begin(DateTime.now());
        _jam.reset();
      }
      final here = _here;
      if (prev == true && !now && here != null) {
        _follow = true;
        _controller.move(here, 17);
      }
    });

    final here = _here;
    final nav = ref.watch(routingProvider);
    final reports = ref
        .watch(reportsProvider.select((s) => s.reports))
        .where((r) => !r.isExpired);

    _screenHeight = MediaQuery.sizeOf(context).height;
    // Markers keep standing upright while the map turns underneath them.
    final turned = ref.watch(mapOrientationProvider) == MapOrientation.headingUp &&
        nav.navigating &&
        _follow;

    final limit = ref.watch(currentSpeedLimitProvider); // null where the map does not know it
    final kmh = _speedMps * 3.6;

    // Where the floating controls sit: just above the trip bar while driving, near the bottom
    // otherwise. The phone's own top and bottom bars are kept clear.
    final choosing = nav.previewing;
    final driving = nav.navigating;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final base = driving ? TripBar.height + bottomInset + 16 : bottomInset + 28;

    final nightMode = ref.watch(nightModeProvider);
    final night = nightMode == NightMode.always ||
        (nightMode == NightMode.auto &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      resizeToAvoidBottomInset: false, // the keyboard should float over the map
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: LatLng(3.1390, 101.6869), // KL
              initialZoom: 15,
              // Two-finger twisting is too easy to do by accident; keep the map north-up.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onLongPress: (tapPosition, point) => _pickDestination(point),
              onTap: (tapPosition, point) {
                FocusManager.instance.primaryFocus?.unfocus();
                ref.read(searchProvider.notifier).clear();
              },
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _follow) {
                  setState(() => _follow = false);
                  _resetRotation(); // browsing the map: north-up again
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'my.jomlah',
                tileBuilder: night ? _nightTiles : null,
              ),
              // Choosing a route: every option, the chosen one on top in blue.
              if (nav.plan != null && nav.previewing)
                PolylineLayer(
                  polylines: [
                    for (var i = 0; i < nav.candidates.length; i++)
                      if (i != nav.selected)
                        Polyline(
                          points: nav.candidates[i].shape,
                          strokeWidth: 6,
                          color: AppColors.routeOption,
                          borderStrokeWidth: 2,
                          borderColor: AppColors.routeBorder,
                        ),
                    _routeLine(nav.plan!.shape),
                  ],
                ),
              // Driving: only the road still ahead, starting exactly at the car. Redrawn every frame
              // with the gliding car, so no stretch of line is left behind it between GPS fixes.
              if (nav.plan != null && !nav.previewing)
                ValueListenableBuilder<CarPose?>(
                  valueListenable: _pose,
                  builder: (context, pose, _) {
                    final plan = nav.plan!;
                    final along = pose?.alongM;
                    final points = (pose != null && along != null && identical(_motion.route, plan.shape))
                        ? remainingFromDistance(plan, along, from: pose.position)
                        : remainingShape(plan.shape, nav.segment, from: pose?.position ?? here);
                    // Slow parts ahead, painted over the blue line (never behind the car).
                    final from = along ?? (plan.totalM - nav.remainingM);
                    final traffic = [
                      for (final st in _slow)
                        if (st.endM > from)
                          Polyline(
                            points: shapeBetween(plan, math.max(st.startM, from), st.endM),
                            strokeWidth: 8,
                            color: st.level == TrafficLevel.heavy ? AppColors.danger : AppColors.warning,
                          ),
                    ];
                    return PolylineLayer(
                      polylines: [if (points.length >= 2) _routeLine(points), ...traffic],
                    );
                  },
                ),
              MarkerLayer(
                markers: [
                  for (final r in reports)
                    Marker(
                      point: r.position,
                      width: 48,
                      height: 48,
                      rotate: turned,
                      child: GestureDetector(
                        onTap: () => ref.read(votePromptProvider.notifier).show(r),
                        child: ReportPin(report: r),
                      ),
                    ),
                  if (nav.destination != null)
                    Marker(
                      point: nav.destination!,
                      width: 48,
                      height: 48,
                      rotate: turned,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        size: 48,
                        color: AppColors.destination,
                        shadows: [Shadow(color: Color(0x66000000), blurRadius: 6)],
                      ),
                    ),
                ],
              ),
              // How sure the GPS is, like other map apps. Only when browsing; while driving the car
              // sits on the road and the circle would just get in the way.
              if (!nav.navigating)
                ValueListenableBuilder<CarPose?>(
                  valueListenable: _pose,
                  builder: (context, pose, _) => CircleLayer(
                    circles: [
                      if (pose != null)
                        CircleMarker(
                          point: pose.position,
                          radius: _accuracyM,
                          useRadiusInMeter: true,
                          color: const Color(0x2633A1FF),
                          borderColor: const Color(0x6633A1FF),
                          borderStrokeWidth: 1,
                        ),
                    ],
                  ),
                ),
              // The car has its own layer so only it redraws on every frame.
              ValueListenableBuilder<CarPose?>(
                valueListenable: _pose,
                builder: (context, pose, _) => MarkerLayer(
                  markers: [
                    if (pose != null)
                      Marker(
                        point: pose.position,
                        width: 72,
                        height: 72,
                        rotate: turned,
                        child: CarMarker(
                          headingDeg: turned ? 0 : pose.headingDeg,
                          braking: pose.braking,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Top: search (with settings), or the route back-bar / turn card, plus banners and prompts.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (nav.destination == null)
                      SearchBox(
                        onPick: (place) => _pickDestination(place.position, place: place),
                        trailing: const SettingsButton(),
                      )
                    else
                      NavTopArea(placeName: _destPlace?.name),
                    const LocationBanner(),
                    if (_stale) const StaleGpsBanner(),
                    const Padding(padding: EdgeInsets.only(top: 8), child: VotePrompt()),
                    if (_askJam)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _JamPrompt(
                          onReport: _reportJam,
                          onDismiss: () {
                            _jamTimer?.cancel();
                            setState(() => _askJam = false);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom: route choices before Jom!, the trip bar while driving.
          if (nav.destination != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: NavBottomArea(onReport: _openReportSheet, onSimulate: _startSimulation),
            ),
          // Map credit, required by OpenStreetMap: kept clear of the panels and buttons.
          Positioned(
            left: 0,
            right: 0,
            top: choosing ? topInset + 8 + 52 + 6 : null,
            bottom: choosing ? null : (driving ? TripBar.height + bottomInset + 2 : bottomInset + 4),
            child: const Center(child: _OsmCredit()),
          ),
          // Floating controls (hidden while choosing a route; the panel needs the room).
          if (!choosing && here != null)
            Positioned(
              left: 16,
              bottom: base,
              child: SpeedCard(kmh: kmh, over: _speedWarner.isOver(limit, kmh)),
            ),
          if (!choosing && limit != null)
            Positioned(left: 92, bottom: base + 4, child: SpeedLimitSign(kph: limit)),
          if (!choosing && _sim != null)
            Positioned(left: 16, bottom: base + 80, child: const _SimPill()),
          if (!choosing && !driving)
            Positioned(right: 16, bottom: base, child: ReportButton(onPressed: _openReportSheet)),
          if (driving)
            Positioned(right: 16, bottom: base, child: const SettingsButton(glass: true)),
          if (!choosing && !_follow && here != null)
            Positioned(
              right: driving ? 16 : 22,
              bottom: driving ? base + 64 : base + 76,
              child: driving
                  ? _BackToCarButton(onPressed: () => _recenter(here))
                  : MapButton(
                      icon: Icons.my_location_rounded,
                      onPressed: () => _recenter(here),
                      tooltip: context.s.myLocation,
                    ),
            ),
        ],
      ),
    );
  }

  /// The orange button: pick what you see, and it is reported where you are.
  void _openReportSheet() {
    if (_here == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s.waitForGps)),
      );
      return;
    }
    showReportSheet(context, onPick: (type) {
      final at = _here;
      if (at == null || ref.read(reportsProvider).submitting) return;
      HapticFeedback.mediumImpact();
      ref.read(reportsProvider.notifier).report(type, at);
    });
  }
}

/// The route line: bright blue with a dark navy edge, so it reads on light and dark maps.
Polyline _routeLine(List<LatLng> points) => Polyline(
      points: points,
      strokeWidth: 8,
      color: AppColors.route,
      borderStrokeWidth: 2.5,
      borderColor: AppColors.routeBorder,
    );

class _JamPrompt extends StatelessWidget {
  const _JamPrompt({required this.onReport, required this.onDismiss});
  final VoidCallback onReport;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.overlay,
        elevation: 6,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const ReportBadge(type: ReportType.jam, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.s.jamQuestion(context.s.reportLabel(ReportType.jam)),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(72, 56)),
                onPressed: onReport,
                child: Text(context.s.report),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(72, 56)),
                onPressed: onDismiss,
                child: Text(context.s.no),
              ),
            ],
          ),
        ),
      );
}

class _SimPill extends StatelessWidget {
  const _SimPill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.overlay,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cyan, width: 1.5),
        ),
        child: Text(
          '🧪 ${context.s.simulate}',
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.cyan),
        ),
      );
}

/// "Kembali": follow the car again, while driving.
class _BackToCarButton extends StatelessWidget {
  const _BackToCarButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.primaryDeep,
        elevation: 8,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(context.s.backToCar, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

/// Credit for the map data, required by OpenStreetMap's licence.
class _OsmCredit extends StatelessWidget {
  const _OsmCredit();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: const Color(0xB3FFFFFF), borderRadius: BorderRadius.circular(4)),
        child: const Text(
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 10, color: Color(0xFF3A4566), fontWeight: FontWeight.w600),
        ),
      );
}
