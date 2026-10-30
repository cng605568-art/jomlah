import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The driver's car, drawn in code so it stays sharp on every screen. Blue and lime like the app icon,
/// with a white outline so it stands out on both the day and the night map.
class CarMarker extends StatelessWidget {
  const CarMarker({super.key, required this.headingDeg, this.braking = false});

  /// Degrees clockwise from north; 0 points the car up the screen.
  final double headingDeg;

  /// Slowing down hard: the brake lights glow.
  final bool braking;

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x40C8FF3D), // soft neon halo
            ),
          ),
          Transform.rotate(
            angle: headingDeg * math.pi / 180,
            child: CustomPaint(
              size: const Size(40, 68),
              painter: _CarPainter(braking: braking),
            ),
          ),
        ],
      );
}

class _CarPainter extends CustomPainter {
  const _CarPainter({required this.braking});
  final bool braking;

  static const _lime = Color(0xFFC8FF3D);
  static const _glass = Color(0xFF0E1A3A);
  static const _roof = Color(0xFF2556E8);
  static const _tyre = Color(0xFF14161E);

  static RRect _rr(double l, double t, double r, double b, double radius) =>
      RRect.fromLTRBR(l, t, r, b, Radius.circular(radius));

  static Path _quad(double x0, double y0, double x1, double y1, double x2, double y2, double x3, double y3) =>
      Path()
        ..moveTo(x0, y0)
        ..lineTo(x1, y1)
        ..lineTo(x2, y2)
        ..lineTo(x3, y3)
        ..close();

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 40 x 68 grid (front of the car at the top), scaled to the size we are given.
    canvas.scale(size.width / 40, size.height / 68);

    // Soft shadow under the car.
    canvas.drawRRect(
      _rr(4.5, 4.5, 38.5, 68.5, 12),
      Paint()
        ..color = const Color(0x6E000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Tyres peeking out at the sides.
    final tyre = Paint()..color = _tyre;
    for (final y in const [11.0, 47.0]) {
      canvas.drawRRect(_rr(1, y, 6, y + 11, 2), tyre);
      canvas.drawRRect(_rr(34, y, 39, y + 11, 2), tyre);
    }

    // White outline, then the body: cyan at the front fading to blue at the back.
    canvas.drawRRect(_rr(3, 1, 37, 67, 14), Paint()..color = Colors.white);
    canvas.drawRRect(
      _rr(4, 2, 36, 66, 13),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1FD1FF), Color(0xFF2F6BFF)],
        ).createShader(const Rect.fromLTRB(4, 2, 36, 66)),
    );

    // Lime racing stripe from bonnet to boot.
    final lime = Paint()..color = _lime;
    canvas.drawRect(const Rect.fromLTRB(17.5, 3, 22.5, 65), lime);

    // Windscreen, with a little glint.
    final glass = Paint()..color = _glass;
    canvas.drawPath(_quad(9, 19, 31, 19, 33, 28, 7, 28), glass);
    canvas.drawLine(
      const Offset(11, 21),
      const Offset(18, 21),
      Paint()
        ..color = const Color(0xFF7896D2)
        ..strokeWidth = 1,
    );

    // Roof, with the stripe carrying on over it.
    final roof = Paint()..color = _roof;
    canvas.drawRRect(_rr(8, 29, 32, 45, 3), roof);
    canvas.drawRect(const Rect.fromLTRB(17.5, 29, 22.5, 45), lime);

    // Rear window and wing mirrors.
    canvas.drawPath(_quad(8, 46, 32, 46, 30, 53, 10, 53), glass);
    canvas.drawRRect(_rr(1.5, 20, 5, 24, 1.5), roof);
    canvas.drawRRect(_rr(35, 20, 38.5, 24, 1.5), roof);

    // Headlights.
    final head = Paint()..color = const Color(0xFFFFF6C2);
    canvas.drawRRect(_rr(6, 3.5, 12, 7, 1.5), head);
    canvas.drawRRect(_rr(28, 3.5, 34, 7, 1.5), head);

    // Tail lights, glowing when braking.
    if (braking) {
      final glow = Paint()
        ..color = const Color(0x96FF2D55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawOval(const Rect.fromLTRB(2, 61, 15, 72), glow);
      canvas.drawOval(const Rect.fromLTRB(25, 61, 38, 72), glow);
    }
    final tail = Paint()..color = braking ? const Color(0xFFFF2D55) : const Color(0xFFAA142D);
    canvas.drawRRect(_rr(6, 62, 12, 65, 1.2), tail);
    canvas.drawRRect(_rr(28, 62, 34, 65, 1.2), tail);
  }

  @override
  bool shouldRepaint(_CarPainter oldDelegate) => oldDelegate.braking != braking;
}
