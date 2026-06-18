import '../models/holding.dart';
import '../models/sip.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';

/// Orchestrates automated recurring investments (SIPs / RDs).
///
/// Two jobs:
///  1. **Reconcile** — match this month's Investments-tagged SMS debit to the
///     plan and credit its backing holding, so detected instalments flow into
///     net worth automatically.
///  2. **Evening check** — for plans whose instalment is due but still
///     unmatched, nudge the user (~7:30–8 PM) to confirm they invested, so it
///     can be added to net worth manually.
///
/// Stateless and context-free, so it runs safely from WorkManager isolates.
class SipService {
  final DatabaseService _db;
  final NotificationService _notifications;

  SipService({DatabaseService? db, NotificationService? notifications})
      : _db = db ?? DatabaseService(),
        _notifications = notifications ?? NotificationService();

  /// How wide a window around the due date we'll accept a matching debit in.
  /// Banks often debit a day or two early/late; the user may invest manually
  /// within the week.
  static const Duration _matchBefore = Duration(days: 4);
  static const Duration _matchAfter = Duration(days: 7);

  /// Whether [sip]'s instalment for the month containing [when] falls inside
  /// its (optional) start/end window.
  bool _periodInWindow(Sip sip, DateTime when) {
    final due = sip.dueDateInMonth(when.year, when.month);
    if (sip.startDate != null &&
        due.isBefore(DateTime(sip.startDate!.year, sip.startDate!.month,
            sip.startDate!.day))) {
      return false;
    }
    if (sip.endDate != null &&
        due.isAfter(
            DateTime(sip.endDate!.year, sip.endDate!.month, sip.endDate!.day))) {
      return false;
    }
    return true;
  }

