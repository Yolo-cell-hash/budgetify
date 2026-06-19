import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../providers/theme_provider.dart';

/// Visual treatment for a rarity: the medallion disc gradient, ring colour, a
/// sparkle/glow colour, and an animation tier (0 sheen, 1 glow+sparkle,
/// 2 rotating sweep + sparkle).
class RarityStyle {
  final List<Color> disc;
  final Color ring;
  final Color spark;
  final int animTier;
  const RarityStyle(this.disc, this.ring, this.spark, this.animTier);
}

RarityStyle rarityStyle(BadgeRarity r) => switch (r) {
      BadgeRarity.copper =>
        const RarityStyle([Color(0xFFD98A4E), Color(0xFF8C4A1E)], Color(0xFF6F3A18), Color(0xFFF0B080), 0),
      BadgeRarity.bronze =>
        const RarityStyle([Color(0xFFE0934A), Color(0xFF935A22)], Color(0xFF6E441A), Color(0xFFF2B97E), 0),
      BadgeRarity.silver =>
        const RarityStyle([Color(0xFFEDF0F4), Color(0xFF98A0AC)], Color(0xFF79828F), Color(0xFFFFFFFF), 0),
      BadgeRarity.gold =>
        const RarityStyle([Color(0xFFF4D585), Color(0xFFC09530)], Color(0xFF8E6E22), Color(0xFFFFF1C2), 1),
      BadgeRarity.platinum =>
        const RarityStyle([Color(0xFFF1F5FA), Color(0xFFA9B7C7)], Color(0xFF8392A3), Color(0xFFFFFFFF), 1),
      BadgeRarity.ruby =>
        const RarityStyle([Color(0xFFF26A99), Color(0xFFA11846)], Color(0xFF7C1236), Color(0xFFFFC2D8), 2),
      BadgeRarity.diamond =>
        const RarityStyle([Color(0xFFAEF1EC), Color(0xFF4FB0C7)], Color(0xFF2E8AA2), Color(0xFFFFFFFF), 2),
    };

String rarityName(BadgeRarity r) => switch (r) {
      BadgeRarity.copper => 'Copper',
      BadgeRarity.bronze => 'Bronze',
      BadgeRarity.silver => 'Silver',
      BadgeRarity.gold => 'Gold',
      BadgeRarity.platinum => 'Platinum',
      BadgeRarity.ruby => 'Ruby',
      BadgeRarity.diamond => 'Diamond',
    };

/// A premium achievement medallion. Earned badges animate by rarity tier;
/// locked badges render desaturated with a small lock. Keep [animate] off in
/// dense grids on low-end devices if needed.
class BadgeMedallion extends StatefulWidget {
  final BadgeRarity rarity;
  final String emblem;
  final bool earned;
  final double size;
  final bool animate;

  const BadgeMedallion({
    super.key,
    required this.rarity,
    required this.emblem,
    required this.earned,
    this.size = 84,
    this.animate = true,
  });

  @override
  State<BadgeMedallion> createState() => _BadgeMedallionState();
}

