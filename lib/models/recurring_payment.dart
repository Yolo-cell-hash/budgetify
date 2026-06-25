// Models for recurring *expenses* — subscriptions (Netflix, Prime), rent,
// EMIs, insurance premiums, utilities, gym… This is the expense twin of the
// SIP/RD investment tracker (see models/sip.dart): a RecurringPayment is the
// *plan* (how much, how often, which day), and each resolved occurrence is a
// RecurringCharge in the ledger.
//
// Unlike SIPs, a recurring *expense* doesn't move money into a holding — the
// realised bank-SMS debit is the spend (counted exactly once by the normal
// pipeline). A predicted/upcoming charge is NEVER counted as spending; only a
// resolved charge linked to a real transaction is. The ledger exists to track
// "did this month's bill go out?", to power reminders, and to feed the
// Financial-Health "recurring load" pillar and Safe-to-Spend.
//
// All schedule math here is pure (no I/O) so it can be unit-tested directly.

/// How often a plan recurs.
enum RecurringCadence { weekly, monthly, quarterly, yearly }

extension RecurringCadenceInfo on RecurringCadence {
  String get name => switch (this) {
        RecurringCadence.weekly => 'weekly',
        RecurringCadence.monthly => 'monthly',
        RecurringCadence.quarterly => 'quarterly',
        RecurringCadence.yearly => 'yearly',
      };

  static RecurringCadence parse(String? s) => switch (s) {
        'weekly' => RecurringCadence.weekly,
        'quarterly' => RecurringCadence.quarterly,
        'yearly' => RecurringCadence.yearly,
        _ => RecurringCadence.monthly,
      };

  /// Step in whole months between occurrences (0 for weekly, which steps days).
  int get monthStep => switch (this) {
        RecurringCadence.weekly => 0,
        RecurringCadence.monthly => 1,
        RecurringCadence.quarterly => 3,
        RecurringCadence.yearly => 12,
      };

  /// Factor that converts one occurrence's amount into a monthly-equivalent,
  /// used for the Financial-Health recurring-load pillar.
  double get perMonthFactor => switch (this) {
        RecurringCadence.weekly => 52 / 12, // ~4.33 occurrences a month
        RecurringCadence.monthly => 1,
        RecurringCadence.quarterly => 1 / 3,
        RecurringCadence.yearly => 1 / 12,
      };
}

/// How a single occurrence was resolved (mirrors SipStatus). "Upcoming" and
/// "overdue" are *derived* in the service, never stored — the ledger only
/// records the three resolved states below.
enum RecurringChargeStatus { detected, confirmed, skipped }

extension RecurringChargeStatusName on RecurringChargeStatus {
  String get name => switch (this) {
        RecurringChargeStatus.detected => 'detected',
        RecurringChargeStatus.confirmed => 'confirmed',
        RecurringChargeStatus.skipped => 'skipped',
      };

  static RecurringChargeStatus parse(String? s) => switch (s) {
        'confirmed' => RecurringChargeStatus.confirmed,
        'skipped' => RecurringChargeStatus.skipped,
        _ => RecurringChargeStatus.detected,
      };

  /// Whether this occurrence actually went out (counts as "handled"). A skip
  /// doesn't.
  bool get isPaid => this != RecurringChargeStatus.skipped;
}

/// A recurring expense plan.
class RecurringPayment {
  final int? id;
  final String name; // "Netflix", "Flat rent", "Term insurance"
  final String category; // an ExpenseCategories value
  final double? amount; // fixed amount; null when [amountIsFixed] is false
  final bool amountIsFixed;
  final RecurringCadence cadence;
  final int dayOfMonth; // 1..31 anchor for monthly/quarterly/yearly (clamped)
  final DateTime anchorDate; // first/reference due date (date-only)
  final DateTime? endDate; // optional; open-ended subscriptions have none
  final bool autoMatch; // reconcile against SMS debits + send reminders
  final String? matchHint; // merchant/sender keyword for SMS matching
  final int reminderLeadDays; // remind this many days before the due date
  final bool paused;
  final String? lastReminderPeriod; // 'YYYY-MM-DD[:slot]' dedup (like Sip)
  final String? note;
  final DateTime createdAt;

  const RecurringPayment({
    this.id,
    required this.name,
    required this.category,
    this.amount,
    this.amountIsFixed = true,
    this.cadence = RecurringCadence.monthly,
    required this.dayOfMonth,
    required this.anchorDate,
    this.endDate,
    this.autoMatch = true,
    this.matchHint,
    this.reminderLeadDays = 2,
    this.paused = false,
    this.lastReminderPeriod,
    this.note,
    required this.createdAt,
  });

