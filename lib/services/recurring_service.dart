import '../models/holding.dart';
import '../models/recurring_plan.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'notification_service.dart';

/// A first-time match awaiting the user's one-tap confirmation, surfaced on the
/// net-worth screen. We don't tag anything until it's confirmed (the chosen
/// "confirm once, then auto-learn" flow), so a coincidental same-amount payment
/// can never be silently mis-tagged.
class PendingMatch {
  final RecurringPlan plan;
  final Holding holding;
  final List<TransactionModel> candidates;

  PendingMatch({
    required this.plan,
    required this.holding,
    required this.candidates,
  });
}

/// Derived progress for a plan, powering the net-worth visualization.
class RecurringProgress {
  final double contributed; // sum of recorded contributions
  final int installmentsDone; // count of recorded contributions
  final int? expectedInstallments; // bounded plans: due so far
  final int? totalInstallments; // bounded plans: full term
  final double? projectedTotal; // fixed bounded plans: total × amount
  final DateTime? nextDue;
  final DateTime? maturityDate;

  const RecurringProgress({
    required this.contributed,
    required this.installmentsDone,
    this.expectedInstallments,
    this.totalInstallments,
    this.projectedTotal,
    this.nextDue,
    this.maturityDate,
  });

  /// 0–1 completion against the full term, or null for open-ended plans.
  double? get fractionComplete =>
      (totalInstallments != null && totalInstallments! > 0)
          ? (installmentsDone / totalInstallments!).clamp(0.0, 1.0)
          : null;

  /// True when fewer installments have landed than were due by now.
  bool get isBehind =>
      expectedInstallments != null && installmentsDone < expectedInstallments!;
}

/// Matches recurring SIP/RD auto-debits against detected SMS transactions,
/// learns each plan's payee signature on first confirmation, records the
/// contribution ledger, and drives the evening "didn't see it" fallback.
class RecurringService {
  static final RecurringService _instance = RecurringService._internal();
  factory RecurringService() => _instance;
  RecurringService._internal();

  final DatabaseService _db = DatabaseService();

  // ==================== PURE MATCHING HELPERS (testable) ====================

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _withinDays(DateTime a, DateTime b, int days) =>
      _dateOnly(a).difference(_dateOnly(b)).inDays.abs() <= days;

