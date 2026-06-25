import '../models/recurring_payment.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'notification_service.dart';

/// Drives recurring *expenses* (subscriptions, rent, EMIs, insurance…).
///
/// Design mirrors [SipService] but for money going *out*:
///  - it never invents spend — a predicted/upcoming charge is not an expense;
///    only the realised bank-SMS debit counts (once, via the normal pipeline);
///  - [reconcile] is pull-based: it links an *existing* debit to the cycle it
///    pays, so "auto-detect from SMS" needs no change to the fragile SMS save
///    path and is fully idempotent;
///  - reminders use the same two-slot dedup as SIP prompts.
///
/// Stateless and context-free, so it runs safely from background isolates.
class RecurringService {
  final DatabaseService _db;
  final NotificationService _notifications;

  RecurringService({DatabaseService? db, NotificationService? notifications})
      : _db = db ?? DatabaseService(),
        _notifications = notifications ?? NotificationService();

  /// How many days either side of the due date a matching debit may fall.
  static const int matchWindowDays = 5;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static int _daysBetween(DateTime from, DateTime to) =>
      _dateOnly(to).difference(_dateOnly(from)).inDays;

  // ──────────────────────────── derived views ────────────────────────────

  /// The current-cycle status of a plan, given a lookup of its resolved
  /// charges by period key. Pure (no I/O) so it's unit-tested directly.
  static RecurringStatusView statusViewFor(
    RecurringPayment plan,
    DateTime now,
    RecurringCharge? Function(String periodKey) chargeFor,
  ) {
    final today = _dateOnly(now);

    if (plan.paused) {
      return RecurringStatusView(
        plan: plan,
        dueDate: null,
        charge: null,
        daysUntilDue: null,
        state: RecurringDueState.none,
      );
    }

    // 1) Has a due date already arrived and gone unresolved? That's the cycle
    //    that needs action (overdue or due today).
    final lastDue = plan.dueOnOrBefore(today);
    if (lastDue != null) {
      final c = chargeFor(RecurringPayment.periodKeyFor(lastDue));
      if (c == null) {
        final days = _daysBetween(today, lastDue); // <= 0
        return RecurringStatusView(
          plan: plan,
          dueDate: lastDue,
          charge: null,
          daysUntilDue: days,
          state: days == 0
              ? RecurringDueState.dueToday
              : RecurringDueState.overdue,
        );
      }
    }

    // 2) Otherwise focus on the next upcoming cycle.
    final from =
        lastDue == null ? today : lastDue.add(const Duration(days: 1));
    final nextDue = plan.nextDueOnOrAfter(from);
    if (nextDue == null) {
      // Plan has ended — reflect the final cycle's resolution if we have it.
      if (lastDue != null) {
        final c = chargeFor(RecurringPayment.periodKeyFor(lastDue));
        if (c != null) {
          return RecurringStatusView(
            plan: plan,
            dueDate: lastDue,
            charge: c,
            daysUntilDue: _daysBetween(today, lastDue),
            state: c.status == RecurringChargeStatus.skipped
                ? RecurringDueState.skipped
                : RecurringDueState.paid,
          );
        }
      }
      return RecurringStatusView(
        plan: plan,
        dueDate: null,
        charge: null,
        daysUntilDue: null,
        state: RecurringDueState.none,
      );
    }

    final days = _daysBetween(today, nextDue); // >= 0
    final c = chargeFor(RecurringPayment.periodKeyFor(nextDue));
    if (c != null) {
      return RecurringStatusView(
        plan: plan,
        dueDate: nextDue,
        charge: c,
        daysUntilDue: days,
        state: c.status == RecurringChargeStatus.skipped
            ? RecurringDueState.skipped
            : RecurringDueState.paid,
      );
    }
    return RecurringStatusView(
      plan: plan,
      dueDate: nextDue,
      charge: null,
      daysUntilDue: days,
      state: days == 0
          ? RecurringDueState.dueToday
          : RecurringDueState.upcoming,
    );
  }

