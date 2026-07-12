import 'package:flutter/material.dart';

import 'avatars.dart';

/// A glass "savings jar" that fills with accent-coloured liquid to [fraction]
/// (0..1). Animated fill, a gentle wavy surface, glass highlight — the
/// signature visual for a savings goal.
class GoalJar extends StatelessWidget {
  final double fraction;
  final int accent;
  final double size;
  final bool showPercent;

  const GoalJar({
    super.key,
    required this.fraction,
    required this.accent,
    this.size = 120,
    this.showPercent = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = accentOf(accent);
    // The glass (tint, streak, foam, outline) was hardcoded white — fine on
    // a dark card, invisible on the light Savings-Goals card. Derive it from
    // the surface brightness so the jar reads in both.
    final onLight = Theme.of(context).brightness == Brightness.light;
    final glass = onLight ? const Color(0xFF3A2E52) : Colors.white;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
                size: Size.square(size),
                painter: _JarPainter(v, colors, glass)),
            if (showPercent)
              Text(
                '${(fraction * 100).round()}%',
                style: TextStyle(
                  fontSize: size * 0.17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  // On a low fill the number sits over the glass, not the
                  // liquid — so ink on light, white on dark.
                  color: onLight ? const Color(0xFF2E2540) : Colors.white,
                  shadows: [
                    Shadow(
                        color: onLight
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black54,
                        blurRadius: 4),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JarPainter extends CustomPainter {
  final double fill; // 0..1
  final List<Color> accent;
  final Color glass;
  const _JarPainter(this.fill, this.accent, this.glass);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Jar body: a rounded-rect glass inset from the edges.
    final body = Rect.fromLTWH(w * 0.14, h * 0.06, w * 0.72, h * 0.9);
    final jar = RRect.fromRectAndRadius(body, Radius.circular(w * 0.16));

    // Glass tint.
    canvas.drawRRect(jar, Paint()..color = glass.withValues(alpha: 0.06));

    // Liquid (clipped to the jar).
    canvas.save();
    canvas.clipRRect(jar);
    final f = fill.clamp(0.0, 1.0);
    if (f > 0) {
      final top = body.bottom - body.height * f;
      final amp = h * 0.022;
      final liquid = Path()
        ..moveTo(body.left, body.bottom)
        ..lineTo(body.left, top)
        ..quadraticBezierTo(
            body.left + body.width * 0.25, top - amp, body.center.dx, top)
        ..quadraticBezierTo(
            body.left + body.width * 0.75, top + amp, body.right, top)
        ..lineTo(body.right, body.bottom)
        ..close();
      canvas.drawPath(
        liquid,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent[0], accent[1]],
          ).createShader(Rect.fromLTWH(body.left, top, body.width, body.bottom - top)),
      );
      // Foam highlight on the surface.
      canvas.drawPath(
        Path()
          ..moveTo(body.left, top)
          ..quadraticBezierTo(
              body.left + body.width * 0.25, top - amp, body.center.dx, top)
          ..quadraticBezierTo(
              body.left + body.width * 0.75, top + amp, body.right, top),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.012
          ..color = Colors.white.withValues(alpha: 0.35),
      );
    }
    canvas.restore();

    // Glass highlight streak.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(body.left + w * 0.07, body.top + h * 0.08, w * 0.06, h * 0.45),
          Radius.circular(w * 0.04)),
      Paint()..color = glass.withValues(alpha: 0.16),
    );

    // Glass outline + a lid rim.
    canvas.drawRRect(
      jar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..color = glass.withValues(alpha: 0.40),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(body.left - w * 0.02, h * 0.02, body.width + w * 0.04, h * 0.08),
          Radius.circular(w * 0.05)),
      Paint()..color = accent[1].withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_JarPainter old) =>
      old.fill != fill || old.accent != accent || old.glass != glass;
}