  /// Collapse a label to an alphanumeric, upper-cased signature so minor
  /// formatting differences between months don't break matching.
  static String normalizeSignature(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// The signature we learn from / match against a transaction: prefer the
  /// parsed merchant name, fall back to the DLT sender header.
  static String signatureForTxn(TransactionModel t) {
    final base = (t.merchantName != null && t.merchantName!.trim().isNotEmpty)
        ? t.merchantName!
        : t.sender;
    return normalizeSignature(base);
  }

  /// Whether [txnDate] falls within the due-day window of [plan]. Adjacent
  /// months are checked too, so a day-1 / last-day mandate posting a day
  /// early or late across a month boundary still matches.
  static bool inDueWindow(RecurringPlan plan, DateTime txnDate,
      {int windowDays = 4}) {
    for (final m in [
      DateTime(txnDate.year, txnDate.month - 1),
      DateTime(txnDate.year, txnDate.month),
      DateTime(txnDate.year, txnDate.month + 1),
    ]) {
      if (_withinDays(txnDate, plan.dueDateIn(m), windowDays)) return true;
    }
    return false;
  }

  /// Allowed deviation from a fixed installment: 1% or ₹1, whichever is larger
  /// (covers paise rounding and the odd platform fee).
  static double toleranceFor(double amount) {
    final pct = amount.abs() * 0.01;
    return pct < 1 ? 1 : pct;
  }

  static bool amountMatches(RecurringPlan plan, double amount) =>
      (amount - plan.amount).abs() <= toleranceFor(plan.amount);

  static bool _signatureMatches(RecurringPlan plan, TransactionModel t) {
    final want = plan.payeeSignature ?? '';
    if (want.isEmpty) return false;
    final got = signatureForTxn(t);
    if (got.isEmpty) return false;
    return got.contains(want) || want.contains(got);
  }

  /// A debit that can be auto-tagged with no confirmation: the plan has a
  /// learned signature, the txn carries it, it's a live, in-window debit.
  /// Amount isn't required — variable / step-up plans still match.
  static bool isAutoMatch(RecurringPlan plan, TransactionModel t) {
    if (t.type != TransactionType.debit) return false;
    if ((plan.payeeSignature ?? '').isEmpty) return false;
    if (!plan.isLiveOn(t.detectedAt)) return false;
    if (!inDueWindow(plan, t.detectedAt)) return false;
    return _signatureMatches(plan, t);
  }

  /// A debit that *could* be this plan's installment but needs confirmation
  /// (no signature learned yet). Fixed plans also require an amount match;
  /// variable plans accept any in-window debit for the user to pick from.
  static bool isCandidate(RecurringPlan plan, TransactionModel t) {
    if (t.type != TransactionType.debit) return false;
    if ((plan.payeeSignature ?? '').isNotEmpty) return false;
    if (!plan.isLiveOn(t.detectedAt)) return false;
    if (!inDueWindow(plan, t.detectedAt)) return false;
    if (plan.isFixed && !amountMatches(plan, t.amount)) return false;
    return true;
  }

  // ==================== PURE PROGRESS HELPERS (testable) ====================

  /// Monthly installments expected from [start] through [asOf] inclusive.
  static int expectedInstallments(DateTime? start, DateTime asOf, int dueDay) {
    if (start == null) return 0;
    final s = DateTime(start.year, start.month);
    final e = DateTime(asOf.year, asOf.month);
    if (e.isBefore(s)) return 0;
    var months = (e.year - s.year) * 12 + (e.month - s.month) + 1;
    final lastDay = DateTime(asOf.year, asOf.month + 1, 0).day;
    final dueThisMonth =
        DateTime(asOf.year, asOf.month, dueDay.clamp(1, lastDay));
    if (asOf.isBefore(dueThisMonth)) months -= 1; // this month not yet due
    return months < 0 ? 0 : months;
  }

  /// Full-term installment count for a bounded plan, else null.
  static int? totalInstallments(RecurringPlan plan) {
    if (plan.startDate == null || plan.endDate == null) return null;
    final s = DateTime(plan.startDate!.year, plan.startDate!.month);
    final e = DateTime(plan.endDate!.year, plan.endDate!.month);
    if (e.isBefore(s)) return 0;
    return (e.year - s.year) * 12 + (e.month - s.month) + 1;
  }

  /// The first due date on or after [from] that lies within the plan's bounds.
  static DateTime? nextDue(RecurringPlan plan, DateTime from) {
    final fromDay = _dateOnly(from);
    var m = DateTime(from.year, from.month);
    for (var i = 0; i < 600; i++) {
      final due = plan.dueDateIn(m);
      if (!due.isBefore(fromDay)) {
        if (plan.endDate != null && due.isAfter(_dateOnly(plan.endDate!))) {
          return null;
        }
        if (plan.startDate == null ||
            !due.isBefore(_dateOnly(plan.startDate!))) {
          return due;
        }
      }
      m = DateTime(m.year, m.month + 1);
    }
    return null;
  }

  static RecurringProgress computeProgress(
    RecurringPlan plan, {
    required double contributed,
    required int installmentsDone,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final total = totalInstallments(plan);
    return RecurringProgress(
      contributed: contributed,
      installmentsDone: installmentsDone,
      expectedInstallments: plan.startDate != null
          ? expectedInstallments(plan.startDate, now, plan.dueDay)
          : null,
      totalInstallments: total,
      projectedTotal: (total != null && plan.isFixed) ? total * plan.amount : null,
      nextDue: plan.active ? nextDue(plan, now) : null,
      maturityDate: plan.endDate,
    );
  }

  // ==================== DB-BACKED OPERATIONS ====================

  /// Called after new debits are detected/scanned. Silently records any that
  /// auto-match a plan that already has a learned signature.
  Future<void> processDetectedTransactions(List<TransactionModel> txns) async {
    final debits =
        txns.where((t) => t.type == TransactionType.debit && t.id != null);
    if (debits.isEmpty) return;
    final plans = (await _db.getActiveRecurringPlans())
        .where((p) => (p.payeeSignature ?? '').isNotEmpty);
    for (final plan in plans) {
      for (final t in debits) {
        if (!isAutoMatch(plan, t)) continue;
        final period = RecurringPlan.periodKey(t.detectedAt);
        if (await _db.hasContributionForPeriod(plan.id!, period)) continue;
        await _applyContribution(plan, t, ContributionSource.auto,
            learnSignature: false);
      }
    }
  }

  /// Confirm a first-time candidate: tag it, record the contribution, and learn
  /// the payee signature so future months auto-match.
  Future<void> confirmMatch(RecurringPlan plan, TransactionModel t) =>
      _applyContribution(plan, t, ContributionSource.auto,
          learnSignature: true);

  Future<void> _applyContribution(
    RecurringPlan plan,
    TransactionModel t,
    ContributionSource source, {
    required bool learnSignature,
  }) async {
    // Tag the debit as an investment (also keeps it out of expense totals).
    if (t.category != 'Investments') {
      await _db.updateTransaction(
        t.copyWith(category: 'Investments', isClassified: true),
      );
    }
    await _db.recordContribution(RecurringContribution(
      planId: plan.id!,
      period: RecurringPlan.periodKey(t.detectedAt),
      amount: t.amount,
      contributedAt: t.detectedAt,
      transactionId: t.id,
      source: source,
    ));
    if (learnSignature && (plan.payeeSignature ?? '').isEmpty) {
      await _db.updateRecurringPlan(
        plan.copyWith(payeeSignature: signatureForTxn(t)),
      );
    }
  }

  /// Manual fallback entry (bank didn't text, or the user logs it themselves):
  /// records a manual Investments transaction plus a contribution for [on]'s
  /// period.
  Future<void> recordManualContribution(
    RecurringPlan plan, {
    required double amount,
    DateTime? on,
  }) async {
    final date = on ?? DateTime.now();
    final txn = TransactionModel(
      amount: amount,
      type: TransactionType.debit,
      sender: 'Manual Entry',
      message: '${plan.kind.label} contribution (manually added)',
      detectedAt: date,
      isClassified: true,
      category: 'Investments',
      isManual: true,
    ).withFingerprint();
    final id = await _db.insertTransaction(txn);
    await _db.recordContribution(RecurringContribution(
      planId: plan.id!,
      period: RecurringPlan.periodKey(date),
      amount: amount,
      contributedAt: date,
      transactionId: id > 0 ? id : null,
      source: ContributionSource.manual,
    ));
  }

  Future<void> stopPlan(RecurringPlan plan) =>
      _db.updateRecurringPlan(plan.copyWith(active: false));

  /// First-time matches awaiting confirmation, for plans without a signature
  /// that have an unrecorded installment this month.
  Future<List<PendingMatch>> getPendingConfirmations() async {
    final open = (await _db.getActiveRecurringPlans())
        .where((p) => (p.payeeSignature ?? '').isEmpty)
        .toList();
    if (open.isEmpty) return const [];

    final holdings = {for (final h in await _db.getHoldings()) h.id: h};
    final since = DateTime.now().subtract(const Duration(days: 45));
    final recentDebits =
        (await _db.getTransactionsByDateRange(since, DateTime.now()))
            .where((t) => t.id != null && t.type == TransactionType.debit)
            .toList();

    final result = <PendingMatch>[];
    for (final plan in open) {
      final period = RecurringPlan.periodKey(DateTime.now());
      if (await _db.hasContributionForPeriod(plan.id!, period)) continue;
      final candidates = recentDebits
          .where((t) => t.category != 'Investments' && isCandidate(plan, t))
          .toList()
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
      if (candidates.isEmpty) continue;
      final holding = holdings[plan.holdingId];
      if (holding == null) continue;
      result.add(PendingMatch(
        plan: plan,
        holding: holding,
        candidates: candidates.take(4).toList(),
      ));
    }
    return result;
  }

  Future<RecurringProgress> progressForPlan(RecurringPlan plan) async {
    final contributed = await _db.totalContributedForPlan(plan.id!);
    final contribs = await _db.getContributionsForPlan(plan.id!);
    return computeProgress(plan,
        contributed: contributed, installmentsDone: contribs.length);
  }

  /// Evening fallback: notify for any live plan that came due in the last few
  /// days but still has no contribution recorded for this period.
  Future<void> runEveningFallbackCheck({int graceDays = 2}) async {
    final now = DateTime.now();
    final plans = await _db.getActiveRecurringPlans();
    if (plans.isEmpty) return;

    final holdings = {for (final h in await _db.getHoldings()) h.id: h};
    final ns = NotificationService();
    await ns.initialize();

    for (final plan in plans) {
      if (!plan.isLiveOn(now)) continue;
      final due = plan.dueDateIn(DateTime(now.year, now.month));
      final daysSinceDue = _dateOnly(now).difference(_dateOnly(due)).inDays;
      if (daysSinceDue < 0 || daysSinceDue > graceDays) continue;

      final period = RecurringPlan.periodKey(now);
      if (await _db.hasContributionForPeriod(plan.id!, period)) continue;

      // Did we at least *see* a plausible debit (just unconfirmed)?
      final since = now.subtract(Duration(days: graceDays + 3));
      final sawCandidate =
          (await _db.getTransactionsByDateRange(since, now)).any(
        (t) =>
            t.type == TransactionType.debit &&
            t.category != 'Investments' &&
            (isCandidate(plan, t) || isAutoMatch(plan, t)),
      );

      final holding = holdings[plan.holdingId];
      await ns.showRecurringReminder(
        planId: plan.id!,
        kindLabel: plan.kind.label,
        holdingName: holding?.name ?? plan.kind.longLabel,
        amount: plan.isFixed ? plan.amount : null,
        sawCandidate: sawCandidate,
      );
    }
  }
}
