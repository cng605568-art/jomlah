import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/l10n/language.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/prefs.dart';
import '../data/valhalla_client.dart';
import '../application/routing_providers.dart';
import '../application/speed_limit_providers.dart';
import '../domain/lanes.dart';
import '../domain/route_plan.dart';
import '../../map/presentation/overlays.dart';

/// Valhalla maneuver type -> icon. Full list: Valhalla docs, "maneuver types".
IconData maneuverIcon(int type) {
  switch (type) {
    case 4:
    case 5:
    case 6:
      return Icons.flag;
    case 9:
      return Icons.turn_slight_right;
    case 10:
      return Icons.turn_right;
    case 11:
      return Icons.turn_sharp_right;
    case 12:
      return Icons.u_turn_right;
    case 13:
      return Icons.u_turn_left;
    case 14:
      return Icons.turn_sharp_left;
    case 15:
      return Icons.turn_left;
    case 16:
      return Icons.turn_slight_left;
    case 18:
    case 20:
    case 23:
      return Icons.fork_right;
    case 19:
    case 21:
    case 24:
      return Icons.fork_left;
    case 25:
      return Icons.merge;
    case 26:
    case 27:
      return Icons.roundabout_right;
    default:
      return Icons.straight;
  }
}

/// A painted lane arrow (OSRM word) -> icon. Malaysia drives on the left, so U-turns go right.
IconData laneIcon(String arrow) {
  switch (arrow) {
    case 'left':
      return Icons.turn_left;
    case 'slight left':
      return Icons.turn_slight_left;
    case 'sharp left':
      return Icons.turn_sharp_left;
    case 'right':
      return Icons.turn_right;
    case 'slight right':
      return Icons.turn_slight_right;
    case 'sharp right':
      return Icons.turn_sharp_right;
    case 'uturn':
      return Icons.u_turn_right;
    default: // "straight", or "none" (no arrow painted: usually straight on)
      return Icons.straight;
  }
}

/// Lanes as the turn card draws them.
List<LaneArrow> laneArrows(List<Lane> lanes) => [
      for (final l in lanes)
        LaneArrow(
          laneIcon(l.shown),
          switch (l.use) {
            LaneUse.best => LaneLook.best,
            LaneUse.ok => LaneLook.ok,
            LaneUse.no => LaneLook.off,
          },
        ),
    ];

String formatDistance(double m) =>
    m < 1000 ? '${(m / 10).round() * 10} m' : '${(m / 1000).toStringAsFixed(1)} km';

/// What the exit sign says, as one line: "Keluar 205 · SUKE · ke Putrajaya / Cyberjaya".
String? signText(ExitSign? sign, [AppStrings s = const AppStrings(AppLanguage.ms)]) {
  if (sign == null || sign.isEmpty) return null;
  final parts = [
    if (sign.numberText != null) s.exitNumber(sign.numberText!),
    if (sign.branchText != null) sign.branchText!,
    if (sign.towardText != null) s.towards(sign.towardText!),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// What to say when no route could be planned.
String routeErrorText(RouteError e, AppStrings s) => switch (e) {
      RouteError.noConnection => s.routeNoConnection,
      RouteError.notFound => s.routeNotFound,
      RouteError.problem => s.routeProblem,
    };

/// Minutes left, scaled from the route's own estimate by the distance still to go.
int minutesLeft(NavState nav) {
  final plan = nav.plan;
  if (plan == null || plan.totalM == 0) return 0;
  return (plan.durationSec * (nav.remainingM / plan.totalM) / 60).ceil();
}

/// Top of the screen once a destination is picked: searching, errors, the back bar while choosing
/// a route, and the blue turn card while driving.
class NavTopArea extends ConsumerWidget {
  const NavTopArea({super.key, this.placeName});

  /// The searched place's name, if the destination came from search.
  final String? placeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(routingProvider);
    final cancel = ref.read(routingProvider.notifier).cancel;
    final s = context.s;

    if (nav.destination == null) return const SizedBox.shrink();
    if (nav.loading) {
      return StatusCard(
        onClose: cancel,
        child: Row(children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(s.findingRoute),
        ]),
      );
    }
    if (nav.error != null) return StatusCard(onClose: cancel, child: Text(routeErrorText(nav.error!, s)));
    if (nav.arrived) {
      return StatusCard(onClose: cancel, child: Text(s.arrivedThanks));
    }
    if (nav.previewing) {
      return TopBackBar(title: placeName ?? s.chosenDestination, onBack: cancel);
    }

    final next = nav.next;
    if (next == null) return const SizedBox.shrink();
    // A road without a name gets the turn itself as its title ("Belok kiri"), in the app's language.
    final street = next.streetNames.isEmpty ? s.maneuver(next.type) : next.streetNames.first;
    final lanes = ref.watch(nextTurnLanesProvider);
    return TurnCard(
      icon: maneuverIcon(next.type),
      distance: formatDistance(nav.distanceToNextM),
      title: street,
      sign: signText(next.sign, s),
      status: nav.rerouting ? s.recalculating : null,
      lanes: lanes == null || nav.rerouting ? null : laneArrows(lanes),
    );
  }
}

