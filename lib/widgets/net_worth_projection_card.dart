import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/net_worth_projection.dart';
import '../providers/theme_provider.dart';

/// A forward-looking card on the Net Worth screen: "if you keep saving like
/// this, here's where your net worth is headed." Lets the user pick a horizon
/// and optionally assume modest investment growth. Estimate only — clearly
/// labelled as such.
class NetWorthProjectionCard extends StatefulWidget {
  final double currentNetWorth;

  /// Typical monthly savings (the projection's contribution). May be negative.
  final double monthlySavings;

  const NetWorthProjectionCard({
    super.key,
    required this.currentNetWorth,
    required this.monthlySavings,
  });

  @override
  State<NetWorthProjectionCard> createState() => _NetWorthProjectionCardState();
}

class _NetWorthProjectionCardState extends State<NetWorthProjectionCard> {
  static const _horizons = [1, 3, 5, 10];
  int _years = 5;
  bool _assumeReturns = false;

  @override
  Widget build(BuildContext context) {
    final hero = HeroStyle.of(context);
    final s = context.l10n;

    final projection = NetWorthProjection(
      currentNetWorth: widget.currentNetWorth,
      monthlyContribution: widget.monthlySavings,
      annualReturnRate: _assumeReturns ? 0.08 : 0.0,
    );
    final projected = projection.projectYears(_years.toDouble());

    final milestone = nextNetWorthMilestone(widget.currentNetWorth);
    final monthsToMilestone =
        milestone == null ? null : projection.monthsToReach(milestone);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: hero.gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hero.border),
        boxShadow: hero.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 18, color: hero.accent),
              const SizedBox(width: 8),
              Text(
                s.netWorthProjection.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: hero.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            s.projectedNetWorth,
            style: TextStyle(fontSize: 12.5, color: hero.mutedForeground),
          ),
          const SizedBox(height: 2),
          Text(
            _inrCompact(projected),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: hero.foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${s.basedOnSaving(_inr(widget.monthlySavings))} · '
            '${_assumeReturns ? s.withGrowth : s.savingsOnly}',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.3,
              color: hero.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          // Horizon selector.
          Row(
            children: [
              for (final y in _horizons) ...[
                _HorizonChip(
                  label: s.yearsShort(y),
                  selected: y == _years,
                  hero: hero,
                  onTap: () => setState(() => _years = y),
                ),
                if (y != _horizons.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // 8% growth toggle.
          GestureDetector(
            onTap: () => setState(() => _assumeReturns = !_assumeReturns),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  _assumeReturns
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: _assumeReturns ? hero.accent : hero.mutedForeground,
                ),
                const SizedBox(width: 8),
                Text(
                  s.assumeReturns,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hero.foreground,
                  ),
                ),
              ],
            ),
          ),
          if (milestone != null && monthsToMilestone != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: hero.innerFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hero.innerBorder),
              ),
              child: Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.reachMilestoneIn(
                        _inrCompact(milestone),
                        s.aboutYears(monthsToMilestone / 12),
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: hero.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            s.projectionDisclaimer,
            style: TextStyle(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: hero.foregroundAlpha(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Indian-style formatting ────────────────────────────────────────────
  static final NumberFormat _grouped = NumberFormat.decimalPattern('en_IN');

  static String _inr(double v) => '₹${_grouped.format(v.round())}';

  /// Compact Indian currency: ₹1.2Cr / ₹45L / ₹12,300.
  static String _inrCompact(double v) {
    final neg = v < 0;
    final a = v.abs();
    String body;
    if (a >= 10000000) {
      final cr = a / 10000000;
      body = '₹${cr.toStringAsFixed(cr % 1 == 0 ? 0 : 2)}Cr';
    } else if (a >= 100000) {
      final l = a / 100000;
      body = '₹${l.toStringAsFixed(l % 1 == 0 ? 0 : 1)}L';
    } else {
      body = '₹${_grouped.format(a.round())}';
    }
    return neg ? '-$body' : body;
  }
}

class _HorizonChip extends StatelessWidget {
  final String label;
  final bool selected;
  final HeroStyle hero;
  final VoidCallback onTap;

  const _HorizonChip({
    required this.label,
    required this.selected,
    required this.hero,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? hero.accent : hero.innerFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? hero.accent : hero.innerBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected
                ? (hero.onDark ? const Color(0xFF1B1E28) : Colors.white)
                : hero.foreground,
          ),
        ),
      ),
    );
  }
}
