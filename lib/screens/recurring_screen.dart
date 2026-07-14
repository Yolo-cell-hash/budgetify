import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../models/recurring_payment.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/database_service.dart';
import '../services/recurring_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_toast.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/recurring_editor_sheet.dart';
import 'recurring_detail_screen.dart';

final NumberFormat recurringFmt =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// One-line due/status text for a recurring plan (shared with the Home card).
String recurringStatusText(BuildContext context, RecurringStatusView v) {
  final l10n = context.l10n;
  final d = v.daysUntilDue;
  switch (v.state) {
    case RecurringDueState.overdue:
      return l10n.overdueByDays(d == null ? 0 : -d);
    case RecurringDueState.dueToday:
      return l10n.dueTodayLabel;
    case RecurringDueState.upcoming:
      return l10n.dueInDays(d ?? 0);
    case RecurringDueState.paid:
      return l10n.recurringPaidLabel;
    case RecurringDueState.skipped:
      return l10n.recurringSkippedLabel;
    case RecurringDueState.none:
      return '';
  }
}

/// Accent for a due state, themed across all four palettes.
Color recurringStatusColor(AppColors colors, RecurringDueState s) =>
    switch (s) {
      RecurringDueState.overdue => colors.danger,
      RecurringDueState.dueToday => colors.accent,
      RecurringDueState.upcoming => colors.textSecondary,
      RecurringDueState.paid => colors.success,
      RecurringDueState.skipped => colors.textTertiary,
      RecurringDueState.none => colors.textTertiary,
    };

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final RecurringService _svc = RecurringService();
  final DatabaseService _db = DatabaseService();

  List<RecurringStatusView>? _views;
  List<RecurringPayment> _paused = const [];
  List<RecurringCandidate> _candidates = const [];
  double _monthlyCommitment = 0;

  // Merchants the user has dismissed from the "Looks recurring" suggestions,
  // so they don't keep reappearing. Persisted across launches.
  static const String _dismissedKey = 'recurring_dismissed_suggestions_v1';
  Set<String> _dismissedSuggestions = {};

  // Guided-tour anchors: the screen title and the Add button.
  final GlobalKey _tutTitleKey = GlobalKey();
  final GlobalKey _tutFabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_load);
    _initAndLoad();
    TutorialService.instance.addListener(_onTutorialTick);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowTutorialTip());
  }

  void _onTutorialTick() {
    if (mounted) _maybeShowTutorialTip();
  }

  /// Guided tour inside Recurring: the section intro, then a pass-through
  /// tip on Add — the editor sheet carries the explainer and the user closes
  /// it without saving.
  void _maybeShowTutorialTip() {
    if (!mounted) return;
    if (mainShellTabIndex.value != 2) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final svc = TutorialService.instance;
    final l10n = context.l10nRead;
    if (svc.isAt(TutorialStep.recurringIntro)) {
      TutorialTips.show(
        context,
        step: TutorialStep.recurringIntro,
        anchor: _tutTitleKey,
        title: l10n.tutRecurringIntroTitle,
        message: l10n.tutRecurringIntroBody,
        passthrough: false,
        buttonLabel: l10n.tutNext,
        onButton: () => svc.advanceFrom(TutorialStep.recurringIntro),
        advanceIfMissing: true,
      );
    } else if (svc.isAt(TutorialStep.recurringAdd)) {
      TutorialTips.show(
        context,
        step: TutorialStep.recurringAdd,
        anchor: _tutFabKey,
        title: l10n.tutRecurringAddTitle,
        message: l10n.tutRecurringAddBody,
      );
    }
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _dismissedSuggestions =
        (prefs.getStringList(_dismissedKey) ?? const <String>[]).toSet();
    await _load();
  }

  String _suggestionKey(String merchant) =>
      merchant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<void> _dismissSuggestions() async {
    final keys = _candidates.map((c) => _suggestionKey(c.merchant)).toSet();
    setState(() {
      _dismissedSuggestions = {..._dismissedSuggestions, ...keys};
      _candidates = const [];
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedKey, _dismissedSuggestions.toList());
  }

  @override
  void dispose() {
    TutorialService.instance.removeListener(_onTutorialTick);
    appDataRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    await _svc.reconcile(); // link any matching SMS debits first
    final views = await _svc.statusViews();
    final plans = await _db.getRecurringPayments();
    final commitment = await _svc.monthlyCommitment();
    final candidates = (await _svc.detectCandidates())
        .where((c) => !_dismissedSuggestions.contains(_suggestionKey(c.merchant)))
        .toList();
    if (!mounted) return;
    setState(() {
      _views = views;
      _paused = plans.where((p) => p.paused).toList();
      _candidates = candidates;
      _monthlyCommitment = commitment;
    });
  }

  Future<void> _add({RecurringPayment? template}) async {
    // Guided tour: tapping Add completes its step; the editor sheet carries
    // the explainer banner and the tour resumes once the sheet closes.
    TutorialService.instance.advanceFrom(TutorialStep.recurringAdd);
    final plan = await showRecurringEditor(context, template: template);
    TutorialService.instance.advanceFrom(TutorialStep.recurringEditor);
    if (plan == null) return;
    await _db.insertRecurringPayment(plan);
    await _load();
  }

  Future<void> _openDetail(RecurringPayment plan) async {
    if (plan.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecurringDetailScreen(planId: plan.id!)),
    );
    await _load();
  }

  Future<void> _markPaid(RecurringStatusView v) async {
    final due = v.dueDate;
    if (due == null) return;
    double? amount = v.plan.amount;
    if (!v.plan.amountIsFixed || amount == null) {
      amount = await _promptAmount();
      if (amount == null) return;
    }
    HapticFeedback.selectionClick();
    await _svc.markPaid(v.plan, due, amount: amount);
    // Cosmetic only: an equipped royal cheers the user for staying on top of bills.
    requestRoyalReaction(RoyalReaction.cheer);
    if (mounted) {
      showAppToast(context,
          message: context.l10nRead.recurringPaidLabel,
          type: AppToastType.success);
    }
    await _load();
  }

  Future<void> _skip(RecurringStatusView v) async {
    final due = v.dueDate;
    if (due == null) return;
    await _svc.skip(v.plan, due);
    await _load();
  }

  Future<double?> _promptAmount() async {
    final controller = TextEditingController();
    final colors = AppColors.of(context);
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(context.l10nRead.enterAmountForCycle,
            style: TextStyle(color: colors.text, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10nRead.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.pop(ctx, (v != null && v > 0) ? v : null);
            },
            child: Text(context.l10nRead.commonSave),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final views = _views;
    final hasAny = (views != null && views.isNotEmpty) || _paused.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: KeyedSubtree(
          key: _tutTitleKey,
          child: AppBarTitle(context.l10n.recurringPaymentsTitle,
              icon: Icons.autorenew_rounded),
        ),
      ),
      floatingActionButton: KeyedSubtree(
        key: _tutFabKey, // guided-tour anchor
        child: FloatingActionButton.extended(
          onPressed: () => _add(),
          icon: const Icon(Icons.add_rounded),
          label: Text(context.l10n.addRecurring),
        ),
      ),
      body: SafeArea(child: views == null
          ? const Center(child: CircularProgressIndicator())
          : !hasAny
              ? _empty(colors)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    if (_monthlyCommitment > 0) _commitmentBanner(colors),
                    if (_candidates.isNotEmpty) _suggestions(colors),
                    for (final v in views) ...[
                      _RecurringRow(
                        view: v,
                        onTap: () => _openDetail(v.plan),
                        onPaid: () => _markPaid(v),
                        onSkip: () => _skip(v),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_paused.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _sectionLabel(colors, context.l10n.pausedLabel),
                      const SizedBox(height: 10),
                      for (final p in _paused) ...[
                        _PausedRow(plan: p, onTap: () => _openDetail(p)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
      ),
    );
  }

  Widget _commitmentBanner(AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 20, color: colors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(context.l10n.monthlyCommitmentLabel,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary)),
          ),
          PrivacyAmount(
            recurringFmt.format(_monthlyCommitment),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: colors.text),
          ),
        ],
      ),
    );
  }

  Widget _suggestions(AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: colors.accent),
              const SizedBox(width: 8),
              Text(context.l10n.detectedSubsTitle,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colors.text)),
              const Spacer(),
              GestureDetector(
                onTap: _dismissSuggestions,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: colors.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(context.l10n.detectedSubsDesc(_candidates.length),
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 10),
          for (final c in _candidates.take(4)) _suggestionRow(colors, c),
        ],
      ),
    );
  }

  Widget _suggestionRow(AppColors colors, RecurringCandidate c) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(ExpenseCategories.getIcon(c.category ?? 'Other'),
              style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.text)),
                Text('${recurringFmt.format(c.amount)} · ~${context.l10n.cadenceMonthly.toLowerCase()}',
                    style:
                        TextStyle(fontSize: 11.5, color: colors.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _add(template: _templateFromCandidate(c)),
            child: Text(context.l10n.trackShort),
          ),
        ],
      ),
    );
  }

  RecurringPayment _templateFromCandidate(RecurringCandidate c) {
    final now = DateTime.now();
    // Next due ≈ same day-of-month next occurrence.
    var anchor = DateTime(now.year, now.month, c.dayOfMonth.clamp(1, 28));
    if (anchor.isBefore(DateTime(now.year, now.month, now.day))) {
      anchor = DateTime(now.year, now.month + 1, c.dayOfMonth.clamp(1, 28));
    }
    return RecurringPayment(
      name: c.merchant,
      category: c.category ?? 'Bills & Utilities',
      amount: c.amount,
      cadence: RecurringCadence.monthly,
      dayOfMonth: anchor.day,
      anchorDate: anchor,
      matchHint: c.merchant,
      createdAt: now,
    );
  }

  Widget _sectionLabel(AppColors colors, String t) => Text(
        t.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: colors.textTertiary),
      );

  Widget _empty(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withValues(alpha: 0.10),
              ),
              child: Icon(Icons.autorenew_rounded,
                  size: 44, color: colors.accent),
            ),
            const SizedBox(height: 20),
            Text(context.l10n.recurringEmptyTitle,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.text)),
            const SizedBox(height: 8),
            Text(
              context.l10n.recurringEmptyDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, height: 1.4, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A live, actionable row for a plan's current cycle.
class _RecurringRow extends StatelessWidget {
  final RecurringStatusView view;
  final VoidCallback onTap;
  final VoidCallback onPaid;
  final VoidCallback onSkip;

  const _RecurringRow({
    required this.view,
    required this.onTap,
    required this.onPaid,
    required this.onSkip,
  });

  bool get _actionable =>
      view.state == RecurringDueState.overdue ||
      view.state == RecurringDueState.dueToday ||
      view.state == RecurringDueState.upcoming;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final plan = view.plan;
    final statusColor = recurringStatusColor(colors, view.state);
    final amount = view.displayAmount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: view.state == RecurringDueState.overdue
                  ? colors.danger.withValues(alpha: 0.45)
                  : colors.border,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.cardAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(ExpenseCategories.getIcon(plan.category),
                        style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colors.text)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                  color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(recurringStatusText(context, view),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor)),
                            if (view.charge?.status ==
                                RecurringChargeStatus.detected) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.bolt_rounded,
                                  size: 13, color: colors.accent),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PrivacyAmount(
                        amount == null
                            ? context.l10n.amountVariesShort
                            : recurringFmt.format(amount),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(view.dueDate == null ? '' : DateFormat('d MMM').format(view.dueDate!),
                          style: TextStyle(
                              fontSize: 11, color: colors.textTertiary)),
                    ],
                  ),
                ],
              ),
              if (_actionable) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSkip,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: colors.border),
                          foregroundColor: colors.textSecondary,
                        ),
                        icon: const Icon(Icons.do_not_disturb_on_outlined,
                            size: 16),
                        label: Text(context.l10n.skipThisCycle),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onPaid,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(context.l10n.markPaidAction),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A dimmed row for a paused plan.
class _PausedRow extends StatelessWidget {
  final RecurringPayment plan;
  final VoidCallback onTap;
  const _PausedRow({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: 0.6,
                child: Text(ExpenseCategories.getIcon(plan.category),
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary)),
              ),
              Icon(Icons.pause_circle_outline_rounded,
                  size: 18, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
