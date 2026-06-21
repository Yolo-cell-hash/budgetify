import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../providers/theme_provider.dart';

/// Frame treatment for a rarity — Clash-Royale-mastery style: a consistent
/// hexagonal shield whose **metal colour and ornamentation** change by tier
/// while the icon inside stays the same. [animTier]: 0 sheen, 1 glow+sparkle,
/// 2 rotating shimmer.
class RarityStyle {
  final List<Color> frame; // metal gradient [light, dark]
  final Color edge; // frame outline
  final Color spark; // glow / sparkle / gem accent
  final int animTier;
  const RarityStyle(this.frame, this.edge, this.spark, this.animTier);
}

RarityStyle rarityStyle(BadgeRarity r) => switch (r) {
      BadgeRarity.copper =>
        const RarityStyle([Color(0xFFD98A4E), Color(0xFF8C4A1E)], Color(0xFF5E3414), Color(0xFFF0B080), 0),
      BadgeRarity.bronze =>
        const RarityStyle([Color(0xFFE3A55C), Color(0xFF965C22)], Color(0xFF5E3A16), Color(0xFFF2B97E), 0),
      BadgeRarity.silver =>
        const RarityStyle([Color(0xFFEDF0F4), Color(0xFF9AA2AE)], Color(0xFF6B7480), Color(0xFFFFFFFF), 0),
      BadgeRarity.gold =>
        const RarityStyle([Color(0xFFF6D77E), Color(0xFFC0922E)], Color(0xFF806017), Color(0xFFFFF1C2), 1),
      BadgeRarity.platinum =>
        const RarityStyle([Color(0xFFF3F7FC), Color(0xFFAAB8C8)], Color(0xFF6E7C8C), Color(0xFFE8FBFF), 1),
      BadgeRarity.ruby =>
        const RarityStyle([Color(0xFFF472A6), Color(0xFFA11846)], Color(0xFF6E1030), Color(0xFFFFC2D8), 2),
      BadgeRarity.diamond =>
        const RarityStyle([Color(0xFFB8F3EE), Color(0xFF4FB0C7)], Color(0xFF2E7E92), Color(0xFFFFFFFF), 2),
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

const Color _windowTop = Color(0xFF2C313C);
const Color _windowBottom = Color(0xFF14161C);

/// A premium achievement medallion: a tiered metal frame (with a crown, and —
/// at higher tiers — gems, side ears and a glow) around an unchanging icon.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.size;
    // Icon sits in the window — a touch below centre to clear the crown.
    final emblem = Padding(
      padding: EdgeInsets.only(top: s * 0.06),
      child: Text(
        widget.emblem,
        style: TextStyle(
          fontSize: s * 0.30,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
        ),
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
                painter: _BadgePainter(
                    t: _c!.value,
                    style: style,
                    rarity: widget.rarity,
                    earned: true,
                    isDark: isDark),
              ),
            )
          else
            CustomPaint(
              size: Size.square(s),
              painter: _BadgePainter(
                  t: 0,
                  style: style,
                  rarity: widget.rarity,
                  earned: widget.earned,
                  isDark: isDark),
            ),
          Opacity(opacity: widget.earned ? 1 : 0.32, child: emblem),
          if (!widget.earned)
            Positioned(
              right: s * 0.02,
              bottom: s * 0.08,
              child: Container(
                padding: EdgeInsets.all(s * 0.045),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2D36) : const Color(0xFFB7BCC6),
                  shape: BoxShape.circle,
                  border: isDark
                      ? null
                      : Border.all(color: Colors.white, width: s * 0.012),
                ),
                child: Icon(Icons.lock_rounded,
                    size: s * 0.15,
                    color: isDark ? Colors.white70 : Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// Flat-top hexagon (pointy left/right) centred at [c].
Path _hex(Offset c, double rx, double ry) => Path()
  ..moveTo(c.dx + rx, c.dy)
  ..lineTo(c.dx + rx * 0.5, c.dy - ry)
  ..lineTo(c.dx - rx * 0.5, c.dy - ry)
  ..lineTo(c.dx - rx, c.dy)
  ..lineTo(c.dx - rx * 0.5, c.dy + ry)
  ..lineTo(c.dx + rx * 0.5, c.dy + ry)
  ..close();

class _BadgePainter extends CustomPainter {
  final double t;
  final RarityStyle style;
  final BadgeRarity rarity;
  final bool earned;
  final bool isDark;

  const _BadgePainter({
    required this.t,
    required this.style,
    required this.rarity,
    required this.earned,
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + size.height * 0.03);
    final rx = size.width * 0.44;
    final ry = size.width * 0.45;
    final frame = _hex(c, rx, ry);
    final rect = Rect.fromCircle(center: c, radius: rx);
    final lvl = rarity.index; // 0..6 ornamentation level

    if (!earned) {
      // Locked badges adapt to the theme: muted gunmetal on dark, soft
      // brushed-silver on light — so they read as "not yet earned" without
      // looking like a stray dark-mode element on a porcelain background.
      if (isDark) {
        _crown(canvas, c, rx, ry, const [Color(0xFF4A4E58), Color(0xFF31343C)],
            const Color(0xFF26282F));
        _fill(canvas, frame, const [Color(0xFF3C404A), Color(0xFF262931)], rect);
        _stroke(canvas, frame, const Color(0xFF20232A), size.width * 0.035);
        _window(canvas, c, rx, ry);
      } else {
        _crown(canvas, c, rx, ry, const [Color(0xFFDDE0E6), Color(0xFFBCC1CB)],
            const Color(0xFFA6ACB7));
        _fill(canvas, frame, const [Color(0xFFEEF0F3), Color(0xFFCBD0D8)], rect);
        _stroke(canvas, frame, const Color(0xFFAEB4BE), size.width * 0.035);
        _window(canvas, c, rx, ry,
            top: const Color(0xFFE2E5EA), bottom: const Color(0xFFC6CAD2));
      }
      return;
    }

    // Glow halo (mid/high tiers).
    if (style.animTier >= 1) {
      final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
      canvas.drawPath(
        _hex(c, rx * (1.05 + 0.05 * pulse), ry * (1.05 + 0.05 * pulse)),
        Paint()
          ..color = style.spark.withValues(alpha: 0.14 + 0.18 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.14),
      );
    }

    // Crown + ears behind the frame so the frame overlaps their base.
    _crown(canvas, c, rx, ry, style.frame, style.edge, gems: lvl >= 3, spark: style.spark);
    if (lvl >= 4) _ears(canvas, c, rx, ry, style);

    // Frame.
    _fill(canvas, frame, style.frame, rect);
    _stroke(canvas, frame, style.edge, size.width * 0.04);
    // Top bevel highlight.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - rx * 0.5, c.dy - ry)
        ..lineTo(c.dx + rx * 0.5, c.dy - ry),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.018
        ..color = Colors.white.withValues(alpha: 0.45),
    );

    // Window.
    _window(canvas, c, rx, ry);

    // Frame shimmer / sheen, clipped to the metal ring (frame minus window).
    canvas.save();
    canvas.clipPath(
      Path.combine(PathOperation.difference, frame, _hex(c, rx * 0.62, ry * 0.62)),
    );
    if (style.animTier == 2) {
      canvas.drawPath(
        frame,
        Paint()
          ..shader = SweepGradient(
            transform: GradientRotation(t * 2 * math.pi),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.6),
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.08, 0.22, 1.0],
          ).createShader(rect),
      );
    } else {
      final x = (t * 2 - 0.5) * size.width;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.5);
      canvas.translate(-c.dx, -c.dy);
      canvas.drawRect(
        Rect.fromLTWH(x, -size.height, size.width * 0.26, size.height * 3),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
      canvas.restore();
    }
    canvas.restore();

    // Sparkles (mid/high tiers).
    if (style.animTier >= 1) {
      const angles = [0.6, 2.5, 3.9];
      for (var i = 0; i < angles.length; i++) {
        final phase = (t + i / angles.length) % 1.0;
        final tw = math.sin(phase * 2 * math.pi).clamp(0.0, 1.0);
        if (tw <= 0.05) continue;
        final a = angles[i];
        final pos = c + Offset(math.cos(a) * rx, math.sin(a) * ry) * 0.82;
        _sparkle(canvas, pos, size.width * 0.10 * tw, style.spark.withValues(alpha: tw));
      }
    }
  }

  void _fill(Canvas canvas, Path p, List<Color> metal, Rect rect) {
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [metal[0], metal[1]],
        ).createShader(rect),
    );
  }

  void _stroke(Canvas canvas, Path p, Color color, double w) {
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  void _window(Canvas canvas, Offset c, double rx, double ry,
      {Color top = _windowTop, Color bottom = _windowBottom}) {
    final win = _hex(c, rx * 0.62, ry * 0.62);
    canvas.drawPath(
      win,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Rect.fromCircle(center: c, radius: rx * 0.62)),
    );
    canvas.drawPath(
      win,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rx * 0.04
        ..color = Colors.black.withValues(alpha: 0.35),
    );
  }

  void _crown(Canvas canvas, Offset c, double rx, double ry, List<Color> metal,
      Color edge,
      {bool gems = false, Color? spark}) {
    final cw = rx * 1.05;
    final by = c.dy - ry * 0.82; // baseline overlaps frame top
    final bh = rx * 0.16;
    final ty = by - rx * 0.46;
    final left = c.dx - cw / 2;
    final bw = cw / 3;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [metal[0], metal[1]],
      ).createShader(Rect.fromLTWH(left, ty, cw, by - ty));
    // bar
    final bar = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, by - bh, left + cw, by), Radius.circular(bh * 0.4));
    canvas.drawRRect(bar, paint);
    // three spikes
    for (var i = 0; i < 3; i++) {
      final cx = left + bw * (i + 0.5);
      final tip = ty;
      final path = Path()
        ..moveTo(cx - bw * 0.5, by - bh)
        ..lineTo(cx, tip)
        ..lineTo(cx + bw * 0.5, by - bh)
        ..close();
      canvas.drawPath(path, paint);
      // ball / gem on each tip
      final dotColor = gems && spark != null ? spark : metal[0];
      canvas.drawCircle(Offset(cx, tip), rx * 0.07, Paint()..color = dotColor);
      canvas.drawCircle(Offset(cx, tip), rx * 0.07,
          Paint()..style = PaintingStyle.stroke..strokeWidth = rx * 0.02..color = edge);
    }
    canvas.drawRRect(
      bar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rx * 0.03
        ..color = edge,
    );
  }

  void _ears(Canvas canvas, Offset c, double rx, double ry, RarityStyle style) {
    for (final sign in [-1.0, 1.0]) {
      final cx = c.dx + sign * rx * 1.02;
      final r = Rect.fromCenter(center: Offset(cx, c.dy), width: rx * 0.30, height: ry * 0.5);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(rx * 0.08));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [style.frame[0], style.frame[1]],
          ).createShader(r),
      );
      canvas.drawRRect(rr,
          Paint()..style = PaintingStyle.stroke..strokeWidth = rx * 0.03..color = style.edge);
    }
  }

  void _sparkle(Canvas canvas, Offset c, double rad, Color color) {
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(c.dx, c.dy - rad)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + rad, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + rad)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - rad, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - rad);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.t != t ||
      old.earned != earned ||
      old.rarity != rarity ||
      old.isDark != isDark;
}

/// Celebratory "Achievement Unlocked!" moment — a scale-in dialog with the
/// animated medallion.
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
              BadgeMedallion(rarity: rarity, emblem: emblem, earned: true, size: 140),
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
