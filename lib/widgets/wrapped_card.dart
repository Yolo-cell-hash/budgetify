import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/monthly_recap.dart';
import '../providers/theme_provider.dart';
import '../services/gamification_service.dart' show usageTitleFor;
import 'brand_logo.dart';
import 'hero_aura.dart';
import 'royal_avatars.dart';

/// The shareable "Wrapped" poster — a fixed-size (360×640) luxury card that
/// tells the month's story in one glance: hero stat, day-by-day spending
/// rhythm, top categories, and a grid of insights (busiest day, no-spend
/// days, time in app, wealth, activity).
///
/// By default it carries only **percentages, counts and names** (no amounts)
/// so it's safe to post anywhere; [showAmounts] flips it to real ₹ figures.
///
/// The card dresses itself from the active theme's [HeroStyle], so every app
/// theme — and an equipped royal's court dress — restyles it automatically.
/// An equipped [royal] additionally signs the card with a small living seal.
///
/// Motion: [loop] (0→1, seamless period) drives drifting sparks, the border
/// sheen, the hero shimmer, the peak-bar pulse and the royal seal. Drive it
/// with a repeating controller for the live view, step it frame-by-frame for
/// the animated share, or leave the default for a rich static frame.
class WrappedCard extends StatelessWidget {
  final MonthlyRecap recap;

  /// When true, render actual ₹ amounts instead of percentages/shares. Off by
  /// default so the shareable card stays amount-free.
  final bool showAmounts;

  /// Loop phase, 0..1. Every effect is periodic in it, so a GIF capturing
  /// exactly one period loops seamlessly.
  final Animation<double> loop;

  /// The equipped royal, shown as a subtle living seal beside the month
  /// title. Null hides the seal entirely.
  final RoyalAvatar? royal;

  /// Entrance animations (bars growing in). Disable for tests.
  final bool animate;

  const WrappedCard({
    super.key,
    required this.recap,
    this.showAmounts = false,
    this.loop = const AlwaysStoppedAnimation(0.35),
    this.royal,
    this.animate = true,
  });

  static const double width = 360;
  static const double height = 640;

  static final _money =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final hero = HeroStyle.of(context);
    final l10n = context.l10n;