  /// Status views for every non-paused plan, sorted by urgency (overdue first,
  /// then due-today, then soonest upcoming).
  Future<List<RecurringStatusView>> statusViews({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final plans = await _db.getRecurringPayments();
    final views = <RecurringStatusView>[];
    for (final plan in plans) {
      if (plan.paused || plan.id == null) continue;
      final charges = await _db.getRecurringCharges(plan.id!);
      final byKey = {for (final c in charges) c.periodKey: c};
      views.add(statusViewFor(plan, today, (k) => byKey[k]));
    }
    views.sort(_byUrgency);
    return views;
  }

  static int _rank(RecurringDueState s) => switch (s) {
        RecurringDueState.overdue => 0,
        RecurringDueState.dueToday => 1,
        RecurringDueState.upcoming => 2,
        RecurringDueState.paid => 3,
        RecurringDueState.skipped => 4,
        RecurringDueState.none => 5,
      };

  static int _byUrgency(RecurringStatusView a, RecurringStatusView b) {
    final r = _rank(a.state).compareTo(_rank(b.state));
    if (r != 0) return r;
    final ad = a.daysUntilDue, bd = b.daysUntilDue;
    if (ad != null && bd != null) return ad.compareTo(bd);
    return a.plan.name.toLowerCase().compareTo(b.plan.name.toLowerCase());
  }

  /// Upcoming or overdue (unresolved) views, optionally only those due within
  /// [withinDays]. Powers the Home "upcoming bills" card.
  Future<List<RecurringStatusView>> upcomingAndOverdue({
    int? withinDays,
    DateTime? now,
  }) async {
    final views = await statusViews(now: now);
    return views.where((v) {
      final actionable = v.state == RecurringDueState.overdue ||
          v.state == RecurringDueState.dueToday ||
          v.state == RecurringDueState.upcoming;
      if (!actionable) return false;
      if (withinDays == null) return true;
      final d = v.daysUntilDue;
      return d != null && d <= withinDays;
    }).toList();
  }

  // ──────────────────────────── commitments ────────────────────────────

  /// Monthly-equivalent commitment of active, fixed-amount plans — for the
  /// Financial-Health recurring-load pillar.
  Future<double> monthlyCommitment({DateTime? now}) async {
    final today = now ?? DateTime.now();
    var total = 0.0;
    for (final plan in await _db.getRecurringPayments()) {
      if (!plan.isActiveForMonth(today)) continue;
      total += plan.monthlyEquivalent;
    }
    return total;
  }

  /// Money still to be paid this calendar month: fixed-amount dues from today
  /// through month-end that aren't resolved yet. Reserved by Safe-to-Spend so
  /// the "₹/day safe" figure already sets aside the rent/EMI you haven't paid.
  Future<double> reservedForRestOfMonth({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final monthEnd = DateTime(today.year, today.month + 1, 0);
    var total = 0.0;
    for (final plan in await _db.getRecurringPayments()) {
      if (plan.paused || plan.id == null) continue;
      final amt = plan.amount;
      if (amt == null || amt <= 0 || !plan.amountIsFixed) continue;
      final dues = plan.occurrencesBetween(today, monthEnd);
      if (dues.isEmpty) continue;
      final charges = await _db.getRecurringCharges(plan.id!);
      final keys = {for (final c in charges) c.periodKey};
      for (final due in dues) {
        if (!keys.contains(RecurringPayment.periodKeyFor(due))) total += amt;
      }
    }
    return total;
  }

  // ──────────────────────────── resolution ────────────────────────────

  /// Record the [status] of a specific cycle ([due]) — idempotent per cycle.
  Future<void> resolveCharge(
    RecurringPayment plan,
    DateTime due, {
    required RecurringChargeStatus status,
    double? amount,
    int? transactionId,
  }) async {
    if (plan.id == null) return;
    final value =
        status == RecurringChargeStatus.skipped ? 0.0 : (amount ?? plan.amount ?? 0);
    await _db.upsertRecurringCharge(RecurringCharge(
      planId: plan.id!,
      periodKey: RecurringPayment.periodKeyFor(due),
      dueDate: _dateOnly(due),
      amount: value,
      status: status,
      transactionId: transactionId,
      resolvedAt: DateTime.now(),
    ));
  }

  Future<void> markPaid(RecurringPayment plan, DateTime due,
          {double? amount, int? transactionId}) =>
      resolveCharge(plan, due,
          status: RecurringChargeStatus.confirmed,
          amount: amount,
          transactionId: transactionId);

  Future<void> skip(RecurringPayment plan, DateTime due) =>
      resolveCharge(plan, due, status: RecurringChargeStatus.skipped);

  /// Resolve a cycle from a notification action (Paid / Skip). Idempotent and
  /// background-isolate safe (no UI). [periodKey] is `YYYY-MM-DD` of the due.
  Future<void> resolveFromAction(
      int planId, String periodKey, bool didPay) async {
    final plan = await _db.getRecurringPayment(planId);
    if (plan == null) return;
    final existing = await _db.getRecurringChargeForPeriod(planId, periodKey);
    if (existing != null && existing.status.isPaid) return;
    final due = _parsePeriodKey(periodKey);
    if (due == null) return;
    await resolveCharge(
      plan,
      due,
      status: didPay
          ? RecurringChargeStatus.confirmed
          : RecurringChargeStatus.skipped,
      amount: plan.amount,
    );
  }

  static DateTime? _parsePeriodKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]),
        m = int.tryParse(parts[1]),
        d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  // ──────────────────────────── reconciliation ────────────────────────────

