import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/l10n/language.dart';
import '../domain/report.dart';

// The pieces that float over the map. They take plain values and callbacks (no providers), so the
// map screen decides what to show and tests can draw them on their own.

const _glassShadow = [BoxShadow(color: Color(0x47000000), blurRadius: 24, offset: Offset(0, 8))];

/// Dark navy "glass" used by every floating control, so they all look like one family.
BoxDecoration glassDecoration({double radius = 20, bool shadow = true}) => BoxDecoration(
      color: AppColors.overlay,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.outline),
      boxShadow: shadow ? _glassShadow : null,
    );

/// A rounded button face with a tap ripple. The shadow is drawn outside the Material, because
/// Ink is clipped to the Material's square box and a shadow drawn there gets cut off at the edges.
class _TapFace extends StatelessWidget {
  const _TapFace({required this.face, required this.radius, required this.onTap, required this.child, this.shadows});

  final BoxDecoration face;
  final double radius;
  final List<BoxShadow>? shadows;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: shadows),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: face,
            child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: child),
          ),
        ),
      );
}

/// Rounded square button floating over the map: re-centre, settings, back.
class MapButton extends StatelessWidget {
  const MapButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 52,
    this.color = AppColors.sky,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: _TapFace(
          face: glassDecoration(radius: 18, shadow: false),
          radius: 18,
          shadows: _glassShadow,
          onTap: onPressed,
          child: SizedBox(width: size, height: size, child: Icon(icon, color: color)),
        ),
      );
}

/// The orange report button. Opens the grid of things to report.
class ReportButton extends StatelessWidget {
  const ReportButton({super.key, required this.onPressed, this.size = 64, this.radius = 22, this.glow = true});

  final VoidCallback onPressed;
  final double size;
  final double radius;
  final bool glow;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: context.s.report,
        child: _TapFace(
          face: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.reportLight, AppColors.report],
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
          radius: radius,
          shadows: glow ? const [BoxShadow(color: Color(0x73F97316), blurRadius: 24, offset: Offset(0, 10))] : null,
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: size * 0.47),
          ),
        ),
      );
}

/// Current speed. Turns red when over the limit.
class SpeedCard extends StatelessWidget {
  const SpeedCard({super.key, required this.kmh, this.over = false});
  final double kmh;
  final bool over;

  @override
  Widget build(BuildContext context) => Container(
        width: 68,
        height: 68,
        decoration: over
            ? BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6))],
              )
            : glassDecoration(radius: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              kmh.round().toString(),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1),
            ),
            Text(
              context.s.kmh,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: over ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
}

/// Speed limit sign like the ones on Malaysian roads: red ring, white face, black number.
class SpeedLimitSign extends StatelessWidget {
  const SpeedLimitSign({super.key, required this.kph});
  final int kph;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.s.speedLimit(kph),
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD7182A), width: 6),
            boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Text(
            '$kph',
            style: TextStyle(
              color: Colors.black,
              fontSize: kph >= 100 ? 18 : 22,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      );
}

/// How each kind of report looks: an icon in a coloured circle.
extension ReportTypeLook on ReportType {
  IconData get icon => switch (this) {
        ReportType.police => Icons.local_police,
        ReportType.camera => Icons.photo_camera,
        ReportType.flood => Icons.flood,
        ReportType.pothole => Icons.warning_amber,
        ReportType.brokenLorry => Icons.local_shipping,
        ReportType.jam => Icons.traffic,
        ReportType.crash => Icons.car_crash,
      };

  Color get color => switch (this) {
        ReportType.police => const Color(0xFF2563EB),
        ReportType.camera => const Color(0xFF7C3AED),
        ReportType.flood => const Color(0xFF0891B2),
        ReportType.pothole => const Color(0xFFD97706),
        ReportType.brokenLorry => const Color(0xFFEA580C),
        ReportType.jam => const Color(0xFFDC2626),
        ReportType.crash => const Color(0xFFE11D48),
      };
}

