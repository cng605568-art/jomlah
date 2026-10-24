import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/geo.dart';
import '../../routing/application/routing_providers.dart';
import '../../routing/presentation/nav_banner.dart';
import '../../search/application/search_providers.dart';
import '../../search/presentation/search_box.dart';
import '../../voice/application/voice_providers.dart';
import '../../voice/presentation/voice_button.dart';
import '../application/providers.dart';
import 'vote_prompt.dart';
import 'widgets.dart';

const _tileUrl = String.fromEnvironment(
  'TILE_URL',
  // Dev only. OSM public tiles are not for production traffic. Self-host and build with:
  // flutter build apk --dart-define=TILE_URL=https://tiles.yourdomain.my/{z}/{x}/{y}.png
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

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

  @override
  void initState() {
    super.initState();
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
    ref.listen(locationProvider, (_, next) {
      next.whenData((pos) {
        final here = LatLng(pos.latitude, pos.longitude);
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

    // Show the whole route when a brand-new one arrives (not on automatic reroutes).
    ref.listen(routingProvider.select((s) => s.plan), (prev, next) {
      if (next == null || prev != null) return;
      _follow = false; // build() re-runs because it watches routingProvider
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(next.shape),
          padding: const EdgeInsets.fromLTRB(32, 150, 32, 170),
        ),
      );
    });

    ref.watch(voiceEngineProvider); // starts the voice engine (it listens on its own)

    final pos = ref.watch(locationProvider).valueOrNull;
    final here = pos == null ? null : LatLng(pos.latitude, pos.longitude);
    final nav = ref.watch(routingProvider);
    final reports = ref
        .watch(reportsProvider.select((s) => s.reports))
        .where((r) => !r.isExpired);

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
              ),
              if (nav.plan != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: nav.plan!.shape,
                      strokeWidth: 8,
                      color: const Color(0xFFC8FF3D),
                      borderStrokeWidth: 3,
                      borderColor: const Color(0xFF0E1224),
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
                      child: HatchAvatar(headingDeg: pos!.heading),
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
                // Search until a destination is chosen, then the turn-by-turn card.
                child: nav.destination == null
                    ? SearchBox(onPick: (place) => _pickDestination(place.position))
                    : const NavBanner(),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: ReportBar(at: here)),
          const Positioned(left: 12, right: 12, bottom: 210, child: VotePrompt()),
          const Positioned(left: 16, bottom: 140, child: VoiceButton()),
          if (!_follow && here != null)
            Positioned(
              right: 16,
              bottom: 140,
              child: nav.plan != null
                  ? FloatingActionButton.extended(
                      onPressed: () => _recenter(here),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Jom!'),
                    )
                  : FloatingActionButton.small(
                      onPressed: () => _recenter(here),
                      child: const Icon(Icons.my_location),
                    ),
            ),
        ],
      ),
    );
  }
}