  /// Link existing bank-SMS debits to the recurring cycle they pay. Pull-based
  /// and idempotent — safe to call on every screen load / background tick.
  /// Returns how many cycles were newly matched.
  Future<int> reconcile({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    var matched = 0;
    for (final plan in await _db.getRecurringPayments()) {
      if (plan.id == null || plan.paused || !plan.autoMatch) continue;
      final due = plan.dueOnOrBefore(today);
      if (due == null) continue;
      final key = RecurringPayment.periodKeyFor(due);
      if (await _db.getRecurringChargeForPeriod(plan.id!, key) != null) {
        continue; // already resolved
      }
      final start = due.subtract(const Duration(days: matchWindowDays));
      final end = DateTime(due.year, due.month,
          due.day + matchWindowDays, 23, 59, 59);
      final txns = await _db.getTransactionsByDateRange(start, end);
      final match = _findMatch(plan, txns);
      if (match == null) continue;
      await resolveCharge(
        plan,
        due,
        status: RecurringChargeStatus.detected,
        amount: match.amount,
        transactionId: match.id,
      );
      matched++;
    }
    return matched;
  }

  /// First debit in [txns] that plausibly pays [plan]: a name/hint match and,
  /// for fixed-amount plans, an amount within tolerance.
  TransactionModel? _findMatch(RecurringPayment plan, List<TransactionModel> txns) {
    final hint = _norm(plan.matchHint ?? plan.name);
    if (hint.isEmpty) return null;
    for (final t in txns) {
      if (t.type != TransactionType.debit) continue;
      final hay = _norm('${t.merchantName ?? ''} ${t.sender}');
      if (!hay.contains(hint) && !hint.contains(hay)) continue;
      final amt = plan.amount;
      if (plan.amountIsFixed && amt != null && amt > 0) {
        final tol = (amt * 0.10).clamp(20.0, double.infinity);
        if ((t.amount - amt).abs() > tol) continue;
      }
      return t;
    }
    return null;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // ──────────────────────────── reminders ────────────────────────────

  /// Send the "Bill reminder" Paid/Skip prompt for any plan whose cycle is
  /// unresolved and within its reminder lead window (or overdue). Two daily
  /// slots (noon / evening); the evening one only fires if noon went
  /// unanswered. Deduped per cycle+slot via [RecurringPayment.lastReminderPeriod].
  /// Returns how many prompts were sent.
  Future<int> sendDuePrompts({required bool evening, DateTime? now}) async {
    final today = now ?? DateTime.now();
    final slot = evening ? 'eve' : 'noon';
    var sent = 0;

    for (final plan in await _db.getRecurringPayments()) {
      if (plan.id == null || plan.paused || !plan.autoMatch) continue;
      final charges = await _db.getRecurringCharges(plan.id!);
      final byKey = {for (final c in charges) c.periodKey: c};
      final view = statusViewFor(plan, today, (k) => byKey[k]);

      final due = view.dueDate;
      if (due == null || view.isResolved) continue;
      final days = view.daysUntilDue ?? 999;
      // Remind within the lead window, on the day, or once it's overdue.
      if (days > plan.reminderLeadDays) continue;

      final key = RecurringPayment.periodKeyFor(due);
      final marker = '$key:$slot';
      if (evening) {
        if (plan.lastReminderPeriod == marker) continue; // evening already sent
      } else {
        if (plan.lastReminderPeriod != null &&
            plan.lastReminderPeriod!.startsWith('$key:')) {
          continue; // something already sent this cycle
        }
      }

      await _notifications.showRecurringPrompt(
        planId: plan.id!,
        name: plan.name,
        amount: plan.amount,
        periodKey: key,
        overdue: view.state == RecurringDueState.overdue,
      );
      await _db.updateRecurringPayment(plan.copyWith(lastReminderPeriod: marker));
      sent++;
    }
    return sent;
  }

  // ──────────────────────────── auto-detect ────────────────────────────

  /// Scan recent debits for likely subscriptions/bills the user hasn't tracked
  /// yet: a merchant charged on a roughly regular monthly cadence with a stable
  /// amount. Suggestion-only — never creates a plan. Newest-activity first.
  Future<List<RecurringCandidate>> detectCandidates({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final start = DateTime(today.year, today.month - 4, 1);
    final txns = await _db.getTransactionsByDateRange(start, today);

    // Group debits by normalised merchant.
    final groups = <String, List<TransactionModel>>{};
    final labels = <String, String>{};
    for (final t in txns) {
      if (t.type != TransactionType.debit) continue;
      final label = (t.merchantName ?? '').trim();
      if (label.isEmpty) continue;
      final key = _norm(label);
      if (key.isEmpty) continue;
      (groups[key] ??= []).add(t);
      labels[key] ??= label;
    }

    // Existing plans, so we don't re-suggest something already tracked.
    final existing = {
      for (final p in await _db.getRecurringPayments()) _norm(p.matchHint ?? p.name)
    };

    final out = <RecurringCandidate>[];
    groups.forEach((key, list) {
      if (existing.any((e) => e.contains(key) || key.contains(e))) return;
      if (list.length < 3) return; // need a few to call it recurring

      list.sort((a, b) => a.detectedAt.compareTo(b.detectedAt));
      // Roughly-monthly spacing: median gap in 24..38 days.
      final gaps = <int>[];
      for (var i = 1; i < list.length; i++) {
        gaps.add(list[i].detectedAt.difference(list[i - 1].detectedAt).inDays);
      }
      final medGap = _median(gaps.map((g) => g.toDouble()).toList());
      if (medGap < 24 || medGap > 38) return;

      // Stable amount: low spread around the median.
      final amounts = list.map((t) => t.amount).toList();
      final medAmt = _median([...amounts]);
      if (medAmt <= 0) return;
      final spread =
          _median(amounts.map((a) => (a - medAmt).abs()).toList());
      if (spread > medAmt * 0.15) return; // amounts vary too much

      final last = list.last;
      out.add(RecurringCandidate(
        merchant: labels[key] ?? last.merchantName ?? key,
        amount: medAmt,
        dayOfMonth: last.detectedAt.day,
        category: last.category,
        occurrences: list.length,
        lastSeen: last.detectedAt,
      ));
    });

    out.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return out;
  }

  static double _median(List<double> xs) {
    if (xs.isEmpty) return 0;
    xs.sort();
    final mid = xs.length ~/ 2;
    return xs.length.isOdd ? xs[mid] : (xs[mid - 1] + xs[mid]) / 2;
  }
}

/// A detected, not-yet-tracked recurring charge — pre-fills the editor.
class RecurringCandidate {
  final String merchant;
  final double amount;
  final int dayOfMonth;
  final String? category;
  final int occurrences;
  final DateTime lastSeen;

  const RecurringCandidate({
    required this.merchant,
    required this.amount,
    required this.dayOfMonth,
    required this.category,
    required this.occurrences,
    required this.lastSeen,
  });
}
