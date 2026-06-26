import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/savings_goal_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/goal_editor_sheet.dart';
import '../widgets/goal_jar.dart';
import '../widgets/privacy_amount.dart';
import 'goal_detail_screen.dart';

final NumberFormat goalFmt =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// One-line status for a goal (shared with the Home card).
String goalStatusText(GoalView v) {
  final p = v.progress;
  if (p.isComplete) return 'Completed 🎉';
  if (p.isOverdue) return 'Past deadline · ${goalFmt.format(p.remaining)} to go';
  if (p.neededPerMonth != null) {
    return '${goalFmt.format(p.neededPerMonth!)}/mo · ${p.daysLeft}d left';
  }
  return '${goalFmt.format(p.remaining)} to go';
}

/// Compact dashboard card summarising savings goals (top jars), or an invite
/// to create one. Self-loading; taps through to the full Goals screen.
class HomeGoalsCard extends StatefulWidget {
  const HomeGoalsCard({super.key});

  @override
  State<HomeGoalsCard> createState() => _HomeGoalsCardState();
}

class _HomeGoalsCardState extends State<HomeGoalsCard> {
  final SavingsGoalService _svc = SavingsGoalService();
  List<GoalView>? _goals;

  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final g = await _svc.goalsWithProgress();
    if (mounted) setState(() => _goals = g);
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final goals = _goals;
    if (goals == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _open,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: goals.isEmpty
                ? Row(
                    children: [
                      const GoalJar(fraction: 0.4, accent: 4, size: 44, showPercent: false),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n.savingsGoalsTitle,
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700, color: colors.text)),
                            const SizedBox(height: 2),
                            Text(context.l10n.goalsSubtitle,
                                style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(context.l10n.savingsGoalsTitle,
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: colors.text)),
                          const Spacer(),
                          Text(context.l10n.seeAllLower,
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: colors.brandAccent)),
                          Icon(Icons.chevron_right_rounded, size: 18, color: colors.brandAccent),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (final v in goals.take(3))
                            Expanded(
                              child: Column(
                                children: [
                                  GoalJar(fraction: v.progress.fraction, accent: v.goal.accent, size: 56),
                                  const SizedBox(height: 6),
                                  Text(v.goal.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final SavingsGoalService _svc = SavingsGoalService();
  List<GoalView>? _goals;

  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final g = await _svc.goalsWithProgress();
    if (mounted) setState(() => _goals = g);
  }

  Future<void> _newGoal() async {
    final g = await showGoalEditor(context);
    if (g != null) {
      await _svc.createGoal(g);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final goals = _goals;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: AppBarTitle(context.l10n.savingsGoalsTitle,
            icon: Icons.savings_rounded),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newGoal,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.newGoal),
      ),
      body: goals == null
          ? const Center(child: CircularProgressIndicator())
          : goals.isEmpty
              ? _empty(colors)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _goalCard(colors, goals[i]),
                ),
    );
  }

  Widget _empty(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoalJar(fraction: 0.35, accent: 4, size: 110, showPercent: false),
            const SizedBox(height: 20),
            Text(context.l10n.setFirstGoal,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.text)),
            const SizedBox(height: 8),
            Text(
              context.l10n.setFirstGoalDesc,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalCard(AppColors colors, GoalView v) {
    final g = v.goal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: g.id!)),
          );
          _load();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: v.progress.isComplete
                    ? colors.success.withValues(alpha: 0.5)
                    : colors.border),
          ),
          child: Row(
            children: [
              GoalJar(fraction: v.progress.fraction, accent: g.accent, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(g.emoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: colors.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    PrivacyAmount(
                      '${goalFmt.format(v.saved)} of ${goalFmt.format(g.targetAmount)}',
                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      goalStatusText(v),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: v.progress.isComplete
                            ? colors.success
                            : (v.progress.isOverdue ? colors.danger : colors.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
