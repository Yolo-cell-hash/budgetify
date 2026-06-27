import 'package:flutter/material.dart';

/// Premium concentric-ring "aura" painted behind a hero card — the Royal Indigo
/// reward's signature flourish, echoing the radiating rings in its reference
/// design. Deliberately whisper-quiet (low-alpha hairlines + a soft glow) so it
/// reads as an embossed, luxe texture rather than loud decoration.
///
/// Drop it as the first child of a [Stack] inside a clipped hero container, and
/// gate it on [HeroStyle.showAura] so only the themes that opt in pay for it.
class HeroAura extends StatelessWidget {
  /// Ring/glow colour — usually the hero's jewel accent.
  final Color color;

  /// Where the rings emanate from, in [Alignment] space. Defaults to just
  /// beyond the top-right corner, matching the reference artwork.
  final Alignment origin;

  const HeroAura({
    super.key,
    required this.color,
    this.origin = const Alignment(1.18, -1.18),
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _AuraPainter(color: color, origin: origin),
        ),
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  final Color color;
  final Alignment origin;

  const _AuraPainter({required this.color, required this.origin});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      (origin.x + 1) / 2 * size.width,
      (origin.y + 1) / 2 * size.height,
    );

    // Soft glow anchors the rings at their origin.
    final glowRadius = size.width * 0.65;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    // Concentric hairline rings radiating outward, fading as they grow.
    final base = size.shortestSide;
    for (var i = 1; i <= 7; i++) {
      canvas.drawCircle(
        center,
        base * 0.16 * i,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: (0.18 - i * 0.02).clamp(0.03, 0.18)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.color != color || old.origin != origin;
}