/// Where the last Simulasi speed is remembered, so the menu highlights it next time.
const kSimSpeedKey = 'sim.kmh';

/// Bottom of the screen once a destination is picked: route choices before "Jom!", the trip bar
/// while driving, nothing otherwise.
class NavBottomArea extends ConsumerWidget {
  const NavBottomArea({super.key, required this.onReport, this.onSimulate, this.onVoice});

  final VoidCallback onReport;

  /// When set, the trip bar has a microphone for voice reports.
  final VoidCallback? onVoice;

  /// When set, the route choice offers a pretend drive at the chosen speed in km/h.
  final void Function(double kmh)? onSimulate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(routingProvider);
    final notifier = ref.read(routingProvider.notifier);
    final s = context.s;

    if (nav.previewing && nav.candidates.isNotEmpty) {
      var fastest = 0;
      for (var i = 1; i < nav.candidates.length; i++) {
        if (nav.candidates[i].durationSec < nav.candidates[fastest].durationSec) fastest = i;
      }
      return RouteOptionsPanel(
        options: [
          for (var i = 0; i < nav.candidates.length; i++)
            RouteOption(
              minutes: (nav.candidates[i].durationSec / 60).ceil(),
              km: nav.candidates[i].distanceKm,
              fastest: nav.candidates.length > 1 && i == fastest,
              toll: nav.candidates[i].hasToll,
            ),
        ],
        selected: nav.selected,
        onSelect: notifier.choose,
        onGo: () async {
          // Android 13+ hides the "navigation active" notice unless allowed.
          try {
            await Permission.notification.request();
          } catch (_) {}
          notifier.begin();
        },
        simulate: onSimulate == null
            ? null
            : PopupMenuButton<double>(
                tooltip: s.simulatedDrive,
                initialValue: ref.read(sharedPrefsProvider).getDouble(kSimSpeedKey), // last speed used
                onSelected: (kmh) {
                  ref.read(sharedPrefsProvider).setDouble(kSimSpeedKey, kmh);
                  onSimulate!(kmh);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 30.0, child: Text('30 ${s.kmh} (${s.city})')),
                  PopupMenuItem(value: 60.0, child: Text('60 ${s.kmh}')),
                  PopupMenuItem(value: 90.0, child: Text('90 ${s.kmh} (${s.highway})')),
                  PopupMenuItem(value: 8.0, child: Text('8 ${s.kmh} (${s.jam})')),
                ],
                child: const SimulateButtonFace(),
              ),
      );
    }

    if (nav.navigating) {
      final minutes = minutesLeft(nav);
      final arrive = formatClock(DateTime.now().add(Duration(minutes: minutes)));
      return TripBar(
        minutes: minutes,
        detail: nav.rerouting ? s.recalculating : '${formatDistance(nav.remainingM)} · ${s.arriveAt(arrive)}',
        onReport: onReport,
        onVoice: onVoice,
        onEnd: notifier.cancel,
      );
    }
    return const SizedBox.shrink();
  }
}
