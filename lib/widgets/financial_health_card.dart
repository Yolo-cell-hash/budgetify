import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import '../services/financial_health_service.dart';
import 'app_dialog.dart';

/// Design-system colour for a health band. On a dark surface ([onDark], e.g. the
/// balance card) the band tracks the active [hero] so the gauge stays tuned to
/// the reward themes' coloured heroes (instead of a stray champagne gold / dull
/// green); on a normal card the theme-aware palette is used. [hero] is only
/// consulted when [onDark]; pass it from any hero surface.
Color healthBandColor(
  HealthBand band, {
  required bool onDark,
  required AppColors colors,
  HeroStyle? hero,
}) =>
    switch (band) {
      HealthBand.excellent =>
        onDark ? (hero?.positive ?? AppColors.successDark) : colors.success,
      HealthBand.good => onDark ? (hero?.accent ?? AppColors.gold) : colors.brandAccent,
      HealthBand.fair => const Color(0xFFD79A3C),
      HealthBand.needsWork =>
        onDark ? const Color(0xFFE0904A) : const Color(0xFFD2772F),
      HealthBand.atRisk =>
        onDark ? (hero?.negative ?? AppColors.dangerDark) : colors.danger,
    };

Color _scoreColor(
  double score, {
  required bool onDark,
  required AppColors colors,
  HeroStyle? hero,
}) =>
    healthBandColor(FinancialHealth.bandFor(score),
        onDark: onDark, colors: colors, hero: hero);

/// Dashboard card for the **Financial Health Score** — a single 0–100 number
/// (100 healthy, 0 poor) blending savings rate, budget adherence, recurring
/// load and net worth. Presentational: the score is computed once by the home
/// screen and passed in, so this card and the compact [FinancialHealthInline]
/// always agree and both refresh the moment the underlying data changes.
class FinancialHealthCard extends StatelessWidget {
  final FinancialHealth health;

  const FinancialHealthCard({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasScore = health.hasScore;
    final accent = hasScore
        ? _scoreColor(health.scoreValue!, onDark: false, colors: colors)
        : colors.textTertiary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, colors),
          const SizedBox(height: 16),
          if (!hasScore)
            _emptyState(context, colors)
          else
            _scored(context, colors, accent),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AppColors colors) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: colors.brandAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.monitor_heart_outlined,
              size: 18, color: colors.brandAccent),
        ),
        const SizedBox(width: 10),
        Text(
          context.l10n.financialHealth,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: colors.text,
          ),
        ),
        const Spacer(),
        // Subtle "tooltip": long-press shows the native hint; a tap opens the
        // full, plain-language breakdown of how the score is calculated.
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: context.l10n.howScoreCalculated,
          icon: Icon(Icons.info_outline_rounded,
              size: 18, color: colors.textTertiary),
          onPressed: () => showFinancialHealthExplainer(context, health),
        ),
      ],
    );
  }

  Widget _scored(BuildContext context, AppColors colors, Color accent) {
    final score = health.score!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _HealthGauge(
              score: score,
              fraction: score / 100,
              color: accent,
              track: colors.border,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    health.band.label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    health.band.caption,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _pillar(colors, context.l10n.mSavingsRate, health.savingsScore),
        const SizedBox(height: 12),
        _pillar(colors, context.l10n.budgetAdherence, health.budgetScore),
        const SizedBox(height: 12),
        _pillar(colors, context.l10n.recurringLoad, health.recurringScore),
        const SizedBox(height: 12),
        _pillar(colors, context.l10n.netWorthWord, health.netWorthScore),
      ],
    );
  }

  /// One labelled pillar: name, sub-score (or "—" when not yet available) and a
  /// thin bar coloured by its own band.
  Widget _pillar(AppColors colors, String label, double? score) {
    final available = score != null;
    final color =
        available ? _scoreColor(score, onDark: false, colors: colors) : colors.textTertiary;
    final fraction = available ? (score / 100).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: available ? colors.text : colors.textTertiary,
                ),
              ),
            ),
            Text(
              available ? score.round().toString() : '—',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: available ? color : colors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 6, color: colors.border),
              if (available)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        context.l10n.healthEmptyDesc,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

