import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/savings_goal.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/notification_service.dart';
import '../services/savings_goal_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/contribution_sheet.dart';
import '../widgets/goal_editor_sheet.dart';
import '../widgets/goal_jar.dart';
import '../widgets/privacy_amount.dart';

class GoalDetailScreen extends StatefulWidget {
  final int goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final SavingsGoalService _svc = SavingsGoalService();
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  GoalView? _view;
  List<GoalContribution> _contributions = const [];

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
    final v = await _svc.goalView(widget.goalId);
    final c = await _svc.contributions(widget.goalId);
    if (mounted) setState(() {
      _view = v;
      _contributions = c;
    });
  }

  Future<void> _addContribution() async {
    final v = _view;
    if (v == null) return;
    final input = await showContributionSheet(context, remaining: v.progress.remaining);
    if (input == null) return;
    final completed = await _svc.addContribution(
      goalId: widget.goalId,
      amount: input.amount,
      date: input.date,
      note: input.note,
    );
    await _load();
    if (completed != null && mounted) _celebrate(completed);
  }

  void _celebrate(SavingsGoal g) {
    // A tray notification (so it's not missed) + an in-app celebration.
    NotificationService().showGoalAchieved(name: g.name, amount: g.targetAmount);
    showAppDialog(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.emoji_events_rounded,
        title: context.l10nRead.goalReachedTitle,
        subtitle: context.l10nRead
            .goalReachedMsg(_fmt.format(g.targetAmount), g.name),
        content: Center(child: GoalJar(fraction: 1, accent: g.accent, size: 120)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10nRead.niceExclaim)),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    final v = _view;
    if (v == null) return;
    final edited = await showGoalEditor(context, existing: v.goal);
    if (edited != null) {
      await _svc.updateGoal(edited);
      _load();
    }
  }

  Future<void> _delete() async {
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        accent: AppColors.dangerLight,
        title: context.l10nRead.deleteGoalTitle,
        subtitle: context.l10nRead.deleteGoalConfirm,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10nRead.commonCancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10nRead.commonDelete)),
        ],
      ),
    );
    if (ok == true) {
      await _svc.deleteGoal(widget.goalId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final v = _view;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(v?.goal.name ?? context.l10n.goalLabel),
        actions: [
          IconButton(onPressed: v == null ? null : _edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: v == null ? null : _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const SizedBox(height: 8),
                Center(child: GoalJar(fraction: v.progress.fraction, accent: v.goal.accent, size: 150)),
                const SizedBox(height: 16),
                Center(
                  child: PrivacyAmount(
                    context.l10n.budgetSpentOf(_fmt.format(v.saved),
                        _fmt.format(v.goal.targetAmount)),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.text),
                  ),
                ),
                const SizedBox(height: 16),
                _statusCard(colors, v),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: v.progress.isComplete ? null : _addContribution,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(v.progress.isComplete
                        ? context.l10n.goalComplete
                        : context.l10n.addToGoal),
                  ),
                ),
                const SizedBox(height: 24),
                Text(context.l10n.contributionsLabel,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.text)),
                const SizedBox(height: 8),
                if (_contributions.isEmpty)
                  Text(context.l10n.noContributionsYet,
                      style: TextStyle(fontSize: 13, color: colors.textSecondary))
                else
                  ..._contributions.map((c) => _contributionRow(colors, c)),
              ],
            ),
    );
  }

  Widget _statusCard(AppColors colors, GoalView v) {
    final p = v.progress;
    final rows = <Widget>[];
    void add(String k, String val, {Color? color}) => rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(k, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
              const Spacer(),
              Text(val,
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700, color: color ?? colors.text)),
            ],
          ),
        ));

    add(context.l10n.progressLabel, '${(p.fraction * 100).round()}%');
    if (!p.isComplete) {
      add(context.l10n.remainingLabel, _fmt.format(p.remaining));
    }
    if (v.goal.deadline != null) {
      add(context.l10n.deadlineLabel, context.l10n.mediumDate(v.goal.deadline!),
          color: p.isOverdue ? colors.danger : null);
    }
    if (p.neededPerMonth != null) {
      add(context.l10n.toStayOnTrack,
          context.l10n.perMonthValue(_fmt.format(p.neededPerMonth!)));
    }
    if (p.isComplete) {
      add(context.l10n.statusLabel, context.l10n.completedStatus,
          color: colors.success);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(children: rows),
    );
  }

  Widget _contributionRow(AppColors colors, GoalContribution c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.add_rounded, size: 18, color: colors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('d MMM yyyy').format(c.date),
                    style: TextStyle(fontSize: 13.5, color: colors.text)),
                if (c.note != null && c.note!.isNotEmpty)
                  Text(c.note!, style: TextStyle(fontSize: 12, color: colors.textTertiary)),
              ],
            ),
          ),
          PrivacyAmount('+ ${_fmt.format(c.amount)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.success)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await _svc.deleteContribution(c.id!);
              _load();
            },
            icon: Icon(Icons.close_rounded, size: 16, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}