/// Round coloured badge with the report's icon (grid tiles, map pins, the "Masih ada?" card).
class ReportBadge extends StatelessWidget {
  const ReportBadge({super.key, required this.type, this.size = 46});
  final ReportType type;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
        child: Icon(type.icon, color: Colors.white, size: size * 0.52),
      );
}

/// The grid of things to report, shown in a sheet from the orange button.
class ReportGrid extends StatelessWidget {
  const ReportGrid({super.key, required this.onPick});
  final void Function(ReportType type) onPick;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.s.whatDoYouSee, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              for (final t in ReportType.values)
                Material(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onPick(t),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ReportBadge(type: t),
                        const SizedBox(height: 8),
                        Text(
                          context.s.reportLabel(t),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
}

/// Opens [ReportGrid] in a bottom sheet; [onPick] runs after the sheet closes.
Future<void> showReportSheet(BuildContext context, {required void Function(ReportType type) onPick}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: ReportGrid(
            onPick: (t) {
              Navigator.pop(sheetContext);
              onPick(t);
            },
          ),
        ),
      ),
    );

/// The big blue card at the top while driving: next turn, how far, which road, exit sign.
class TurnCard extends StatelessWidget {
  const TurnCard({
    super.key,
    required this.icon,
    required this.distance,
    required this.title,
    this.sign,
    this.status,
    this.lanes,
  });

  final IconData icon;
  final String distance;
  final String title;
  final String? sign; // "Keluar 205 · ke Putrajaya", shown like the green highway signs
  final String? status; // e.g. "Mengira semula…"
  final List<LaneArrow>? lanes; // the lanes before the turn, left to right

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDeep, AppColors.turnCard],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x731E40AF), blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _turnRow(),
            if (lanes != null && lanes!.length > 1)
              Padding(padding: const EdgeInsets.only(top: 12), child: LaneRow(lanes: lanes!)),
          ],
        ),
      );

  Widget _turnRow() => Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0x29FFFFFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 46, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(distance, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1)),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25),
                  ),
                  if (sign != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B6B3A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xB3FFFFFF)),
                      ),
                      child: Text(
                        sign!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        status!,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xCCFFFFFF)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
}

/// How one lane looks in the lane row.
enum LaneLook {
  best, // the lane to be in: bright, on a light tile
  ok, // also fine: bright arrow
  off, // goes elsewhere: faded
}

/// One lane before a turn: its painted arrow and whether to use it.
class LaneArrow {
  const LaneArrow(this.icon, this.look);
  final IconData icon;
  final LaneLook look;
}

/// The lanes before a turn, left to right, like the arrows painted on the road.
class LaneRow extends StatelessWidget {
  const LaneRow({super.key, required this.lanes});
  final List<LaneArrow> lanes;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x330B1430),
          borderRadius: BorderRadius.circular(16),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < lanes.length; i++) ...[
                if (i > 0)
                  Container(width: 2, height: 26, margin: const EdgeInsets.symmetric(horizontal: 3), color: const Color(0x40FFFFFF)),
                _LaneTile(lane: lanes[i]),
              ],
            ],
          ),
        ),
      );
}

class _LaneTile extends StatelessWidget {
  const _LaneTile({required this.lane});
  final LaneArrow lane;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 40,
        decoration: BoxDecoration(
          color: lane.look == LaneLook.best ? const Color(0x40FFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          lane.icon,
          size: 28,
          color: switch (lane.look) {
            LaneLook.best => Colors.white,
            LaneLook.ok => const Color(0xD9FFFFFF),
            LaneLook.off => const Color(0x47FFFFFF),
          },
        ),
      );
}

/// A plain floating card with a close button: "Mencari laluan…", errors, "Sampai!".
class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.child, this.onClose});
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Container(
        decoration: glassDecoration(radius: 24),
        padding: const EdgeInsets.fromLTRB(18, 10, 6, 10),
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Expanded(child: DefaultTextStyle.merge(style: const TextStyle(fontWeight: FontWeight.w600), child: child)),
            if (onClose != null)
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded), tooltip: context.s.cancel),
          ],
        ),
      );
}

