import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/geo.dart';
import '../../routing/application/routing_providers.dart';
import '../../routing/domain/route_plan.dart';
import '../../routing/presentation/nav_banner.dart';
import '../../search/application/search_providers.dart';
import '../../search/presentation/search_box.dart';
import '../../settings/presentation/settings_button.dart';
import '../../voice/application/voice_providers.dart';
import '../application/map_style_provider.dart';
import '../application/providers.dart';
import '../domain/car_motion.dart';
import '../domain/gps_filter.dart';
import 'location_banner.dart';
import 'vote_prompt.dart';
import 'widgets.dart';

const _tileUrl = String.fromEnvironment(
  'TILE_URL',
  // Dev only. OSM public tiles are not for production traffic. Self-host and build with:
  // flutter build apk --dart-define=TILE_URL=https://tiles.yourdomain.my/{z}/{x}/{y}.png
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

const _lime = Color(0xFFC8FF3D);
const _midnight = Color(0xFF0E1224);

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

  /// Runs about once a second when a GPS fix arrives.
  void _onFix(Position pos) {
    _lastFix = DateTime.now();
    final filtered = _filter.accept(GpsFix(
      position: LatLng(pos.latitude, pos.longitude),
      accuracyM: pos.accuracy,
      speedMps: pos.speed,
      headingDeg: pos.heading,
      time: DateTime.now(),
    ));
    if (filtered == null) return; // junk fix, ignore it

    final routing = ref.read(routingProvider.notifier);
    routing.onPosition(filtered.position);
    final snap = routing.snap(filtered.position);
    final at = snap?.point ?? filtered.position;

    _motion.onFix(
      at,
      speedMps: filtered.speedMps,
      headingDeg: snap?.bearingDeg ?? filtered.headingDeg,
      now: _now,
    );
    setState(() {
      _here = at;
      _speedMps = filtered.speedMps;
    });

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

  void _pickDestination(LatLng point) {
    final raw = ref.read(locationProvider).valueOrNull;
    final from = _here ?? (raw == null ? null : LatLng(raw.latitude, raw.longitude));
    if (from == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tunggu GPS dapat lokasi dulu.')),
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
      if (!active) _resetRotation(); // trip over: back to north-up
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

    // "Jom!" pressed: switch to following the car.
    ref.listen(routingProvider.select((s) => s.previewing), (prev, now) {
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
              if (nav.plan != null)
                PolylineLayer(
                  polylines: [
                    if (nav.previewing)
                      for (var i = 0; i < nav.candidates.length; i++)
                        if (i != nav.selected)
                          Polyline(
                            points: nav.candidates[i].shape,
                            strokeWidth: 6,
                            color: const Color(0xFF8A90B0),
                            borderStrokeWidth: 2,
                            borderColor: _midnight,
                          ),
                    Polyline(
                      // While driving, only draw what is still ahead, starting at the car.
                      points: nav.previewing
                          ? nav.plan!.shape
                          : remainingShape(nav.plan!.shape, nav.segment, from: here),
                      strokeWidth: 8,
                      color: _lime,
                      borderStrokeWidth: 3,
                      borderColor: _midnight,
                    ),
                  ],
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
                        color: Color(0xFFFF4F8B),
                      ),
                    ),
                ],
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
                        child: HatchAvatar(headingDeg: turned ? 0 : pose.headingDeg),
                      ),
                  ],
                ),
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search until a destination is chosen, then route options or turn-by-turn.
                    if (nav.destination == null)
                      SearchBox(onPick: (place) => _pickDestination(place.position))
                    else
                      const NavBanner(),
                    const LocationBanner(),
                    if (_stale) const StaleGpsBanner(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: ReportBar(at: here)),
          const Positioned(left: 12, right: 12, bottom: 210, child: VotePrompt()),
          const Positioned(left: 16, bottom: 140, child: SettingsButton()),
          if (here != null)
            Positioned(left: 16, bottom: 196, child: _SpeedBubble(kmh: _speedMps * 3.6)),
          if (!_follow && here != null)
            Positioned(
              right: 16,
              bottom: 140,
              child: nav.navigating
                  ? FloatingActionButton.extended(
                      heroTag: 'recenter',
                      onPressed: () => _recenter(here),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Kembali'),
                    )
                  : FloatingActionButton.small(
                      heroTag: 'recenter',
                      onPressed: () => _recenter(here),
                      child: const Icon(Icons.my_location),
                    ),
            ),
        ],
      ),
    );
  }
}

class _SpeedBubble extends StatelessWidget {
  const _SpeedBubble({required this.kmh});
  final double kmh;

  @override
  Widget build(BuildContext context) => Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xF2171C36),
          shape: BoxShape.circle,
          border: Border.all(color: _lime, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kmh.round().toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1),
            ),
            const Text('km/j', style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
      );
}
