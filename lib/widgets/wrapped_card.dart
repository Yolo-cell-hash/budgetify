import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/monthly_recap.dart';
import '../providers/theme_provider.dart';

/// The shareable "Wrapped" card — a fixed-size (360×640) luxury card rendered
/// off the app's hero gradient, carrying only **percentages, counts and
/// names** (no amounts) so it's safe to post to WhatsApp / Instagram.
///
/// Fixed dimensions keep the captured image crisp and consistent regardless
/// of device.
class WrappedCard extends StatelessWidget {
  final MonthlyRecap recap;

  const WrappedCard({super.key, required this.recap});

  static const double width = 360;
  static const double height = 640;

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
    final monthLabel = DateFormat('MMMM yyyy').format(recap.month);

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
                          children: [
                            Text(
                              '✦',
                              style: TextStyle(
                                color: _gold,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
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
                    'My month in review',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 24),
                  _hero(),
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

                  Expanded(child: _stats()),

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
                          'Private & on-device',
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

  /// Big hero stat: savings rate when available, otherwise the top category.
  Widget _hero() {
    final rate = recap.savingsRatePct;
    if (rate != null && rate >= 0) {
      return _heroBlock('$rate%', 'OF INCOME SAVED', _gold);
    }
    if (rate != null && rate < 0) {
      return _heroBlock('Over', 'SPENT MORE THAN EARNED', _red);
    }
    final c = recap.topCategory;
    if (c != null) {
      return _heroBlock(
          '${c.sharePct}%', 'WENT TO ${c.label.toUpperCase()}', _gold);
    }
    return _heroBlock(
        '${recap.transactionCount}', 'TRANSACTIONS THIS MONTH', _gold);
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
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 64,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
                height: 1.0,
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

  Widget _stats() {
    final rows = <Widget>[];

    if (recap.topCategory != null) {
      rows.add(_statRow('🍔', 'Top category',
          '${recap.topCategory!.label} · ${recap.topCategory!.sharePct}%'));
    }
    if (recap.topMerchant != null) {
      rows.add(_statRow('🏪', 'Top merchant',
          '${recap.topMerchant!.label} · ${recap.topMerchant!.sharePct}%'));
    }
    if (recap.spendVsLastMonthPct != null) {
      final p = recap.spendVsLastMonthPct!;
      final down = p <= 0;
      rows.add(_statRow(
        down ? '📉' : '📈',
        'Spending vs last month',
        '${down ? '↓' : '↑'} ${p.abs()}%',
        valueColor: down ? _green : _red,
      ));
    }
    if (recap.netWorthChangePct != null) {
      final p = recap.netWorthChangePct!;
      rows.add(_statRow(
          '💎', 'Net worth', '${p >= 0 ? '↑' : '↓'} ${p.abs()}%',
          valueColor: p >= 0 ? _green : _red));
    } else if (recap.investedPct != null) {
      rows.add(_statRow('💎', 'Invested', '${recap.investedPct}% of assets'));
    }
    if (recap.categoryMover != null) {
      final m = recap.categoryMover!;
      rows.add(_statRow(
          m.icon, '${m.label} ${m.up ? 'up' : 'down'}',
          '${m.up ? '↑' : '↓'} ${m.changePct.abs()}%',
          valueColor: m.up ? _red : _green));
    }
    rows.add(_statRow('🧾', 'Activity',
        '${recap.transactionCount} txns · ${recap.merchantCount} merchants'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: rows,
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