/// Back button and the destination's name, at the top while choosing a route.
class TopBackBar extends StatelessWidget {
  const TopBackBar({super.key, required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          MapButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: onBack,
            tooltip: context.s.cancel,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 52,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: glassDecoration(radius: 18),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
}

/// Shape shared by the panels that sit at the bottom of the screen.
const _sheetDecoration = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, -10))],
);

/// One route to choose from.
class RouteOption {
  const RouteOption({required this.minutes, required this.km, this.fastest = false, this.toll = false});
  final int minutes;
  final double km;
  final bool fastest;
  final bool toll;
}

/// Bottom panel while choosing a route: route cards, the big "Jom!" button and Simulasi.
class RouteOptionsPanel extends StatelessWidget {
  const RouteOptionsPanel({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.onGo,
    this.simulate,
  });

  final List<RouteOption> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onGo;
  final Widget? simulate; // the Simulasi button, when offered

  @override
  Widget build(BuildContext context) => Container(
        decoration: _sheetDecoration,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 14),
              Text(context.s.chooseRoute, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (var i = 0; i < options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RouteCard(option: options[i], selected: i == selected, onTap: () => onSelect(i)),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: _GoButton(onPressed: onGo)),
                  if (simulate != null) ...[const SizedBox(width: 10), simulate!],
                ],
              ),
            ],
          ),
        ),
      );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.option, required this.selected, required this.onTap});
  final RouteOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFF16285C) : AppColors.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.outline, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.s.minutes(option.minutes),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.1)),
                      Text('${option.km.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (option.fastest) _Badge(context.s.fastest, AppColors.go, const Color(0x2E34D399)),
                if (option.fastest && option.toll) const SizedBox(width: 6),
                if (option.toll) _Badge(context.s.toll, AppColors.warning, const Color(0x2EF59E0B)),
              ],
            ),
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color, this.background);
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

class _GoButton extends StatelessWidget {
  const _GoButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _TapFace(
        face: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDeep]),
          borderRadius: BorderRadius.circular(20),
        ),
        radius: 20,
        shadows: const [BoxShadow(color: Color(0x732563EB), blurRadius: 24, offset: Offset(0, 10))],
        onTap: onPressed,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.navigation_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(context.s.go, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

/// The Simulasi button's look (the map screen wraps it in the speed menu).
class SimulateButtonFace extends StatelessWidget {
  const SimulateButtonFace({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science_outlined, color: AppColors.sky, size: 22),
            const SizedBox(width: 8),
            Text(context.s.simulate,
                style: const TextStyle(color: AppColors.sky, fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      );
}

/// Bottom bar while driving: time left (green), distance and arrival time, report and end trip.
class TripBar extends StatelessWidget {
  const TripBar({
    super.key,
    required this.minutes,
    required this.detail,
    required this.onReport,
    required this.onEnd,
  });

  final int minutes;
  final String detail; // "4.3 km · tiba 21:52"
  final VoidCallback onReport;
  final VoidCallback onEnd;

  /// Height of the bar above the phone's own bottom inset, for placing things just above it.
  static const height = 88.0;

  @override
  Widget build(BuildContext context) => Container(
        decoration: _sheetDecoration,
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.s.minutes(minutes),
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.go, height: 1)),
                    const SizedBox(height: 4),
                    Text(detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  ],
                ),
              ),
              ReportButton(onPressed: onReport, size: 56, radius: 20, glow: false),
              const SizedBox(width: 10),
              Tooltip(
                message: context.s.endTrip,
                child: Material(
                  color: const Color(0x26EF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.danger, width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onEnd,
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.close_rounded, color: AppColors.danger, size: 28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// "21:52" for the arrival time.
String formatClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