class _BadgeMedallionState extends State<BadgeMedallion>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.earned && widget.animate) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = rarityStyle(widget.rarity);
    final s = widget.size;
    final emblem = Text(
      widget.emblem,
      style: TextStyle(
        fontSize: s * 0.40,
        shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
      ),
    );

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_c != null)
            AnimatedBuilder(
              animation: _c!,
              builder: (_, __) => CustomPaint(
                size: Size.square(s),
                painter: _BadgePainter(t: _c!.value, style: style, earned: true),
              ),
            )
          else
            CustomPaint(
              size: Size.square(s),
              painter: _BadgePainter(t: 0, style: style, earned: widget.earned),
            ),
          Opacity(opacity: widget.earned ? 1 : 0.30, child: emblem),
          if (!widget.earned)
            Positioned(
              right: s * 0.06,
              bottom: s * 0.06,
              child: Container(
                padding: EdgeInsets.all(s * 0.05),
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2D36),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded,
                    size: s * 0.16, color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  final double t; // 0..1 animation phase
  final RarityStyle style;
  final bool earned;

  const _BadgePainter({required this.t, required this.style, required this.earned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final discR = r * 0.82;

    // Locked: flat desaturated disc + ring, no flourish.
    if (!earned) {
      final disc = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF3A3E47), Color(0xFF24272E)],
        ).createShader(Rect.fromCircle(center: center, radius: discR));
      canvas.drawCircle(center, discR, disc);
      canvas.drawCircle(
        center,
        discR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.10
          ..color = const Color(0xFF454953),
      );
      return;
    }

    // Glow (mid/high tiers): a soft pulsing halo behind the disc.
    if (style.animTier >= 1) {
      final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
      canvas.drawCircle(
        center,
        discR * (1.04 + 0.06 * pulse),
        Paint()
          ..color = style.spark.withValues(alpha: 0.18 + 0.22 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18),
      );
    }

    // Disc.
    final disc = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: style.disc,
      ).createShader(Rect.fromCircle(center: center, radius: discR));
    canvas.drawCircle(center, discR, disc);

    // Ring.
    canvas.drawCircle(
      center,
      discR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.11
        ..color = style.ring,
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: discR)));

    if (style.animTier == 0) {
      // Sheen: a diagonal light band sweeping across the disc.
      final x = (t * 2 - 0.5) * size.width;
      final band = Rect.fromLTWH(x, -size.height, size.width * 0.32, size.height * 3);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.5);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawRect(
        band,
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
      canvas.restore();
    } else {
      // High tier: a bright arc sweeping around the ring.
      if (style.animTier == 2) {
        final sweep = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.11
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: 2 * math.pi,
            transform: GradientRotation(t * 2 * math.pi),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.12, 0.24],
          ).createShader(Rect.fromCircle(center: center, radius: discR));
        canvas.drawCircle(center, discR, sweep);
      }
    }
    canvas.restore();

    // Sparkles (mid/high tiers): twinkling 4-point stars at fixed angles.
    if (style.animTier >= 1) {
      const angles = [0.5, 2.1, 3.7, 5.2];
      for (var i = 0; i < angles.length; i++) {
        final phase = (t + i / angles.length) % 1.0;
        final tw = math.sin(phase * 2 * math.pi).clamp(0.0, 1.0);
        if (tw <= 0.05) continue;
        final a = angles[i];
        final pos = center + Offset(math.cos(a), math.sin(a)) * discR * 0.66;
        _sparkle(canvas, pos, r * 0.13 * tw, style.spark.withValues(alpha: tw));
      }
    }
  }

  void _sparkle(Canvas canvas, Offset c, double rad, Color color) {
    final p = Paint()..color = color;
    final path = Path();
    path.moveTo(c.dx, c.dy - rad);
    path.quadraticBezierTo(c.dx, c.dy, c.dx + rad, c.dy);
    path.quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + rad);
    path.quadraticBezierTo(c.dx, c.dy, c.dx - rad, c.dy);
    path.quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - rad);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.t != t || old.earned != earned || old.style != style;
}

/// Celebratory "Achievement Unlocked!" moment — a scale-in dialog with the
/// animated medallion. Returns when dismissed.
Future<void> showBadgeUnlock(
  BuildContext context, {
  required BadgeRarity rarity,
  required String emblem,
  required String groupName,
  required String tierLabel,
}) {
  final colors = AppColors.of(context);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (ctx) => Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.7, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, v, child) =>
            Transform.scale(scale: v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ACHIEVEMENT UNLOCKED',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 18),
              BadgeMedallion(rarity: rarity, emblem: emblem, earned: true, size: 132),
              const SizedBox(height: 18),
              Text(
                '$groupName · $tierLabel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${rarityName(rarity)} tier',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Awesome'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
