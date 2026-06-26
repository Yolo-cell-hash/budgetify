import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/recurring_payment.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../screens/recurring_screen.dart';
import '../services/app_events.dart';
import '../services/recurring_service.dart';
import 'privacy_amount.dart';

/// Home dashboard card surfacing the next bills due (overdue highlighted), or
/// nothing at all when the user tracks no recurring payments — so it never
/// clutters a dashboard for someone who doesn't use the feature.
class UpcomingRecurringCard extends StatefulWidget {
  const UpcomingRecurringCard({super.key});

  @override
  State<UpcomingRecurringCard> createState() => _UpcomingRecurringCardState();
}

class _UpcomingRecurringCardState extends State<UpcomingRecurringCard> {
  final RecurringService _svc = RecurringService();
  List<RecurringStatusView>? _due;

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
    await _svc.reconcile();
    final due = await _svc.upcomingAndOverdue(withinDays: 14);
    if (mounted) setState(() => _due = due);
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecurringScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final due = _due;
    if (due == null || due.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final hasOverdue =
        due.any((v) => v.state == RecurringDueState.overdue);

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
              border: Border.all(
                color: hasOverdue
                    ? colors.danger.withValues(alpha: 0.45)
                    : colors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.autorenew_rounded,
                        size: 16, color: colors.accent),
                    const SizedBox(width: 8),
                    Text(context.l10n.upcomingBillsTitle,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.text)),
                    const Spacer(),
                    Text(context.l10n.seeAllLower,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.brandAccent)),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: colors.brandAccent),
                  ],
                ),
                const SizedBox(height: 12),
                for (final v in due.take(3)) _row(colors, v),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(AppColors colors, RecurringStatusView v) {
    final statusColor = recurringStatusColor(colors, v.state);
    final amount = v.displayAmount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(ExpenseCategories.getIcon(v.plan.category),
              style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.text)),
                Text(recurringStatusText(context, v),
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ],
            ),
          ),
          if (amount != null)
            PrivacyAmount(recurringFmt.format(amount),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.text)),
        ],
      ),
    );
  }
}
