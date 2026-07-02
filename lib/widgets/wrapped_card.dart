import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/monthly_recap.dart';
import '../providers/theme_provider.dart';
import 'brand_logo.dart';

/// The shareable "Wrapped" card — a fixed-size (360×640) luxury card rendered
/// off the app's hero gradient, carrying only **percentages, counts and
/// names** (no amounts) so it's safe to post to WhatsApp / Instagram.
///
/// Fixed dimensions keep the captured image crisp and consistent regardless
/// of device.
class WrappedCard extends StatelessWidget {
  final MonthlyRecap recap;

  /// When true, render actual ₹ amounts instead of percentages/shares. Off by
  /// default so the shareable card stays amount-free.
  final bool showAmounts;

  const WrappedCard({super.key, required this.recap, this.showAmounts = false});

  static const double width = 360;
  static const double height = 640;

  static final _money =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static const _gold = AppColors.gold;
  static const _green = AppColors.successDark;
  static const _red = AppColors.dangerDark;

  // Premium gradient for the card background
  static const _bgGradient = [
    Color(0xFF0D0F1A),
    Color(0xFF171B2E),
    Color(0xFF0D0F1A),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final monthLabel = l10n.wrappedCardMonth(recap.month);

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          // Outer shimmer border
          gradient: const LinearGradient(
            colors: [
              Color(0xFF3A3220),
              Color(0xFFC8A75E),
              Color(0xFF3A3220),
              Color(0xFFC8A75E),
              Color(0xFF3A3220),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(1.2),
        child: Container(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: _bgGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(27),
          ),
          child: Stack(
            children: [
              // Ambient glow orbs
              Positioned(
                top: -40,
                right: -20,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _gold.withValues(alpha: 0.12),
                        _gold.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                left: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF4A5899).withValues(alpha: 0.10),
                        const Color(0xFF4A5899).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Floating sparkle dots
              ..._sparkles(),
              // Main content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _gold.withValues(alpha: 0.18),
                              _gold.withValues(alpha: 0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.25),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            BrandLogo(size: 13),
                            SizedBox(width: 6),
                            Text(
                              'BUDGETIFY',
                              style: TextStyle(
                                color: _gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                            width: 0.5,
                          ),
                        ),
                        child: const Text(
                          '✨ WRAPPED',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    monthLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.myMonthInReview,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 24),
                  _hero(l10n),
                  const SizedBox(height: 22),

                  // Divider with gradient fade
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          _gold.withValues(alpha: 0.3),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(child: _stats(l10n)),

                  // Footer
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.04),
                          Colors.white.withValues(alpha: 0.01),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.40)),
                        const SizedBox(width: 5),
                        Text(
                          l10n.privateOnDevice,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.40),
                            fontSize: 10.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'budgetify.app',
                          style: TextStyle(
                            color: _gold.withValues(alpha: 0.7),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Decorative sparkle dots scattered around the card.
  List<Widget> _sparkles() {
    final rng = math.Random(recap.month.month * 31 + recap.transactionCount);
    return List.generate(8, (i) {
      final top = 60.0 + rng.nextDouble() * 480;
      final left = 20.0 + rng.nextDouble() * 300;
      final size = 1.5 + rng.nextDouble() * 2.5;
      final alpha = 0.15 + rng.nextDouble() * 0.25;
      return Positioned(
        top: top,
        left: left,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withValues(alpha: alpha),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: alpha * 0.5),
                blurRadius: size * 3,
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Big hero stat. In numbers mode, lead with total spent; otherwise the
  /// privacy-safe savings rate / top-category share.
  Widget _hero(AppStrings l10n) {
    if (showAmounts) {
      return _heroBlock(
          _money.format(recap.totalSpent), l10n.wSpentThisMonth, _gold);
    }
    final rate = recap.savingsRatePct;
    if (rate != null && rate >= 0) {
      return _heroBlock('$rate%', l10n.wOfIncomeSaved, _gold);
    }
    if (rate != null && rate < 0) {
      return _heroBlock(l10n.wOver, l10n.wSpentMoreThanEarned, _red);
    }
    final c = recap.topCategory;
    if (c != null) {
      return _heroBlock('${c.sharePct}%',
          l10n.wWentTo(l10n.categoryName(c.label).toUpperCase()), _gold);
    }
    return _heroBlock(
        '${recap.transactionCount}', l10n.wTransactionsThisMonth, _gold);
  }

  Widget _heroBlock(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Glow halo behind the number
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -10,
              top: 10,
              child: Container(
                width: 120,
                height: 60,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // FittedBox so longer figures (e.g. ₹1,24,500) never overflow.
            SizedBox(
              width: width - 80,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.80),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _stats(AppStrings l10n) {
    final rows = <Widget>[];

    if (recap.topCategory != null) {
      final c = recap.topCategory!;
      final cat = l10n.categoryName(c.label);
      rows.add(_statRow('🍔', l10n.wTopCategory,
          showAmounts && recap.topCategoryAmount != null
              ? '$cat · ${_money.format(recap.topCategoryAmount)}'
              : '$cat · ${c.sharePct}%'));
    }
    if (recap.topMerchant != null) {
      final m = recap.topMerchant!;
      rows.add(_statRow('🏪', l10n.wTopMerchant,
          showAmounts && recap.topMerchantAmount != null
              ? '${m.label} · ${_money.format(recap.topMerchantAmount)}'
              : '${m.label} · ${m.sharePct}%'));
    }
    if (recap.spendVsLastMonthPct != null) {
      final p = recap.spendVsLastMonthPct!;
      final down = p <= 0;
      rows.add(_statRow(
        down ? '📉' : '📈',
        l10n.wSpendingVsLastMonth,
        '${down ? '↓' : '↑'} ${p.abs()}%',
        valueColor: down ? _green : _red,
      ));
    }
    if (showAmounts) {
      // Numbers-mode-only insights.
      rows.add(_statRow('📅', l10n.wAvgPerDay, _money.format(recap.avgPerDay)));
      if (recap.biggestTxnAmount != null) {
        rows.add(_statRow('💥', l10n.wBiggestExpense,
            '${recap.biggestTxnLabel ?? ''} · ${_money.format(recap.biggestTxnAmount)}'));
      }
      if (recap.totalIncome > 0) {
        rows.add(_statRow('💰', l10n.commonIncome, _money.format(recap.totalIncome),
            valueColor: _green));
      }
    } else {
      if (recap.netWorthChangePct != null) {
        final p = recap.netWorthChangePct!;
        rows.add(_statRow(
            '💎', l10n.wNetWorth, '${p >= 0 ? '↑' : '↓'} ${p.abs()}%',
            valueColor: p >= 0 ? _green : _red));
      } else if (recap.investedPct != null) {
        rows.add(_statRow(
            '💎', l10n.wInvested, l10n.wInvestedPctOfAssets(recap.investedPct!)));
      }
      if (recap.categoryMover != null) {
        final m = recap.categoryMover!;
        rows.add(_statRow(
            m.icon, l10n.wMover(l10n.categoryName(m.label), m.up),
            '${m.up ? '↑' : '↓'} ${m.changePct.abs()}%',
            valueColor: m.up ? _red : _green));
      }
    }

    // The card is a fixed-height shareable image, so cap the rows: keep the
    // top 5 highlights plus the Activity summary (6 total). Numbers mode adds
    // extra rows and would otherwise overflow into the footer.
    final activity = _statRow('🧾', l10n.wActivity,
        l10n.wActivitySummary(recap.transactionCount, recap.merchantCount));
    final shown = [...rows.take(5), activity];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: shown,
    );
  }

  Widget _statRow(String icon, String label, String value,
      {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