    // The poster is a fixed-size composition — pin the text scale so a large
    // system font can't push it out of frame (it scales as a whole instead).
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedBuilder(
          // Only the thin border chrome rebuilds each tick; the card body is
          // the prebuilt child, its animated leaves repainting on their own.
          animation: loop,
          builder: (context, child) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: SweepGradient(
                colors: [
                  hero.accent.withValues(alpha: 0.22),
                  hero.accent,
                  hero.accent.withValues(alpha: 0.22),
                  hero.accent.withValues(alpha: 0.75),
                  hero.accent.withValues(alpha: 0.22),
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                transform: GradientRotation(loop.value * 2 * math.pi),
              ),
              boxShadow: hero.shadow,
            ),
            child: Padding(padding: const EdgeInsets.all(1.4), child: child),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hero.gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(27),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: Stack(
                children: [
                  if (hero.showAura) HeroAura(color: hero.accent),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SparkFieldPainter(
                        loop: loop,
                        color: royal == null
                            ? hero.accent
                            : Color.lerp(hero.accent,
                                royal!.theme.accentSoft, 0.45)!,
                        seed: recap.month.month * 31 + recap.transactionCount,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                    child: _body(context, hero, l10n),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, HeroStyle hero, AppStrings l10n) {
    final trends = recap.trends;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(hero, l10n),
        const SizedBox(height: 16),
        _monthRow(hero, l10n),
        const SizedBox(height: 14),
        _hero(hero, l10n),
        const SizedBox(height: 14),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              hero.accent.withValues(alpha: 0.0),
              hero.accent.withValues(alpha: 0.45),
              hero.accent.withValues(alpha: 0.0),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (trends != null && trends.peakDay != null) ...[
          _rhythm(hero, l10n, trends),
          const SizedBox(height: 14),
        ],
        if (recap.topCategories.isNotEmpty) _categories(hero, l10n),
        // Twin spacers float the grid between the story above and the
        // footer, so leftover height never pools awkwardly at the bottom.
        const Spacer(),
        _grid(hero, l10n),
        const Spacer(),
        _footer(hero, l10n),
      ],
    );
  }

  // ── Header: brand pill + WRAPPED pill ─────────────────────────────────

  Widget _header(HeroStyle hero, AppStrings l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  hero.accent.withValues(alpha: 0.18),
                  hero.accent.withValues(alpha: 0.06),
                ]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: hero.accent.withValues(alpha: 0.30), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'BUDGETIFY',
                    style: TextStyle(
                      color: hero.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
              decoration: BoxDecoration(
                color: hero.innerFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: hero.innerBorder, width: 0.5),
              ),
              child: Text(
                '✨ WRAPPED',
                style: TextStyle(
                  color: hero.mutedForeground,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Month title + subtitle, with the royal seal on the right ──────────

  Widget _monthRow(HeroStyle hero, AppStrings l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.wrappedCardMonth(recap.month),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hero.foreground,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                l10n.myMonthInReview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hero.foregroundAlpha(0.50),
                  fontSize: 11,
                  letterSpacing: 0.3,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        if (royal != null) _RoyalSeal(royal: royal!, loop: loop),
      ],
    );
  }

  // ── Hero stat + trend pill ─────────────────────────────────────────────

  ({String value, String label, bool negative}) _heroStat(AppStrings l10n) {
    if (showAmounts) {
      return (
        value: _money.format(recap.totalSpent),
        label: l10n.wSpentThisMonth,
        negative: false,
      );
    }
    final rate = recap.savingsRatePct;
    if (rate != null && rate >= 0) {
      return (value: '$rate%', label: l10n.wOfIncomeSaved, negative: false);
    }
    if (rate != null && rate < 0) {
      return (
        value: l10n.wOver,
        label: l10n.wSpentMoreThanEarned,
        negative: true,
      );
    }
    final c = recap.topCategory;
    if (c != null) {
      return (
        value: '${c.sharePct}%',
        label: l10n.wWentTo(l10n.categoryName(c.label).toUpperCase()),
        negative: false,
      );
    }
    return (
      value: '${recap.transactionCount}',
      label: l10n.wTransactionsThisMonth,
      negative: false,
    );
  }

  Widget _hero(HeroStyle hero, AppStrings l10n) {
    final stat = _heroStat(l10n);
    final color = stat.negative ? hero.negative : hero.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: hero.foregroundAlpha(0.75),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _ShimmerText(
              stat.value,
              loop: loop,
              onDark: hero.onDark,
              style: TextStyle(
                color: color,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.6,
                height: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Pills shrink as one strip if a language runs long.
        Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (recap.spendVsLastMonthPct != null)
                  _trendPill(hero, l10n, recap.spendVsLastMonthPct!),
                if (showAmounts && (recap.savingsRatePct ?? -1) >= 0) ...[
                  const SizedBox(width: 6),
                  _pill(
                    hero,
                    text:
                        '${recap.savingsRatePct}% ${l10n.wOfIncomeSaved.toLowerCase()}',
                    color: hero.positive,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _trendPill(HeroStyle hero, AppStrings l10n, int pct) {
    final down = pct <= 0; // spending down vs last month = good
    return _pill(
      hero,
      text: '${down ? '↓' : '↑'} ${pct.abs()}% ${l10n.wVsLastMonth}',
      color: down ? hero.positive : hero.negative,
    );
  }

  Widget _pill(HeroStyle hero, {required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          height: 1.2,
        ),
      ),
    );
  }

  // ── Daily rhythm strip ─────────────────────────────────────────────────

  Widget _rhythm(HeroStyle hero, AppStrings l10n, RecapTrends trends) {
    final peak = trends.peakDay!;
    final peakLabel = showAmounts
        ? '${_money.format(trends.peakDayAmount)} · ${l10n.dayMonth(peak)}'
        : '${l10n.wPeakLabel} · ${l10n.dayMonth(peak)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _caption(hero, l10n.wDailyRhythm),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    peakLabel,
                    style: TextStyle(
                      color: hero.accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 46,
          width: double.infinity,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(recap.month),
            tween: Tween(begin: animate ? 0.0 : 1.0, end: 1.0),
            duration: Duration(milliseconds: animate ? 700 : 0),
            curve: Curves.easeOutCubic,
            builder: (context, grow, _) => CustomPaint(
              painter: _RhythmBarsPainter(
                values: trends.dailySpend,
                peakIndex: peak.day - 1,
                grow: grow,
                loop: loop,
                barColor: hero.foregroundAlpha(0.30),
                restColor: hero.foregroundAlpha(0.12),
                peakColor: hero.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Top categories ─────────────────────────────────────────────────────

  Widget _categories(HeroStyle hero, AppStrings l10n) {
    final cats = recap.topCategories;
    final maxShare =
        cats.fold<int>(1, (m, c) => c.sharePct > m ? c.sharePct : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption(hero, l10n.wTopCategories),
        const SizedBox(height: 9),
        for (var i = 0; i < cats.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          _categoryRow(hero, l10n, cats[i], maxShare),
        ],
      ],
    );
  }

  Widget _categoryRow(
      HeroStyle hero, AppStrings l10n, RecapHighlight c, int maxShare) {
    final value = showAmounts && c.amount != null
        ? _money.format(c.amount)
        : '${c.sharePct}%';
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(c.icon, style: const TextStyle(fontSize: 10.5)),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 108,
          child: Text(
            l10n.categoryName(c.label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hero.foregroundAlpha(0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(height: 4.5, color: hero.foregroundAlpha(0.10)),
                FractionallySizedBox(
                  widthFactor: (c.sharePct / maxShare).clamp(0.04, 1.0),
                  child: Container(
                    height: 4.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        hero.accent,
                        hero.accent.withValues(alpha: 0.55),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 62,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: hero.foreground,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Insight grid ───────────────────────────────────────────────────────

  List<_TileData> _tiles(AppStrings l10n) {
    final trends = recap.trends;
    final tiles = <_TileData>[];

    // Fallbacks queue for slots whose stat is missing this month.
    final extras = <_TileData>[
      if (recap.categoryMover != null)
        _TileData(
          label: l10n.wMover(
              l10n.categoryName(recap.categoryMover!.label),
              recap.categoryMover!.up),
          value:
              '${recap.categoryMover!.up ? '↑' : '↓'} ${recap.categoryMover!.changePct.abs()}%',
          tone: recap.categoryMover!.up ? _Tone.negative : _Tone.positive,
        ),
      if (trends != null)
        _TileData(
          label: l10n.wActiveDays,
          value: '${trends.trackedDays - trends.noSpendDays}',
          sub: l10n.wOfDays(trends.trackedDays),
        ),
      _TileData(
        label: l10n.wActivity,
        value: l10n.nTxns(recap.transactionCount),
      ),
    ];
    _TileData nextExtra() =>
        extras.isEmpty ? _TileData(label: '', value: '—') : extras.removeAt(0);

    // 1 — top merchant.
    final m = recap.topMerchant;
    tiles.add(m == null
        ? nextExtra()
        : _TileData(
            label: l10n.wTopMerchant,
            value: m.label,
            sub: showAmounts && m.amount != null
                ? _money.format(m.amount)
                : l10n.wPctOfSpend(m.sharePct),
          ));

    // 2 — busiest day (by txn count) / avg per day in amounts mode.
    if (showAmounts) {
      tiles.add(_TileData(
          label: l10n.wAvgPerDay, value: _money.format(recap.avgPerDay)));
    } else {
      tiles.add(trends?.busiestDay == null
          ? nextExtra()
          : _TileData(
              label: l10n.wBusiestDay,
              value: l10n.dayMonth(trends!.busiestDay!),
              sub: l10n.nTxns(trends.busiestDayTxns),
            ));
    }

    // 3 — no-spend days / biggest expense in amounts mode.
    if (showAmounts) {
      tiles.add(recap.biggestTxnAmount == null
          ? nextExtra()
          : _TileData(
              label: l10n.wBiggestExpense,
              value: _money.format(recap.biggestTxnAmount),
              sub: recap.biggestTxnLabel,
            ));
    } else {
      tiles.add(trends == null
          ? nextExtra()
          : _TileData(
              label: l10n.wNoSpendDays,
              value: '${trends.noSpendDays}',
              sub: l10n.wOfDays(trends.trackedDays),
            ));
    }

    // 4 — time in app (+ usage title), a non-financial delight.
    if (recap.appTimeSeconds > 0) {
      final title = usageTitleFor(recap.appTimeSeconds / 3600.0);
      tiles.add(_TileData(
        label: l10n.wTimeInApp,
        value: _fmtDuration(recap.appTimeSeconds),
        sub: title == null ? null : '${title.emoji} ${title.name}',
      ));
    } else {
      tiles.add(nextExtra());
    }

    // 5 — wealth: net-worth change, invested share, or income in ₹ mode.
    if (showAmounts && recap.totalIncome > 0) {
      tiles.add(_TileData(
        label: l10n.commonIncome,
        value: _money.format(recap.totalIncome),
        tone: _Tone.positive,
      ));
    } else if (recap.netWorthChangePct != null) {
      final p = recap.netWorthChangePct!;
      tiles.add(_TileData(
        label: l10n.wNetWorth,
        value: '${p >= 0 ? '↑' : '↓'} ${p.abs()}%',
        tone: p >= 0 ? _Tone.positive : _Tone.negative,
      ));
    } else if (recap.investedPct != null) {
      tiles.add(_TileData(
        label: l10n.wInvested,
        value: l10n.wInvestedPctOfAssets(recap.investedPct!),
      ));
    } else {
      tiles.add(nextExtra());
    }

    // 6 — activity.
    tiles.add(_TileData(
      label: l10n.wActivity,
      value: l10n.nTxns(recap.transactionCount),
      sub: l10n.nMerchants(recap.merchantCount),
    ));

    return tiles;
  }

  Widget _grid(HeroStyle hero, AppStrings l10n) {
    final tiles = _tiles(l10n);
    Widget row(int a, int b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _tile(hero, tiles[a])),
              const SizedBox(width: 7),
              Expanded(child: _tile(hero, tiles[b])),
            ],
          ),
        );
    return Column(
      children: [
        row(0, 1),
        const SizedBox(height: 8),
        row(2, 3),
        const SizedBox(height: 8),
        row(4, 5),
      ],
    );
  }

  Widget _tile(HeroStyle hero, _TileData d) {
    final valueColor = switch (d.tone) {
      _Tone.positive => hero.positive,
      _Tone.negative => hero.negative,
      _Tone.neutral => hero.foreground,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: hero.innerFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hero.innerBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            d.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hero.foregroundAlpha(0.55),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                d.value,
                maxLines: 1,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
            ),
          ),
          if (d.sub != null) ...[
            const SizedBox(height: 2),
            Text(
              d.sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hero.foregroundAlpha(0.50),
                fontSize: 8.5,
                letterSpacing: 0.1,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────

  Widget _footer(HeroStyle hero, AppStrings l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: hero.innerFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hero.innerBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline,
              size: 11, color: hero.foregroundAlpha(0.45)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              l10n.privateOnDevice,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hero.foregroundAlpha(0.45),
                fontSize: 9.5,
                letterSpacing: 0.2,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'budgetify.app',
            style: TextStyle(
              color: hero.accent.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _caption(HeroStyle hero, String text) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: hero.foregroundAlpha(0.55),
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        height: 1.25,
      ),
    );
  }

  static String _fmtDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

enum _Tone { neutral, positive, negative }

class _TileData {
  final String label;
  final String value;
  final String? sub;
  final _Tone tone;

  const _TileData({
    required this.label,
    required this.value,
    this.sub,
    this.tone = _Tone.neutral,
  });
}

// ── Animated leaves ───────────────────────────────────────────────────────

/// Gently twinkling sparks orbiting fixed anchor points. Every term is
/// periodic in the loop phase, so a one-period capture loops seamlessly.
class _SparkFieldPainter extends CustomPainter {
  final Animation<double> loop;
  final Color color;
  final int seed;

  _SparkFieldPainter({
    required this.loop,
    required this.color,
    required this.seed,
  }) : super(repaint: loop);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final t = loop.value;
    final paint = Paint();
    for (var i = 0; i < 12; i++) {
      final bx = 16 + rng.nextDouble() * (size.width - 32);
      final by = 70 + rng.nextDouble() * (size.height - 130);
      final orbit = 2.5 + rng.nextDouble() * 4.5;
      final phase = rng.nextDouble();
      final dir = rng.nextBool() ? 1 : -1;
      final a = 2 * math.pi * (t * dir + phase);
      final p = Offset(bx + math.cos(a) * orbit, by + math.sin(a) * orbit);
      final twinkle =
          (math.sin(2 * math.pi * (2 * t + phase)) + 1) / 2; // 0..1
      final alpha = 0.10 + twinkle * 0.30;
      final r = 1.0 + rng.nextDouble() * 1.2 + twinkle * 0.5;
      paint.color = color.withValues(alpha: alpha * 0.4);
      canvas.drawCircle(p, r * 2.4, paint); // soft halo
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(p, r, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkFieldPainter old) =>
      old.color != color || old.seed != seed || old.loop != loop;
}

/// The month's daily-spend bars. The peak bar breathes with the loop; the
/// rest sit quietly. [grow] (0..1) is the entrance sweep, staggered
/// left-to-right.
class _RhythmBarsPainter extends CustomPainter {
  final List<double> values;
  final int peakIndex;
  final double grow;
  final Animation<double> loop;
  final Color barColor;
  final Color restColor;
  final Color peakColor;

  _RhythmBarsPainter({
    required this.values,
    required this.peakIndex,
    required this.grow,
    required this.loop,
    required this.barColor,
    required this.restColor,
    required this.peakColor,
  }) : super(repaint: loop);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final n = values.length;
    const gap = 2.0;
    final barW = (size.width - gap * (n - 1)) / n;
    final maxV = values.fold<double>(0, math.max);
    if (maxV <= 0) return;

    final t = loop.value;
    final paint = Paint();
    for (var i = 0; i < n; i++) {
      // Staggered entrance: each bar starts a touch after its neighbour.
      final local =
          ((grow - i / n * 0.35) / 0.65).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(local);
      final frac = values[i] / maxV;
      final h = frac <= 0 ? 2.0 : (3.0 + frac * (size.height - 3)) * eased;
      final x = i * (barW + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barW, h),
        const Radius.circular(2),
      );
      if (i == peakIndex) {
        final pulse = (math.sin(2 * math.pi * t) + 1) / 2;
        paint.color = Color.lerp(
            peakColor.withValues(alpha: 0.75), peakColor, pulse)!;
        // A soft glow crowns the peak.
        canvas.drawRRect(
          rect,
          Paint()
            ..color = peakColor.withValues(alpha: 0.20 + pulse * 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      } else {
        paint.color = frac <= 0 ? restColor : barColor;
      }
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_RhythmBarsPainter old) =>
      old.values != values ||
      old.grow != grow ||
      old.peakIndex != peakIndex ||
      old.barColor != barColor ||
      old.restColor != restColor ||
      old.peakColor != peakColor;
}

/// Text with a soft sheen band sweeping across once per loop. The band is
/// fully off-glyph at both ends of the period, so the loop has no seam.
class _ShimmerText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Animation<double> loop;
  final bool onDark;

  const _ShimmerText(
    this.text, {
    required this.style,
    required this.loop,
    required this.onDark,
  });

  @override
  Widget build(BuildContext context) {
    final base = Text(text, style: style);
    return AnimatedBuilder(
      animation: loop,
      child: base,
      builder: (context, child) {
        final centre = -1.8 + loop.value * 3.6; // -1.8 → 1.8, off at ends
        final sheen = onDark ? Colors.white : Colors.white.withValues(alpha: 0.9);
        return Stack(
          children: [
            child!,
            // The sheen: same glyphs, masked to a moving highlight band.
            ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(centre - 0.6, -0.4),
                end: Alignment(centre + 0.6, 0.4),
                colors: [
                  sheen.withValues(alpha: 0.0),
                  sheen.withValues(alpha: onDark ? 0.45 : 0.65),
                  sheen.withValues(alpha: 0.0),
                ],
              ).createShader(bounds),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

/// The equipped royal's living seal — a small velvet crest where the royal
/// breathes, blinks and (once per loop) waves. Subtle by design: it signs
/// the card without stealing the show.
class _RoyalSeal extends StatelessWidget {
  final RoyalAvatar royal;
  final Animation<double> loop;

  const _RoyalSeal({required this.royal, required this.loop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: royal.theme.accentSoft.withValues(alpha: 0.55),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: royal.theme.accent.withValues(alpha: 0.28),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(painter: _RoyalSealPainter(royal: royal, loop: loop)),
      ),
    );
  }
}

class _RoyalSealPainter extends CustomPainter {
  final RoyalAvatar royal;
  final Animation<double> loop;

  _RoyalSealPainter({required this.royal, required this.loop})
      : super(repaint: loop);

  @override
  void paint(Canvas canvas, Size size) {
    // Map the loop onto a slice of the royal idle timeline that contains the
    // wave-and-blink beat but starts/ends in an idle pose, so the loop seam
    // is invisible.
    final t = 0.30 + loop.value * 0.25;
    RoyalAvatarPainter(royal: royal, t: t).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_RoyalSealPainter old) =>
      old.royal != royal || old.loop != loop;
}
