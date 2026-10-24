import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../application/routing_providers.dart';

const _lime = Color(0xFFC8FF3D);

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

String formatDistance(double m) =>
    m < 1000 ? '${(m / 10).round() * 10} m' : '${(m / 1000).toStringAsFixed(1)} km';

class NavBanner extends ConsumerWidget {
  const NavBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(routingProvider);
    final cancel = ref.read(routingProvider.notifier).cancel;

    if (nav.destination == null) return const SizedBox.shrink();
    if (nav.loading) {
      return _Card(
        onClose: cancel,
        child: const Row(children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Mencari laluan…'),
        ]),
      );
    }
    if (nav.error != null) {
      return _Card(onClose: cancel, child: Text(nav.error!));
    }
    if (nav.arrived) {
      return _Card(onClose: cancel, child: const Text('Sampai! 🎉 Terima kasih sebab Jomlah.'));
    }

    if (nav.previewing) {
      final notifier = ref.read(routingProvider.notifier);
      var fastest = 0;
      for (var i = 1; i < nav.candidates.length; i++) {
        if (nav.candidates[i].durationSec < nav.candidates[fastest].durationSec) fastest = i;
      }
      return _Card(
        onClose: cancel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih laluan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < nav.candidates.length; i++)
                  ChoiceChip(
                    selected: i == nav.selected,
                    onSelected: (_) => notifier.choose(i),
                    label: Text(
                      '${nav.candidates.length > 1 && i == fastest ? 'Terpantas · ' : ''}'
                      '${(nav.candidates[i].durationSec / 60).ceil()} min · '
                      '${nav.candidates[i].distanceKm.toStringAsFixed(1)} km',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () async {
                  // Android 13+ hides the "navigation active" notice unless allowed.
                  try {
                    await Permission.notification.request();
                  } catch (_) {}
                  notifier.begin();
                },
                icon: const Icon(Icons.navigation),
                label: const Text('Jom!', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      );
    }

    final plan = nav.plan!;
    final next = nav.next!;
    final etaMin = plan.totalM == 0
        ? 0
        : (plan.durationSec * (nav.remainingM / plan.totalM) / 60).ceil();

    return _Card(
      onClose: cancel,
      child: Row(
        children: [
          Icon(maneuverIcon(next.type), size: 44, color: _lime),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatDistance(nav.distanceToNextM),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                Text(next.instruction, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  nav.rerouting
                      ? 'Mengira semula…'
                      : 'Tinggal ${formatDistance(nav.remainingM)} · $etaMin min',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onClose});
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xF2171C36),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(child: child),
              if (onClose != null)
                IconButton(onPressed: onClose, icon: const Icon(Icons.close), tooltip: 'Batal'),
            ],
          ),
        ),
      );
}
