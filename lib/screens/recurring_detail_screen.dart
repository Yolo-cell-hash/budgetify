import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/recurring_payment.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/recurring_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/recurring_editor_sheet.dart';
import 'recurring_screen.dart';

/// Full view of one recurring plan: its current cycle, a ledger of past
/// occurrences, and edit / pause / delete actions.
class RecurringDetailScreen extends StatefulWidget {
  final int planId;
  const RecurringDetailScreen({super.key, required this.planId});

  @override
  State<RecurringDetailScreen> createState() => _RecurringDetailScreenState();
}

class _RecurringDetailScreenState extends State<RecurringDetailScreen> {
  final DatabaseService _db = DatabaseService();

  RecurringPayment? _plan;
  RecurringStatusView? _view;
  List<RecurringCharge> _charges = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await _db.getRecurringPayment(widget.planId);
    if (plan == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final charges = await _db.getRecurringCharges(widget.planId);
    final byKey = {for (final c in charges) c.periodKey: c};
    final view = RecurringService.statusViewFor(
        plan, DateTime.now(), (k) => byKey[k]);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _charges = charges;
      _view = view;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final plan = _plan;
    if (plan == null) return;
    final updated = await showRecurringEditor(context, existing: plan);
    if (updated == null) return;
    await _db.updateRecurringPayment(updated);
    await _load();
  }

  Future<void> _togglePause() async {
    final plan = _plan;
    if (plan == null) return;
    await _db.updateRecurringPayment(plan.copyWith(paused: !plan.paused));
    await _load();
  }

  Future<void> _delete() async {
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        accent: AppColors.of(ctx).danger,
        title: context.l10nRead.deleteRecurringTitle,
        subtitle: context.l10nRead.deleteRecurringConfirm,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10nRead.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(ctx).danger,
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10nRead.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteRecurringPayment(widget.planId);
    if (mounted) {
      showAppToast(context,
          message: context.l10nRead.recurringPaymentDeleted,
          type: AppToastType.info);
      Navigator.pop(context);
    }
  }

  String _cadenceLabel(RecurringCadence c) => switch (c) {
        RecurringCadence.weekly => context.l10n.cadenceWeekly,
        RecurringCadence.monthly => context.l10n.cadenceMonthly,
        RecurringCadence.quarterly => context.l10n.cadenceQuarterly,
        RecurringCadence.yearly => context.l10n.cadenceYearly,
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final plan = _plan;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(plan?.name ?? context.l10n.recurringTitle),
        actions: [
          if (plan != null)
            IconButton(
              tooltip: context.l10n.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
          if (plan != null)
            IconButton(
              tooltip: plan.paused
                  ? context.l10n.resumeAction
                  : context.l10n.pauseAction,
              icon: Icon(plan.paused
                  ? Icons.play_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded),
              onPressed: _togglePause,
            ),
          IconButton(
            tooltip: context.l10n.commonDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _delete,
          ),
        ],
      ),
      body: _loading || plan == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _summaryCard(colors, plan),
                const SizedBox(height: 20),
                Text(context.l10n.recurringHistoryTitle.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: colors.textTertiary)),
                const SizedBox(height: 10),
                if (_charges.isEmpty)
                  Text('—',
                      style: TextStyle(color: colors.textTertiary, fontSize: 13))
                else
                  for (final c in _charges) _historyRow(colors, c),
              ],
            ),
    );
  }

  Widget _summaryCard(AppColors colors, RecurringPayment plan) {
    final view = _view;
    final statusColor = view == null
        ? colors.textTertiary
        : recurringStatusColor(colors, view.state);
    final amount = plan.amount;
    final due = DateFormat('EEE, d MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(ExpenseCategories.getIcon(plan.category),
                    style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrivacyAmount(
                      amount == null
                          ? context.l10n.amountVariesShort
                          : recurringFmt.format(amount),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_cadenceLabel(plan.cadence)} · ${context.l10n.categoryName(plan.category)}',
                      style:
                          TextStyle(fontSize: 12.5, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(
                plan.paused
                    ? context.l10n.pausedLabel
                    : (view == null ? '' : recurringStatusText(context, view)),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: plan.paused ? colors.textTertiary : statusColor),
              ),
              const Spacer(),
              if (!plan.paused && view?.dueDate != null)
                Text(due.format(view!.dueDate!),
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyRow(AppColors colors, RecurringCharge c) {
    final (label, color) = switch (c.status) {
      RecurringChargeStatus.skipped => (
          context.l10n.recurringSkippedLabel,
          colors.textTertiary
        ),
      RecurringChargeStatus.detected => (
          context.l10n.recurringPaidLabel,
          colors.success
        ),
      RecurringChargeStatus.confirmed => (
          context.l10n.recurringPaidLabel,
          colors.success
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(DateFormat('d MMM yyyy').format(c.dueDate),
                style: TextStyle(fontSize: 13.5, color: colors.text)),
          ),
          if (c.status == RecurringChargeStatus.detected)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.bolt_rounded, size: 14, color: colors.accent),
            ),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(width: 12),
          if (c.status != RecurringChargeStatus.skipped)
            PrivacyAmount(recurringFmt.format(c.amount),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.text)),
        ],
      ),
    );
  }
}
