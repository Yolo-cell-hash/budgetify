import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A living, flickering streak flame — the evolving streak emblem. It breathes
/// and shimmers on a loop, and grows hotter (amber → orange → white-blue core)
/// as the streak climbs, so a long streak literally looks fiercer than a short
/// one. Replaces the static 🔥 emoji.
class StreakFlame extends StatefulWidget {
  final int streak;
  final double size;

  const StreakFlame({super.key, required this.streak, this.size = 30});

  /// 0..3, hotter the longer the streak: ember → flame → blaze → inferno.
  static int tierFor(int streak) {
    if (streak >= 30) return 3;
    if (streak >= 14) return 2;
    if (streak >= 5) return 1;
    return 0;
  }

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.3,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _FlamePainter(
            t: _c.value,
            tier: StreakFlame.tierFor(widget.streak),
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  final double t; // 0..1 loop phase
  final int tier;

  _FlamePainter({required this.t, required this.tier});

  // [outer, mid, core] per tier — hotter (toward white / blue core) as it grows.
  List<Color> get _palette => switch (tier) {
        3 => const [Color(0xFF8AC0FF), Color(0xFFFF9A1F), Color(0xFFFFFFFF)],
        2 => const [Color(0xFFFF5A1F), Color(0xFFFFC21F), Color(0xFFFFF4CC)],
        1 => const [Color(0xFFFF7A1A), Color(0xFFFFB020), Color(0xFFFFE39A)],
        _ => const [Color(0xFFEF8A3C), Color(0xFFFFBC63), Color(0xFFFFDDA6)],
      };

  Path _flame(double cx, Size size, double scale) {
    final h = size.height;
    final top = h * 0.04;
    final bot = h * 0.96;
    final b = size.width * 0.42 * scale; // bulge
    return Path()
      ..moveTo(cx, top)
      ..quadraticBezierTo(cx + b, h * 0.42, cx + b * 0.55, h * 0.82)
      ..quadraticBezierTo(cx + b * 0.30, bot, cx, bot)
      ..quadraticBezierTo(cx - b * 0.30, bot, cx - b * 0.55, h * 0.82)
      ..quadraticBezierTo(cx - b, h * 0.42, cx, top)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Two out-of-phase waves so the flicker never looks mechanical.
    final flick = math.sin(t * 2 * math.pi);
    final flick2 = math.sin(t * 2 * math.pi * 1.7 + 1.1);
    final cx = w / 2 + flick * 0.05 * w;
    final stretch = 1 + flick2 * 0.07;
    final pal = _palette;

    // Outer glow — brighter and larger at higher tiers.
    final center = Offset(w / 2, h * 0.62);
    final glowR = w * (0.60 + flick2 * 0.05) * (1 + tier * 0.07);
    canvas.drawCircle(
      center,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            pal[0].withValues(alpha: 0.30 + tier * 0.04),
            pal[0].withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowR)),
    );

    // Layered flame: outer body, mid, hot core.
    canvas.drawPath(_flame(cx, size, 1.0 * stretch), Paint()..color = pal[0]);
    canvas.drawPath(
        _flame(cx, size, 0.70 * stretch), Paint()..color = pal[1]);
    canvas.drawPath(
        _flame(cx + flick * 0.02 * w, size, 0.40 * stretch),
        Paint()..color = pal[2]);
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.t != t || old.tier != tier;
}
