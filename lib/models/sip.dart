// Models for automated recurring investments — SIPs (mutual funds, stocks,
// PPF…) and RDs (recurring deposits). A Sip is the *plan*: how much, on which
// day of the month, and (optionally) over what window. Each resolved monthly
// instalment is a SipPayment.
//
// A Sip is backed 1:1 by an investment Holding (via holdingId) so that every
// detected/confirmed instalment simply increases that holding's value — net
// worth, the home widget, allocation and snapshots all update for free, with
// holdings remaining the single source of truth.
//
// All schedule math here is pure (no I/O) so it can be unit-tested.

/// How a single monthly instalment was resolved.
enum SipStatus {
  /// Matched automatically to an Investments-tagged SMS transaction.
  detected,

  /// The user confirmed it manually (e.g. from the evening reminder).
  confirmed,

  /// The user said they skipped this month.
  skipped,
}

extension SipStatusName on SipStatus {
  String get name => switch (this) {
        SipStatus.detected => 'detected',
        SipStatus.confirmed => 'confirmed',
        SipStatus.skipped => 'skipped',
      };

  static SipStatus parse(String? s) => switch (s) {
        'confirmed' => SipStatus.confirmed,
        'skipped' => SipStatus.skipped,
        _ => SipStatus.detected,
      };

  /// Whether this instalment actually added money (i.e. counts toward
  /// progress and net worth). Skips don't.
  bool get isPaid => this != SipStatus.skipped;
}

/// A recurring investment plan.
class Sip {
  final int? id;
  final String name; // user label, e.g. "Parag Parikh Flexi Cap"
  final String category; // one of HoldingCategories.investments
  final double? amount; // fixed instalment; null when [amountIsFixed] is false
  final bool amountIsFixed;
  final int dayOfMonth; // 1..31 (clamped to month length when resolving)
  final DateTime? startDate; // optional
  final DateTime? endDate; // optional; progress shown only when both set
  final bool autoDetect; // watch SMS for a matching debit
  final int? holdingId; // the backing net-worth holding
  final int priorInstallments; // instalments cleared before tracking began
  final String? lastReminderPeriod; // 'YYYY-MM' we last nudged for (dedupe)
  final DateTime createdAt;

  const Sip({
    this.id,
    required this.name,
    required this.category,
    this.amount,
    this.amountIsFixed = true,
    required this.dayOfMonth,
    this.startDate,
    this.endDate,
    this.autoDetect = true,
    this.holdingId,
    this.priorInstallments = 0,
    this.lastReminderPeriod,
    required this.createdAt,
  });

  /// "RD" for recurring deposits, "SIP" for everything else — for labels.
  String get kindLabel => category == 'Recurring Deposit' ? 'RD' : 'SIP';

  /// Whether a start *and* end date were provided, enabling the progress bar.
  bool get hasSchedule => startDate != null && endDate != null;

