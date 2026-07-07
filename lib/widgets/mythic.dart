import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Palette + building blocks for the "Master Budgeter" mythic treatment —
/// the final-boss look the profile earns when the crown title is equipped.
/// Kept together so the card, the title rows and any future mythic surface
/// stay visually consistent.
class Mythic {
  Mythic._();

  static const Color deepViolet = Color(0xFF241452);
  static const Color abyss = Color(0xFF080312);
  static const Color gold = Color(0xFFF2C14E);
  static const Color paleGold = Color(0xFFFFE9B0);
  static const Color ember = Color(0xFFB8862B);
  static const Color cyan = Color(0xFF6FE3FF);

  /// Card canvas: royal violet sinking into the void.
  static const List<Color> cardGradient = [deepViolet, Color(0xFF120A2E), abyss];

  /// Molten-gold ramp for crowns, banners and shimmer text.
  static const List<Color> crownGradient = [paleGold, gold, ember];

  /// Border colour that breathes between gold and starlight as [t] loops.
  static Color borderAt(double t) {
    final wave = (math.sin(t * 2 * math.pi) + 1) / 2; // 0..1
    return Color.lerp(gold, cyan, wave * 0.45)!;
  }
}

/// Text painted with a molten-gold gradient and a sheen that sweeps across as
/// [t] loops 0→1. With a fixed [t] (e.g. share capture) it renders a static
/// gold gradient — no animation dependency.
class MythicShimmerText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double t;
  final TextAlign? textAlign;

  const MythicShimmerText(
    this.text, {
    super.key,
    required this.style,
    this.t = 0.5,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    // The sheen band slides from left of the text to right of it.
    final centre = -0.5 + t * 2.0;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: const [
          Mythic.gold,
          Mythic.paleGold,
          Colors.white,
          Mythic.paleGold,
          Mythic.gold,
        ],
        stops: [
          (centre - 0.45).clamp(0.0, 1.0),
          (centre - 0.18).clamp(0.0, 1.0),
          centre.clamp(0.0, 1.0),
          (centre + 0.18).clamp(0.0, 1.0),
          (centre + 0.45).clamp(0.0, 1.0),
        ],
      ).createShader(bounds),
      child: Text(text, textAlign: textAlign, style: style),
    );
  }
}

/// Self-driving [MythicShimmerText] for spots without their own ticker
/// (title gallery rows, bottom sheets). Loops a gentle sheen forever.
class AnimatedMythicText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  const AnimatedMythicText(this.text, {super.key, required this.style, this.textAlign});

  @override
  State<AnimatedMythicText> createState() => _AnimatedMythicTextState();
}

class _AnimatedMythicTextState extends State<AnimatedMythicText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => MythicShimmerText(
        widget.text,
        t: _c.value,
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    );
  }
}

/// The mythic aura: slow-breathing concentric rings and a field of orbiting
/// four-point sparks, painted behind the card content. Deterministic in [t]
/// (0..1 loop) so a static frame can be captured for sharing.
class MythicAuraPainter extends CustomPainter {
  final double t;
  final Alignment focus;

  const MythicAuraPainter({required this.t, this.focus = Alignment.topCenter});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(
      size.width * (0.5 + focus.x / 2),
      size.height * (0.5 + focus.y / 2) + 62,
    );
    final breath = (math.sin(t * 2 * math.pi) + 1) / 2; // 0..1

    // Concentric halo rings.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 4; i++) {
      final radius = 58.0 + i * 34 + breath * 6;
      ring.color = Color.lerp(Mythic.gold, Mythic.cyan, i / 4)!
          .withValues(alpha: (0.16 - i * 0.032) * (0.7 + breath * 0.3));
      canvas.drawCircle(centre, radius, ring);
    }

    // Orbiting sparks — seeded so they twinkle in place between frames.
    final rng = math.Random(7);
    final spark = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 14; i++) {
      final orbit = 46.0 + rng.nextDouble() * 120;
      final speed = i.isEven ? 1.0 : -1.0;
      final phase = rng.nextDouble() * 2 * math.pi;
      final angle = phase + speed * t * 2 * math.pi * 0.5;
      final p = centre + Offset(math.cos(angle), math.sin(angle)) * orbit;
      if (p.dx < 6 || p.dx > size.width - 6 || p.dy < 6 || p.dy > size.height - 6) {
        continue;
      }
      final twinkle =
          (math.sin(t * 2 * math.pi * 2 + phase * 3) + 1) / 2; // 0..1
      final r = 0.9 + twinkle * 1.4;
      spark.color = (i % 3 == 0 ? Mythic.cyan : Mythic.paleGold)
          .withValues(alpha: 0.25 + twinkle * 0.55);
      _star(canvas, p, r, spark);
    }
  }

  /// A tiny four-point star (diamond with pinched waist).
  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r * 2)
      ..quadraticBezierTo(c.dx + r * 0.4, c.dy - r * 0.4, c.dx + r * 2, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.4, c.dy + r * 0.4, c.dx, c.dy + r * 2)
      ..quadraticBezierTo(c.dx - r * 0.4, c.dy + r * 0.4, c.dx - r * 2, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.4, c.dy - r * 0.4, c.dx, c.dy - r * 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(MythicAuraPainter old) =>
      old.t != t || old.focus != focus;
}
