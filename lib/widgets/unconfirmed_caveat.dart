import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../providers/app_preferences.dart';
import '../providers/theme_provider.dart';
import 'privacy_amount.dart';

/// The doubt that belongs to the month's total: how much of it came from rows
/// the parser flagged for a look.
///
/// Sits directly under the hero figure so the caveat is read in the same
/// glance as the number, rather than as a separate notice further down the
/// page that people scroll past.
///
/// Shows the rupee amount, not the row count. Two flagged entries of ₹40 is
/// noise and two of ₹10,240 changes the picture; a count can't tell those
/// apart, so it would send everyone to the queue just to find out which they
/// had.
///
/// Renders nothing at zero. A permanent line that usually reads "nothing to
/// check" is a line people stop seeing, which costs the amber its meaning for
/// the months when there is something.
class UnconfirmedCaveat extends StatelessWidget {
  /// The flagged share of the month's expenses. At or below zero the widget
  /// collapses to [SizedBox.shrink].
  final double amount;

  /// Opens the review queue. The figure and the fix stay one gesture apart.
  final VoidCallback onTap;

  const UnconfirmedCaveat({
    super.key,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();

    final hero = HeroStyle.of(context);
    // The hero surface has no warning colour of its own (only positive and
    // negative are tuned per surface), but the palette's two ambers are split
    // for exactly this: the lifted one stays legible on the near-black hero,
    // the deep one on the champagne light hero.
    final amber = hero.onDark ? AppColors.warningDark : AppColors.warningLight;
    final hidden = context.select<AppPreferences, bool>((p) => p.amountsHidden);
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final line = context.l10n.unconfirmedInTotal(formatter.format(amount));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 14, color: amber),
              const SizedBox(width: 6),
              // Loose fit: the label takes its natural width and only starts
              // ellipsising when the longer translations run out of card. An
              // Expanded here would stretch it and push the chevron to the far
              // edge, detaching it from the text it belongs to.
              Flexible(
                child: Text(
                  // Only the ₹ figure is masked under Privacy Mode. Blanking
                  // the whole line would hide that anything needs checking at
                  // all, which is the one part that isn't private.
                  hidden ? maskRupeeFigures(line) : line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: amber,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: amber),
            ],
          ),
        ),
      ),
    );
  }
}
