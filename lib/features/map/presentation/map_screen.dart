import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _MapScreenState extends ConsumerState<MapScreen> {
  final _controller = MapController();
  bool _follow = true;
  bool _loadedReports = false;
  Timer? _poll;
  Timer? _staleTimer;
  DateTime? _lastFix; // when the last GPS fix arrived
  bool _stale = false; // trip running but no fix for a while
  double _heading = 0; // last trustworthy direction of travel (GPS heading is junk when slow)

  @override
  void initState() {
    super.initState();
    _staleTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final last = _lastFix;
      final stale = ref.read(routingProvider).navigating &&
          last != null &&
          DateTime.now().difference(last) > const Duration(seconds: 8);
      if (stale != _stale && mounted) setState(() => _stale = stale);
    });
    // Pull fresh alerts every 20 s. (Server push can replace this later.)
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      final pos = ref.read(locationProvider).valueOrNull;
      if (pos != null) {
        ref.read(reportsProvider.notifier).refresh(LatLng(pos.latitude, pos.longitude));
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _staleTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _pickDestination(LatLng point) {
    final pos = ref.read(locationProvider).valueOrNull;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tunggu GPS dapat lokasi dulu.')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    ref
        .read(routingProvider.notifier)
        .start(LatLng(pos.latitude, pos.longitude), point);
  }

  void _recenter(LatLng here) {
    setState(() => _follow = true);
    _controller.move(here, 17);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(voiceEngineProvider); // starts the voice engine (it listens on its own)

    ref.listen(locationProvider, (_, next) {
      next.whenData((pos) {
        final here = LatLng(pos.latitude, pos.longitude);
        _lastFix = DateTime.now();
        if (pos.heading >= 0 && pos.speed > 1.0) _heading = pos.heading;
        if (_follow) _controller.move(here, 17);
        ref.read(routingProvider.notifier).onPosition(here);
        for (final r in ref.read(reportsProvider).reports) {
          if (!r.isExpired && haversineM(here, r.position) < 40) {
            ref.read(votePromptProvider.notifier).maybePrompt(r);
            break;
          }
        }
        if (!_loadedReports) {
          _loadedReports = true;
          ref.read(reportsProvider.notifier).refresh(here);
        }
      });
    });

    ref.listen(reportsProvider.select((s) => s.toast), (_, toast) {
      if (toast == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
      ref.read(reportsProvider.notifier).clearToast();
    });

    // Keep the screen on only while a trip is in progress.
    ref.listen(routingProvider.select((s) => s.navigating), (_, active) {
      WakelockPlus.toggle(enable: active);
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
      if (prev == true && !now) {
        final pos = ref.read(locationProvider).valueOrNull;
        if (pos != null) {
          _follow = true;
          _controller.move(LatLng(pos.latitude, pos.longitude), 17);
        }
      }
    });

    final pos = ref.watch(locationProvider).valueOrNull;
    final here = pos == null ? null : LatLng(pos.latitude, pos.longitude);
    final nav = ref.watch(routingProvider);
    final reports = ref
        .watch(reportsProvider.select((s) => s.reports))
        .where((r) => !r.isExpired);

    final nightMode = ref.watch(nightModeProvider);
    final night = nightMode == NightMode.always ||
        (nightMode == NightMode.auto &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final kmh = pos == null ? 0.0 : (pos.speed < 0 ? 0.0 : pos.speed) * 3.6;

    return Scaffold(
      resizeToAvoidBottomInset: false, // the keyboard should float over the map
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: LatLng(3.1390, 101.6869), // KL
              initialZoom: 15,
              onLongPress: (tapPosition, point) => _pickDestination(point),
              onTap: (tapPosition, point) {
                FocusManager.instance.primaryFocus?.unfocus();
                ref.read(searchProvider.notifier).clear();
              },
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _follow) setState(() => _follow = false);
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
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        size: 48,
                        color: Color(0xFFFF4F8B),
                      ),
                    ),
                  if (here != null)
                    Marker(
                      point: here,
                      width: 72,
                      height: 72,
                      child: HatchAvatar(headingDeg: _heading),
                    ),
                ],
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
          if (pos != null)
            Positioned(left: 16, bottom: 196, child: _SpeedBubble(kmh: kmh)),
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
