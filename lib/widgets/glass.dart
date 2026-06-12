import 'dart:ui';

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// Frosted-glass card: blurred backdrop, translucent fill, hairline border.
/// Use sparingly over the [AmbientBackground] so the blur has something to
/// refract — that's what sells the glass effect.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.blur = 18,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.65),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Soft ambient glow blobs behind screen content. Very subtle — two
/// out-of-focus gold/ink orbs that give glass surfaces depth without
/// shouting. Wrap a screen body: `AmbientBackground(child: ...)`.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: colors.background)),
        Positioned(
          top: -120,
          right: -80,
          child: _GlowOrb(
            diameter: 320,
            color: AppColors.gold.withOpacity(isDark ? 0.10 : 0.16),
          ),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: _GlowOrb(
            diameter: 360,
            color: isDark
                ? const Color(0xFF3A4163).withOpacity(0.22)
                : const Color(0xFF8FA9C7).withOpacity(0.18),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double diameter;
  final Color color;

  const _GlowOrb({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
