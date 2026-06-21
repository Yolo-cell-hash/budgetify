import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_preferences.dart';
import '../providers/theme_provider.dart';
import '../screens/insights_screen.dart';
import '../services/insights_service.dart';
import 'motion.dart';
import 'privacy_amount.dart';

/// On-device spending forecast + insights, shown only when AI Prediction
/// Mode is enabled (the caller gates this). Self-contained: loads its own
/// data and renders nothing intrusive — a single card matching the app's
/// design language. Read-only; respects privacy mode for figures.
class InsightsCard extends StatefulWidget {
  /// Bumped by the parent (via key or this token) to trigger a reload when
  /// underlying data changes.
  final int reloadToken;

  const InsightsCard({super.key, this.reloadToken = 0});

  @override
  State<InsightsCard> createState() => _InsightsCardState();
}

class _InsightsCardState extends State<InsightsCard> {
  final InsightsService _service = InsightsService();
  InsightsResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(InsightsCard old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) _load();
  }

  Future<void> _load() async {
    final result = await _service.compute();
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final r = _result;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InsightsScreen()),
      ),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights_rounded,
                    size: 18, color: AppColors.goldDeep),
              ),
              const SizedBox(width: 10),
              Text(
                'Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldDeep,
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.goldDeep),
            ],
          ),
          const SizedBox(height: 14),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (r == null || r.isEmpty)
            _emptyState(colors, r?.hasHistory ?? false)
          else ...[
            if (r.forecast != null) _forecast(colors, r.forecast!),
            if (r.forecast != null && r.insights.isNotEmpty)
              const SizedBox(height: 16),
            for (var i = 0; i < r.insights.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              FadeSlideIn(order: i, child: _insightRow(colors, r.insights[i])),
            ],
          ],
        ],
      ),
      ),
    );
  }

  Widget _emptyState(AppColors colors, bool hasHistory) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        hasHistory
            ? 'No spending yet this month — insights will appear as you spend.'
            : 'Building your baseline. Insights and forecasts sharpen after a '
                'few weeks of activity.',
        style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.4),
      ),
    );
  }

  Widget _forecast(AppColors colors, SpendingForecast f) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final overUnder = f.projectedVsBudget;
    final hidden = context.select<AppPreferences, bool>((p) => p.amountsHidden);
    final hero = HeroStyle.of(context);
    final spentLine = 'Day ${f.daysElapsed} of ${f.daysInMonth} · '
        '${fmt.format(f.spentSoFar)} spent so far';
    final tone = overUnder != null && overUnder > 0 ? colors.danger : colors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: hero.gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hero.border),
        boxShadow: hero.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROJECTED THIS MONTH',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w600,
              color: hero.accent,
            ),
          ),
          const SizedBox(height: 6),
          PrivacyAnimatedAmount(
            value: f.projected,
            formatter: fmt,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: hero.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hidden ? maskRupeeFigures(spentLine) : spentLine,
            style: TextStyle(
              fontSize: 11.5,
              color: hero.mutedForeground,
            ),
          ),
          if (overUnder != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    overUnder > 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 15,
                    color: tone,
                  ),
                  const SizedBox(width: 6),
                  PrivacyAmount(
                    overUnder > 0
                        ? '${fmt.format(overUnder)} over budget'
                        : '${fmt.format(-overUnder)} under budget',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tone,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (f.safeToSpendPerDay != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Safe to spend: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: hero.mutedForeground,
                  ),
                ),
                PrivacyAmount(
                  '${fmt.format(f.safeToSpendPerDay!)}/day',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: hero.accent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightRow(AppColors colors, Insight insight) {
    final hidden = context.select<AppPreferences, bool>((p) => p.amountsHidden);
    final title = hidden ? maskRupeeFigures(insight.title) : insight.title;
    final detail = hidden ? maskRupeeFigures(insight.detail) : insight.detail;
    final accent = switch (insight.tone) {
      InsightTone.positive => AppColors.successLight,
      InsightTone.caution => const Color(0xFFD79A3C),
      InsightTone.alert => AppColors.dangerLight,
      InsightTone.neutral => colors.textSecondary,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(insight.icon, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
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
    );
  }
}
