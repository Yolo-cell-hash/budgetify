import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_preferences.dart';
import 'motion.dart';

/// Replace the numeric portion of a formatted amount with a fixed bullet
/// mask, keeping the currency symbol, sign, and any surrounding words —
/// e.g. "+ ₹1,234.56" → "+ ₹••••", "₹12,345 spent" → "₹•••• spent".
///
/// A fixed-width mask (rather than one bullet per digit) also hides the
/// magnitude, not just the exact figure.
String maskAmount(String formatted) {
  return formatted.replaceAll(RegExp(r'[\d,]+(?:\.\d+)?'), '••••');
}

/// Mask only ₹-prefixed figures inside a longer sentence, leaving other
/// numbers (percentages, "Day 12 of 30") readable — for insight text.
String maskRupeeFigures(String s) {
  return s.replaceAll(RegExp(r'₹\s?[\d,]+(?:\.\d+)?'), '₹••••');
}

/// A monetary [text] that renders as a clean bullet mask while Privacy Mode
/// is on and amounts are hidden. Tapping toggles a session-wide reveal (one
/// tap unmasks every amount; tapping again re-hides). When privacy mode is
/// off it's a plain [Text].
class PrivacyAmount extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const PrivacyAmount(this.text, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<AppPreferences, bool>((p) => p.amountsHidden);
    if (!hidden) return Text(text, style: style, textAlign: textAlign);

    return GestureDetector(
      onTap: () => context.read<AppPreferences>().toggleReveal(),
      behavior: HitTestBehavior.opaque,
      child: Text(maskAmount(text), style: style, textAlign: textAlign),
    );
  }
}

/// Amount that counts up when visible and shows the bullet mask when hidden.
/// Use where an amount would otherwise animate (hero card, budget gauge).
class PrivacyAnimatedAmount extends StatelessWidget {
  final double value;
  final NumberFormat formatter;
  final TextStyle? style;
  final String prefix;

  const PrivacyAnimatedAmount({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<AppPreferences, bool>((p) => p.amountsHidden);
    if (hidden) {
      return GestureDetector(
        onTap: () => context.read<AppPreferences>().toggleReveal(),
        behavior: HitTestBehavior.opaque,
        child: Text(maskAmount('$prefix${formatter.format(value)}'),
            style: style),
      );
    }
    return CountUpAmount(
      value: value,
      formatter: formatter,
      style: style,
      prefix: prefix,
    );
  }
}
