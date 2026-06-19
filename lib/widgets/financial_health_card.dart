import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';
import '../services/financial_health_service.dart';
import 'app_dialog.dart';

/// Dashboard card for the **Financial Health Score** — a single 0–100 number
/// (100 healthy, 0 poor) blended from savings rate, budget adherence,
/// recurring load and net worth. Self-contained: given this month's income and
/// expenses (so the savings pillar matches the savings-rate bar above it), it
/// loads the remaining pillars and renders an animated gauge, a per-pillar
/// breakdown and a tap-through explanation of how the score is calculated.
class FinancialHealthCard extends StatefulWidget {
  final double income;
  final double expenses;

  /// Bumped by the parent when underlying data changes, to trigger a reload.
  final int reloadToken;

  /// Injectable for tests; defaults to a database-backed service.
  @visibleForTesting
  final FinancialHealthService? service;

  const FinancialHealthCard({
    super.key,
    required this.income,
    required this.expenses,
    this.reloadToken = 0,
    this.service,
  });

  @override
  State<FinancialHealthCard> createState() => _FinancialHealthCardState();
}

class _FinancialHealthCardState extends State<FinancialHealthCard> {
  late final FinancialHealthService _service =
      widget.service ?? FinancialHealthService();
  FinancialHealth? _health;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FinancialHealthCard old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken ||
        old.income != widget.income ||
        old.expenses != widget.expenses) {
      _load();
    }
  }

  Future<void> _load() async {
    final health = await _service.compute(
      income: widget.income,
      expenses: widget.expenses,
    );
    if (!mounted) return;
    setState(() {
      _health = health;
      _loading = false;
    });
  }

  /// Map a 0–100 value to the design-system colour for its band.
  Color _bandColor(HealthBand band, AppColors colors) => switch (band) {
        HealthBand.excellent => colors.success,
        HealthBand.good => AppColors.gold,
        HealthBand.fair => const Color(0xFFD79A3C),
        HealthBand.needsWork => const Color(0xFFD2772F),
        HealthBand.atRisk => colors.danger,
      };

  Color _scoreColor(double score, AppColors colors) =>
      _bandColor(FinancialHealth.bandFor(score), colors);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final h = _health;
    final hasScore = h?.hasScore ?? false;
    final scoreValue = h?.scoreValue ?? 0;
    final accent = hasScore ? _scoreColor(scoreValue, colors) : colors.textTertiary;

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
          _header(colors, h),
          const SizedBox(height: 16),
          if (_loading)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!hasScore)
            _emptyState(colors)
          else
            _scored(colors, h!, accent),
        ],
      ),
    );
  }

  Widget _header(AppColors colors, FinancialHealth? h) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.monitor_heart_outlined,
              size: 18, color: AppColors.goldDeep),
        ),
        const SizedBox(width: 10),
        Text(
          'Financial Health',
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
          tooltip: 'How your score is calculated',
          icon: Icon(Icons.info_outline_rounded,
              size: 18, color: colors.textTertiary),
          onPressed: h == null ? null : () => _showExplainer(h),
        ),
      ],
    );
  }

  Widget _scored(AppColors colors, FinancialHealth h, Color accent) {
    final score = h.score!;
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
                    h.band.label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    h.band.caption,
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
        _pillar(colors, 'Savings rate', h.savingsScore),
        const SizedBox(height: 12),
        _pillar(colors, 'Budget adherence', h.budgetScore),
        const SizedBox(height: 12),
        _pillar(colors, 'Recurring load', h.recurringScore),
        const SizedBox(height: 12),
        _pillar(colors, 'Net worth', h.netWorthScore),
      ],
    );
  }

  /// One labelled pillar: name, sub-score (or "—" when not yet available) and a
  /// thin bar coloured by its own band.
  Widget _pillar(AppColors colors, String label, double? score) {
    final available = score != null;
    final color = available ? _scoreColor(score, colors) : colors.textTertiary;
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

  Widget _emptyState(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'Add some income, a budget, or holdings and your Financial Health '
        'Score will appear here.',
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  void _showExplainer(FinancialHealth h) {
    final colors = AppColors.of(context);
    showAppDialog(
      context,
      builder: (_) => AppDialog(
        icon: Icons.monitor_heart_outlined,
        title: 'How your score works',
        subtitle:
            'A single 0–100 number (100 is healthy, 0 is poor) blended from up '
            'to four pillars. Pillars without data yet are skipped and the rest '
            'reweighted, so the score always reflects what we can see.',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _explainRow(colors, 'Savings rate', '35%',
                'How much of your income you keep. 20% or more earns full marks.',
                h.savingsScore),
            _explainRow(colors, 'Budget adherence', '25%',
                'Staying within the budgets you set. Going over costs points.',
                h.budgetScore),
            _explainRow(colors, 'Recurring load', '20%',
                'Recurring commitments (SIPs/RDs) versus income — more headroom scores higher.',
                h.recurringScore),
            _explainRow(colors, 'Net worth', '20%',
                'Your equity — assets versus debts. Counts only if you track holdings.',
                h.netWorthScore),
            const SizedBox(height: 4),
            Text(
              'Everything is computed on your device.',
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
            child: const Text('Got it'),
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
    final color = available ? _scoreColor(score, colors) : colors.textTertiary;
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
