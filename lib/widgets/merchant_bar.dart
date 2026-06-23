import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import 'privacy_amount.dart';

/// One animated merchant row: rank badge, name, amount, an animated spend bar,
/// and a transaction-count + share caption. Shared by the category-budget
/// insights screen and the merchant-analytics screens for one consistent look.
class MerchantBar extends StatelessWidget {
  final int rank;
  final String name;
  final String amountLabel;
  final int count;
  final double fraction; // 0..1 relative to the top merchant (bar width)
  final double shareOfTotal; // 0..1 of the period total (caption)
  final Color color;
  final bool isTop;

  /// Whether the share caption reads "of category" (vs the default
  /// "of spending"). Localized at build time.
  final bool shareIsCategory;

  /// Optional tap handler (e.g. to drill into a merchant).
  final VoidCallback? onTap;

  const MerchantBar({
    super.key,
    required this.rank,
    required this.name,
    required this.amountLabel,
    required this.count,
    required this.fraction,
    required this.shareOfTotal,
    required this.color,
    this.isTop = false,
    this.shareIsCategory = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withAlpha(isTop ? 45 : 26),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
            if (isTop)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  context.l10n.topBadge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: color,
                  ),
                ),
              ),
            PrivacyAmount(
              amountLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: colors.textTertiary),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 8, color: color.withAlpha(20)),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withAlpha(160), color],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${context.l10n.txnCountCaption(count)} · '
          '${(shareOfTotal * 100).toStringAsFixed(0)}% '
          '${shareIsCategory ? context.l10n.ofCategory : context.l10n.ofSpending}',
          style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: content,
    );
  }
}
