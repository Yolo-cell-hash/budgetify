import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Subtle entrance: fade + 16px slide-up with easeOutCubic.
/// Give list items an increasing [order] for a gentle stagger.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int order;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.order = 0,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: 60 * order);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Currency amount that counts up to its value when it changes.
class CountUpAmount extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final NumberFormat? formatter;
  final String prefix;

  const CountUpAmount({
    super.key,
    required this.value,
    this.style,
    this.formatter,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final fmt =
        formatter ?? NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return Text('$prefix${fmt.format(animated)}', style: style);
      },
    );
  }
}

/// Linear progress that animates toward its value.
class AnimatedProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final Color backgroundColor;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) {
          return LinearProgressIndicator(
            value: animated,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: height,
          );
        },
      ),
    );
  }
}

/// Tap feedback: scales down slightly while pressed. Wrap cards/buttons
/// that use GestureDetector for a tactile, premium feel.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PressableScale({super.key, required this.child, this.onTap});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