  // ---- pure schedule helpers ----

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static String periodKeyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// The instalment due-date within a specific month, with [dayOfMonth]
  /// clamped to that month's length (so day 31 in June → 30 June).
  DateTime dueDateInMonth(int year, int month) {
    final day = dayOfMonth.clamp(1, daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  /// The next due-date on or after [from] (date-only), capped by [endDate].
  /// Returns null when the plan has already ended.
  DateTime? nextDueOnOrAfter(DateTime from) {
    final fromDay = DateTime(from.year, from.month, from.day);
    var due = dueDateInMonth(from.year, from.month);
    if (due.isBefore(fromDay)) {
      due = dueDateInMonth(from.year, from.month + 1);
    }
    if (endDate != null && due.isAfter(_dateOnly(endDate!))) return null;
    return due;
  }

  /// Total scheduled instalments across [startDate]..[endDate] inclusive.
  /// Zero when no full schedule is set.
  int get totalInstallments {
    if (!hasSchedule) return 0;
    return _countDueDates(startDate!, endDate!);
  }

  /// How many instalments were scheduled from [startDate] through [asOf]
  /// (inclusive, never past [endDate]). Used to pre-fill the "already
  /// completed" catch-up field when a plan started before the app was added.
  int scheduledInstallmentsThrough(DateTime asOf) {
    if (startDate == null) return 0;
    var end = _dateOnly(asOf);
    if (endDate != null && _dateOnly(endDate!).isBefore(end)) {
      end = _dateOnly(endDate!);
    }
    if (end.isBefore(_dateOnly(startDate!))) return 0;
    return _countDueDates(startDate!, end);
  }

  /// Count due-dates within [from]..[to] inclusive (both date-only).
  int _countDueDates(DateTime from, DateTime to) {
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    if (end.isBefore(start)) return 0;
    var count = 0;
    var y = start.year;
    var m = start.month;
    // Walk month-by-month; cheap even for decades-long plans.
    while (true) {
      final due = dueDateInMonth(y, m);
      if (due.isAfter(end)) break;
      if (!due.isBefore(start)) count++;
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return count;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // ---- serialization ----

  factory Sip.fromMap(Map<String, dynamic> m) => Sip(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        category: m['category'] as String? ?? 'Other Investment',
        amount: (m['amount'] as num?)?.toDouble(),
        amountIsFixed: (m['amount_is_fixed'] as int?) != 0,
        dayOfMonth: (m['day_of_month'] as int?) ?? 1,
        startDate: _fromMs(m['start_date'] as int?),
        endDate: _fromMs(m['end_date'] as int?),
        autoDetect: (m['auto_detect'] as int?) != 0,
        holdingId: m['holding_id'] as int?,
        priorInstallments: (m['prior_installments'] as int?) ?? 0,
        lastReminderPeriod: m['last_reminder_period'] as String?,
        createdAt: _fromMs(m['created_at'] as int?) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category': category,
        'amount': amount,
        'amount_is_fixed': amountIsFixed ? 1 : 0,
        'day_of_month': dayOfMonth,
        'start_date': startDate?.millisecondsSinceEpoch,
        'end_date': endDate?.millisecondsSinceEpoch,
        'auto_detect': autoDetect ? 1 : 0,
        'holding_id': holdingId,
        'prior_installments': priorInstallments,
        'last_reminder_period': lastReminderPeriod,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  Sip copyWith({
    int? id,
    String? name,
    String? category,
    double? amount,
    bool? amountIsFixed,
    int? dayOfMonth,
    DateTime? startDate,
    DateTime? endDate,
    bool? autoDetect,
    int? holdingId,
    int? priorInstallments,
    String? lastReminderPeriod,
    DateTime? createdAt,
  }) =>
      Sip(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        amountIsFixed: amountIsFixed ?? this.amountIsFixed,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        autoDetect: autoDetect ?? this.autoDetect,
        holdingId: holdingId ?? this.holdingId,
        priorInstallments: priorInstallments ?? this.priorInstallments,
        lastReminderPeriod: lastReminderPeriod ?? this.lastReminderPeriod,
        createdAt: createdAt ?? this.createdAt,
      );

  static DateTime? _fromMs(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

/// A single resolved monthly instalment of a [Sip].
class SipPayment {
  final int? id;
  final int sipId;
  final String periodKey; // 'YYYY-MM' — unique per (sip, month)
  final double amount;
  final SipStatus status;
  final int? transactionId; // the matched SMS transaction, when detected
  final DateTime resolvedAt;

  const SipPayment({
    this.id,
    required this.sipId,
    required this.periodKey,
    required this.amount,
    required this.status,
    this.transactionId,
    required this.resolvedAt,
  });

  factory SipPayment.fromMap(Map<String, dynamic> m) => SipPayment(
        id: m['id'] as int?,
        sipId: m['sip_id'] as int,
        periodKey: m['period_key'] as String,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        status: SipStatusName.parse(m['status'] as String?),
        transactionId: m['transaction_id'] as int?,
        resolvedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['resolved_at'] as int?) ?? 0,
        ),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sip_id': sipId,
        'period_key': periodKey,
        'amount': amount,
        'status': status.name,
        'transaction_id': transactionId,
        'resolved_at': resolvedAt.millisecondsSinceEpoch,
      };
}

/// Pure, derived progress for a [Sip] given how many instalments have actually
/// been paid (detected + confirmed + prior). Built by the service from the
/// payment ledger; no I/O here so it's trivially testable.
class SipProgress {
  final Sip sip;

  /// Paid instalments recorded in the ledger this device knows about
  /// (excludes skips). Prior instalments are added on top.
  final int paidCount;

  /// Total money credited so far via this plan (for display).
  final double investedSoFar;

  /// Whether the current month's instalment is still unresolved *and* due.
  final bool dueThisPeriod;

  const SipProgress({
    required this.sip,
    required this.paidCount,
    required this.investedSoFar,
    required this.dueThisPeriod,
  });

  /// Completed instalments = those paid through the app + any the user had
  /// already cleared before tracking started.
  int get completed => paidCount + sip.priorInstallments;

  int get total => sip.totalInstallments;

  /// 0..1 progress, or null when there's no start/end window to measure
  /// against.
  double? get fraction {
    if (!sip.hasSchedule || total <= 0) return null;
    return (completed / total).clamp(0.0, 1.0);
  }

  int? get remaining {
    if (!sip.hasSchedule) return null;
    final r = total - completed;
    return r < 0 ? 0 : r;
  }

  bool get isComplete => sip.hasSchedule && completed >= total && total > 0;
}
