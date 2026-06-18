import '../models/holding.dart';
import '../models/sip.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';

/// Drives recurring investments (SIPs / RDs) with a manual-but-convenient
/// model: the app never invents instalments from SMS. Money only moves when
/// the *user* says so — by entering past instalments up front, or by answering
/// the Yes/No "Investment Alert" prompt (from the notification or in-app).
///
/// Stateless and context-free, so it runs safely from background isolates.
class SipService {
  final DatabaseService _db;
  final NotificationService _notifications;

  SipService({DatabaseService? db, NotificationService? notifications})
      : _db = db ?? DatabaseService(),
        _notifications = notifications ?? NotificationService();

  /// Whether [sip]'s instalment for the month containing [when] falls inside
  /// its (optional) start/end window.
  bool _periodInWindow(Sip sip, DateTime when) {
    final due = sip.dueDateInMonth(when.year, when.month);
    if (sip.startDate != null && due.isBefore(_dateOnly(sip.startDate!))) {
      return false;
    }
    if (sip.endDate != null && due.isAfter(_dateOnly(sip.endDate!))) {
      return false;
    }
    return true;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Record a paid instalment and top up the backing holding (creating one if
  /// the plan doesn't have a holding yet). Net worth, allocation, snapshots and
  /// the home widget all derive from holdings, so this is the single write that
  /// makes an instalment "count".
  Future<void> _applyInstallment(
    Sip sip, {
    required double amount,
    required String period,
    required SipStatus status,
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
      resolvedAt: DateTime.now(),
    ));
  }

  /// Confirm the current month's instalment manually ("Yes, I invested").
  /// [amount] is required for plans without a stored amount.
  Future<void> confirmCurrentInstallment(Sip sip, {double? amount}) async {
    if (sip.id == null) return;
    final now = DateTime.now();
    final due = sip.dueDateInMonth(now.year, now.month);
    final period = Sip.periodKeyFor(due);
    final value = amount ?? sip.amount ?? 0;
    if (value <= 0) return;
    final existing = await _db.getSipPaymentForPeriod(sip.id!, period);
    if (existing != null && existing.status.isPaid) return; // already logged
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
    final now = DateTime.now();
    final due = sip.dueDateInMonth(now.year, now.month);
    await _db.upsertSipPayment(SipPayment(
      sipId: sip.id!,
      periodKey: Sip.periodKeyFor(due),
      amount: 0,
      status: SipStatus.skipped,
      resolvedAt: DateTime.now(),
    ));
  }

  /// Resolve an instalment from a notification action (Yes/No). Idempotent —
  /// if the month is already logged, does nothing. Safe in a background
  /// isolate (no UI). When [didInvest] is true the plan must have a stored
  /// amount; non-amount plans fall through to the in-app prompt.
  Future<void> resolveFromAction(int sipId, String period, bool didInvest) async {
    final sip = await _db.getSip(sipId);
    if (sip == null) return;
    final existing = await _db.getSipPaymentForPeriod(sipId, period);
    if (existing != null && existing.status.isPaid) return;

    if (didInvest) {
      final amount = sip.amount ?? 0;
      if (amount <= 0) return; // can't credit an unknown amount silently
      await _applyInstallment(
        sip,
        amount: amount,
        period: period,
        status: SipStatus.confirmed,
      );
    } else {
      await _db.upsertSipPayment(SipPayment(
        sipId: sipId,
        periodKey: period,
        amount: 0,
        status: SipStatus.skipped,
        resolvedAt: DateTime.now(),
      ));
    }
    await WidgetService.update();
  }

  /// Plans whose instalment is due this month (due date has passed) and is
  /// still unresolved — surfaced as the in-app "did you invest?" prompt.
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

  /// Build display progress for a plan from its (user-driven) ledger.
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

  /// Send the "Investment Alert" Yes/No prompt for plans whose instalment is
  /// due *today* and unresolved. Two daily slots: noon and evening. The
  /// evening slot only fires if the noon prompt wasn't answered (i.e. still
  /// unresolved). Deduped per period+slot via [Sip.lastReminderPeriod].
  /// Returns how many prompts were sent.
  Future<int> sendDuePrompts({required bool evening, DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayKey = _dateOnly(today);
    final slot = evening ? 'eve' : 'noon';
    var sent = 0;

    for (final sip in await _db.getSips()) {
      if (sip.id == null || !sip.autoDetect) continue; // reminders opted out
      if (!_periodInWindow(sip, today)) continue;
      final due = sip.dueDateInMonth(today.year, today.month);
      if (_dateOnly(due) != todayKey) continue; // only on the due day
      final period = Sip.periodKeyFor(due);

      final existing = await _db.getSipPaymentForPeriod(sip.id!, period);
      if (existing != null) continue; // already answered/resolved

      final marker = '$period:$slot';
      if (evening) {
        if (sip.lastReminderPeriod == marker) continue; // evening already sent
      } else {
        // Noon only fires if nothing was sent for this period yet.
        if (sip.lastReminderPeriod != null &&
            sip.lastReminderPeriod!.startsWith('$period:')) {
          continue;
        }
      }

      await _notifications.showSipPrompt(
        sipId: sip.id!,
        name: sip.name,
        amount: sip.amount,
        periodKey: period,
        evening: evening,
      );
      await _db.updateSip(sip.copyWith(lastReminderPeriod: marker));
      sent++;
    }
    return sent;
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