/// Compact one-line Financial Health indicator ("FINANCIAL HEALTH  72/100"),
/// shown on the balance card under the savings-rate bar when the full card is
/// turned off. Renders nothing when there's no score yet. Tapping the ⓘ opens
/// the same explainer as the full card.
class FinancialHealthInline extends StatelessWidget {
  final FinancialHealth health;
  final bool onDark;

  const FinancialHealthInline({
    super.key,
    required this.health,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (!health.hasScore) return const SizedBox.shrink();

    final hero = onDark ? HeroStyle.of(context) : null;
    final score = health.score!;
    final color = _scoreColor(health.scoreValue!,
        onDark: onDark, colors: colors, hero: hero);
    final labelColor = onDark ? hero!.accent : colors.textSecondary;
    final muted =
        onDark ? Colors.white.withValues(alpha: 0.55) : colors.textTertiary;

    return Row(
      children: [
        Text(
          context.l10n.financialHealthUpper,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const Spacer(),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: color,
          ),
        ),
        Text(
          '/100',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showFinancialHealthExplainer(context, health),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(Icons.info_outline_rounded, size: 15, color: muted),
          ),
        ),
      ],
    );
  }
}

/// Plain-language popup explaining how the score is calculated, with each
/// pillar's weight and current sub-score. Shared by the full card and the
/// compact indicator so the "how it works" detail is reachable from both.
void showFinancialHealthExplainer(BuildContext context, FinancialHealth h) {
  final colors = AppColors.of(context);
  showAppDialog(
    context,
    builder: (_) => AppDialog(
      icon: Icons.monitor_heart_outlined,
      title: context.l10nRead.howScoreWorks,
      subtitle: context.l10nRead.howScoreWorksDesc,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _explainRow(colors, context.l10nRead.mSavingsRate, '35%',
              context.l10nRead.savingsRateExplain, h.savingsScore),
          _explainRow(colors, context.l10nRead.budgetAdherence, '25%',
              context.l10nRead.budgetAdherenceExplain, h.budgetScore),
          _explainRow(colors, context.l10nRead.recurringLoad, '20%',
              context.l10nRead.recurringLoadExplain, h.recurringScore),
          _explainRow(colors, context.l10nRead.netWorthWord, '20%',
              context.l10nRead.netWorthExplain, h.netWorthScore),
          const SizedBox(height: 4),
          Text(
            context.l10nRead.computedOnDevice,
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10nRead.gotIt),
        ),
      ],
    ),
  );
}

Widget _explainRow(
  AppColors colors,
  String name,
  String weight,
  String desc,
  double? score,
) {
  final available = score != null;
  final color =
      available ? _scoreColor(score, onDark: false, colors: colors) : colors.textTertiary;
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ),
                  Text(
                    available ? '${score.round()} · $weight' : '— · $weight',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: available ? color : colors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A 270° arc gauge with the score counting up in its centre as the arc fills.
class _HealthGauge extends StatelessWidget {
  final int score;
  final double fraction; // 0..1
  final Color color;
  final Color track;

  const _HealthGauge({
    required this.score,
    required this.fraction,
    required this.color,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: 104,
      height: 104,
      child: TweenAnimationBuilder<double>(
        // A single 0→1 progress drives both the arc fill and the count-up so
        // they stay in sync and land on the true score (not score × fraction).
        tween: Tween(begin: 0, end: 1.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) {
          final shown = (score * t).round();
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(104, 104),
                painter: _GaugePainter(
                  fraction: fraction.clamp(0.0, 1.0) * t,
                  color: color,
                  track: track,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$shown',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      color: color,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction; // 0..1
  final Color color;
  final Color track;

  const _GaugePainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  // A 270° sweep starting bottom-left, leaving a 90° gap at the bottom.
  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;
  static const double _stroke = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _stroke / 2,
      _stroke / 2,
      size.width - _stroke,
      size.height - _stroke,
    );

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _start, _sweep, false, bg);

    if (fraction > 0) {
      final fg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, _start, _sweep * fraction.clamp(0.0, 1.0), false, fg);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