  /// Try to auto-match Investments-tagged debits to each plan's recent
  /// instalments and credit the backing holding. Idempotent — safe to call
  /// after every SMS scan and on app resume.
  Future<void> reconcile({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final sips = await _db.getSips();
    var credited = false;

    for (final sip in sips) {
      if (!sip.autoDetect) continue;

      // Look at the current month and the previous one (covers a missed run).
      for (final month in [today, DateTime(today.year, today.month - 1)]) {
        if (!_periodInWindow(sip, month)) continue;
        final due = sip.dueDateInMonth(month.year, month.month);
        if (due.isAfter(today)) continue; // not due yet
        final period = Sip.periodKeyFor(due);
        if (sip.id == null) continue;
        final existing = await _db.getSipPaymentForPeriod(sip.id!, period);
        if (existing != null) continue; // already resolved

        final match = await _db.findInvestmentTransactionForSip(
          windowStart: due.subtract(_matchBefore),
          windowEnd: due.add(_matchAfter),
          due: due,
          amount: sip.amountIsFixed ? sip.amount : null,
        );
        if (match == null) continue;

        await _applyInstallment(
          sip,
          amount: match.amount,
          period: period,
          status: SipStatus.detected,
          transactionId: match.id,
        );
        credited = true;
      }
    }

    if (credited) await WidgetService.update();
  }

  /// Record a paid instalment and top up the backing holding (creating one if
  /// the SIP doesn't have a holding yet). Net worth, allocation, snapshots and
  /// the home widget all derive from holdings, so this is the single write
  /// that makes an instalment "count".
  Future<void> _applyInstallment(
    Sip sip, {
    required double amount,
    required String period,
    required SipStatus status,
    int? transactionId,
  }) async {
    var holdingId = sip.holdingId;
    final existingHolding =
        holdingId == null ? null : await _db.getHolding(holdingId);

    if (existingHolding == null) {
      holdingId = await _db.insertHolding(Holding(
        name: sip.name,
        kind: HoldingKind.asset,
        category: sip.category,
        amount: amount,
        updatedAt: DateTime.now(),
      ));
      if (sip.id != null) {
        await _db.updateSip(sip.copyWith(holdingId: holdingId));
      }
    } else {
      await _db.updateHolding(existingHolding.copyWith(
        amount: existingHolding.amount + amount,
        updatedAt: DateTime.now(),
      ));
    }

    await _db.upsertSipPayment(SipPayment(
      sipId: sip.id!,
      periodKey: period,
      amount: amount,
      status: status,
      transactionId: transactionId,
      resolvedAt: DateTime.now(),
    ));
  }

  /// Confirm the current month's instalment manually (the "Yes, I invested"
  /// path from the reminder). [amount] is required for non-fixed plans.
  Future<void> confirmCurrentInstallment(Sip sip, {double? amount}) async {
    if (sip.id == null) return;
    final due = sip.dueDateInMonth(DateTime.now().year, DateTime.now().month);
    final period = Sip.periodKeyFor(due);
    final value = amount ?? sip.amount ?? 0;
    if (value <= 0) return;
    // Guard against double-crediting if a background reconcile already matched
    // this month between the prompt being shown and the user confirming.
    final existing = await _db.getSipPaymentForPeriod(sip.id!, period);
    if (existing != null && existing.status.isPaid) return;
    await _applyInstallment(
      sip,
      amount: value,
      period: period,
      status: SipStatus.confirmed,
    );
    await WidgetService.update();
  }

  /// Mark the current month's instalment as skipped (no money moved).
  Future<void> skipCurrentInstallment(Sip sip) async {
    if (sip.id == null) return;
    final due = sip.dueDateInMonth(DateTime.now().year, DateTime.now().month);
    await _db.upsertSipPayment(SipPayment(
      sipId: sip.id!,
      periodKey: Sip.periodKeyFor(due),
      amount: 0,
      status: SipStatus.skipped,
      resolvedAt: DateTime.now(),
    ));
  }

  /// Plans whose instalment is due this month (due date has passed) and is
  /// still unresolved — surfaced as the in-app "did you invest?" prompt and
  /// the target of the evening reminder.
  Future<List<Sip>> pendingDueSips({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final out = <Sip>[];
    for (final sip in await _db.getSips()) {
      if (sip.id == null) continue;
      if (!_periodInWindow(sip, today)) continue;
      final due = sip.dueDateInMonth(today.year, today.month);
      if (due.isAfter(today)) continue;
      final existing =
          await _db.getSipPaymentForPeriod(sip.id!, Sip.periodKeyFor(due));
      if (existing == null) out.add(sip);
    }
    return out;
  }

  /// Build display progress for a plan from its ledger.
  Future<SipProgress> progressFor(Sip sip, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final paid = sip.id == null ? 0 : await _db.getPaidSipPaymentCount(sip.id!);
    final invested =
        sip.id == null ? 0.0 : await _db.getSipInvestedTotal(sip.id!);
    final due = sip.dueDateInMonth(today.year, today.month);
    var dueNow = false;
    if (sip.id != null && _periodInWindow(sip, today) && !due.isAfter(today)) {
      final existing =
          await _db.getSipPaymentForPeriod(sip.id!, Sip.periodKeyFor(due));
      dueNow = existing == null;
    }
    return SipProgress(
      sip: sip,
      paidCount: paid,
      investedSoFar: invested,
      dueThisPeriod: dueNow,
    );
  }

  /// Reconcile, then notify for any plan still due-and-unresolved. Deduped per
  /// month via each plan's [Sip.lastReminderPeriod], so the user is nudged at
  /// most once per instalment. Returns how many reminders were raised.
  Future<int> runEveningCheck({DateTime? now}) async {
    final today = now ?? DateTime.now();
    await reconcile(now: today);

    final pending = await pendingDueSips(now: today);
    final toRemind = <Sip>[];
    for (final sip in pending) {
      final due = sip.dueDateInMonth(today.year, today.month);
      final period = Sip.periodKeyFor(due);
      if (sip.lastReminderPeriod == period) continue; // already nudged
      toRemind.add(sip);
    }
    if (toRemind.isEmpty) return 0;

    await _notifications.showSipReminder(
      count: toRemind.length,
      name: toRemind.length == 1 ? toRemind.first.name : null,
      amount: toRemind.length == 1 ? toRemind.first.amount : null,
    );

    final period = Sip.periodKeyFor(today);
    for (final sip in toRemind) {
      if (sip.id != null) {
        await _db.updateSip(sip.copyWith(lastReminderPeriod: period));
      }
    }
    return toRemind.length;
  }

  /// Default number of instalments a user has likely already cleared before
  /// tracking started — everything scheduled up to *last* month (the current
  /// month is what they're being asked about going forward).
  static int suggestedPriorInstallments(Sip sip, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final lastMonth = DateTime(today.year, today.month - 1, 28);
    return sip.scheduledInstallmentsThrough(lastMonth);
  }
}