  // ---- pure schedule helpers ----

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// A stable per-occurrence key — the due date as `YYYY-MM-DD`. Used for the
  /// UNIQUE(plan, period) ledger constraint, so reconciliation is idempotent
  /// regardless of cadence.
  static String periodKeyFor(DateTime due) {
    final d = _dateOnly(due);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Add [n] whole months to [d], clamping the day to the target month length
  /// (so the 31st in a 30-day month becomes the 30th).
  static DateTime _addMonths(DateTime d, int n, int anchorDay) {
    final total = (d.month - 1) + n;
    final y = d.year + (total ~/ 12);
    final m = (total % 12) + 1;
    final day = anchorDay.clamp(1, daysInMonth(y, m));
    return DateTime(y, m, day);
  }

  /// The occurrence immediately following [due] for this plan's cadence.
  DateTime _step(DateTime due) {
    if (cadence == RecurringCadence.weekly) {
      return due.add(const Duration(days: 7));
    }
    return _addMonths(due, cadence.monthStep, dayOfMonth);
  }

  /// The next due-date on or after [from] (date-only), capped by [endDate].
  /// Returns null when the plan has already ended before [from].
  DateTime? nextDueOnOrAfter(DateTime from) {
    final target = _dateOnly(from);
    var due = _dateOnly(anchorDate);
    // Walk forward from the anchor; bounded so a stale anchor can't spin.
    var guard = 0;
    while (due.isBefore(target) && guard++ < 5000) {
      due = _step(due);
    }
    if (endDate != null && due.isAfter(_dateOnly(endDate!))) return null;
    return due;
  }

  /// The most recent due-date on or before [when] (date-only), not earlier
  /// than the anchor and not after [endDate]. Null when nothing is due yet.
  DateTime? dueOnOrBefore(DateTime when) {
    final target = _dateOnly(when);
    final anchor = _dateOnly(anchorDate);
    if (target.isBefore(anchor)) return null;
    var due = anchor;
    var guard = 0;
    while (guard++ < 5000) {
      final next = _step(due);
      if (next.isAfter(target)) break;
      due = next;
    }
    if (endDate != null && due.isAfter(_dateOnly(endDate!))) return null;
    return due;
  }

  /// Every due-date within [start]..[end] inclusive (both date-only). Used by
  /// reconciliation and tests; bounded for safety.
  List<DateTime> occurrencesBetween(DateTime start, DateTime end) {
    final out = <DateTime>[];
    final lo = _dateOnly(start);
    final hi = _dateOnly(end);
    var due = nextDueOnOrAfter(lo);
    var guard = 0;
    while (due != null && !due.isAfter(hi) && guard++ < 5000) {
      out.add(due);
      if (endDate != null && due.isAtSameMomentAs(_dateOnly(endDate!))) break;
      due = _step(due);
      if (endDate != null && due.isAfter(_dateOnly(endDate!))) break;
    }
    return out;
  }

  /// Whether the plan is active (started, not ended, not paused) for the month
  /// containing [when] — i.e. it should count toward recurring load.
  bool isActiveForMonth(DateTime when) {
    if (paused) return false;
    final monthStart = DateTime(when.year, when.month, 1);
    final monthEnd = DateTime(when.year, when.month + 1, 0);
    if (_dateOnly(anchorDate).isAfter(monthEnd)) return false;
    if (endDate != null && _dateOnly(endDate!).isBefore(monthStart)) {
      return false;
    }
    return true;
  }

  /// This plan's monthly-equivalent commitment (0 when the amount is variable
  /// or unset). Feeds the Financial-Health recurring-load pillar.
  double get monthlyEquivalent {
    final a = amount;
    if (a == null || a <= 0 || !amountIsFixed) return 0;
    return a * cadence.perMonthFactor;
  }

  // ---- serialization ----

  factory RecurringPayment.fromMap(Map<String, dynamic> m) => RecurringPayment(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        category: m['category'] as String? ?? 'Other',
        amount: (m['amount'] as num?)?.toDouble(),
        amountIsFixed: (m['amount_is_fixed'] as int?) != 0,
        cadence: RecurringCadenceInfo.parse(m['cadence'] as String?),
        dayOfMonth: (m['day_of_month'] as int?) ?? 1,
        anchorDate: _fromMs(m['anchor_date'] as int?) ?? DateTime.now(),
        endDate: _fromMs(m['end_date'] as int?),
        autoMatch: (m['auto_match'] as int?) != 0,
        matchHint: m['match_hint'] as String?,
        reminderLeadDays: (m['reminder_lead_days'] as int?) ?? 2,
        paused: (m['paused'] as int?) != 0,
        lastReminderPeriod: m['last_reminder_period'] as String?,
        note: m['note'] as String?,
        createdAt: _fromMs(m['created_at'] as int?) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category': category,
        'amount': amount,
        'amount_is_fixed': amountIsFixed ? 1 : 0,
        'cadence': cadence.name,
        'day_of_month': dayOfMonth,
        'anchor_date': _dateOnly(anchorDate).millisecondsSinceEpoch,
        'end_date': endDate == null
            ? null
            : _dateOnly(endDate!).millisecondsSinceEpoch,
        'auto_match': autoMatch ? 1 : 0,
        'match_hint': matchHint,
        'reminder_lead_days': reminderLeadDays,
        'paused': paused ? 1 : 0,
        'last_reminder_period': lastReminderPeriod,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  RecurringPayment copyWith({
    int? id,
    String? name,
    String? category,
    double? amount,
    bool? amountIsFixed,
    RecurringCadence? cadence,
    int? dayOfMonth,
    DateTime? anchorDate,
    DateTime? endDate,
    bool? autoMatch,
    String? matchHint,
    int? reminderLeadDays,
    bool? paused,
    String? lastReminderPeriod,
    String? note,
    DateTime? createdAt,
  }) =>
      RecurringPayment(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        amountIsFixed: amountIsFixed ?? this.amountIsFixed,
        cadence: cadence ?? this.cadence,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        anchorDate: anchorDate ?? this.anchorDate,
        endDate: endDate ?? this.endDate,
        autoMatch: autoMatch ?? this.autoMatch,
        matchHint: matchHint ?? this.matchHint,
        reminderLeadDays: reminderLeadDays ?? this.reminderLeadDays,
        paused: paused ?? this.paused,
        lastReminderPeriod: lastReminderPeriod ?? this.lastReminderPeriod,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );

  static DateTime? _fromMs(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

/// A single resolved occurrence of a [RecurringPayment] (the ledger row).
class RecurringCharge {
  final int? id;
  final int planId;
  final String periodKey; // 'YYYY-MM-DD' of the due date — unique per (plan)
  final DateTime dueDate;
  final double amount;
  final RecurringChargeStatus status;
  final int? transactionId; // the matched SMS debit, when detected
  final DateTime resolvedAt;

  const RecurringCharge({
    this.id,
    required this.planId,
    required this.periodKey,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.transactionId,
    required this.resolvedAt,
  });

  factory RecurringCharge.fromMap(Map<String, dynamic> m) => RecurringCharge(
        id: m['id'] as int?,
        planId: m['plan_id'] as int,
        periodKey: m['period_key'] as String,
        dueDate: DateTime.fromMillisecondsSinceEpoch(
          (m['due_date'] as int?) ?? 0,
        ),
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        status: RecurringChargeStatusName.parse(m['status'] as String?),
        transactionId: m['transaction_id'] as int?,
        resolvedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['resolved_at'] as int?) ?? 0,
        ),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'plan_id': planId,
        'period_key': periodKey,
        'due_date': dueDate.millisecondsSinceEpoch,
        'amount': amount,
        'status': status.name,
        'transaction_id': transactionId,
        'resolved_at': resolvedAt.millisecondsSinceEpoch,
      };
}

/// Derived, display-ready state for a plan's current cycle — built by the
/// service from the plan + ledger. No I/O here, so it's easy to test/use.
enum RecurringDueState { upcoming, dueToday, overdue, paid, skipped, none }

class RecurringStatusView {
  final RecurringPayment plan;

  /// The due-date of the cycle this view describes (the current/active cycle).
  final DateTime? dueDate;

  /// The resolved charge for [dueDate], if any.
  final RecurringCharge? charge;

  /// Whole days until the due date (negative when overdue). Null without a due.
  final int? daysUntilDue;

  final RecurringDueState state;

  const RecurringStatusView({
    required this.plan,
    required this.dueDate,
    required this.charge,
    required this.daysUntilDue,
    required this.state,
  });

  bool get isResolved =>
      state == RecurringDueState.paid || state == RecurringDueState.skipped;

  /// The amount to show for this cycle — the resolved amount if known, else the
  /// plan's fixed amount (null for variable bills).
  double? get displayAmount => charge?.amount ?? plan.amount;
}
