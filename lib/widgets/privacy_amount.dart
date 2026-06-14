import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_preferences.dart';

/// Blurs [child] while Privacy Mode is on and amounts are hidden. Tapping a
/// blurred amount toggles a session-wide reveal (one tap unblurs every
/// amount in the app; tapping again re-hides). When privacy mode is off it
/// renders [child] untouched.
///
/// Real glyphs are blurred (rather than replaced with dots) so layout width
/// and the premium feel are preserved — you can tell a figure is there, you
/// just can't read it.
class PrivacyBlur extends StatelessWidget {
  final Widget child;
  final double blurSigma;

  const PrivacyBlur({super.key, required this.child, this.blurSigma = 9});

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<AppPreferences, bool>((p) => p.amountsHidden);
    if (!hidden) return child;

    return GestureDetector(
      onTap: () => context.read<AppPreferences>().toggleReveal(),
      behavior: HitTestBehavior.opaque,
      child: ClipRect(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: child,
        ),
      ),
    );
  }
}

/// Convenience wrapper for a plain monetary text figure.
class PrivacyAmount extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final double blurSigma;

  const PrivacyAmount(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.blurSigma = 9,
  });

  @override
  Widget build(BuildContext context) {
    return PrivacyBlur(
      blurSigma: blurSigma,
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}
