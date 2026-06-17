/// Recurring investment plans — SIPs (mutual-fund mandates) and RDs (recurring
/// deposits). A plan is attached to a manual [Holding] and describes a monthly
/// auto-debit the app should watch for in incoming SMS. When a matching debit
/// is seen it is tagged 'Investments' and recorded as a [RecurringContribution];
/// if nothing is seen by the evening of the due day, the user is reminded to
/// confirm manually (banks don't always text, and RDs are often internal).
///
/// Contributions are tracked as "invested so far" — they do NOT auto-edit the
/// linked holding's current value, which stays user-controlled (a mutual fund's
/// market value moves independently of what you put in).
library;

/// Whether the plan is a mutual-fund SIP or a bank recurring deposit.
enum RecurringKind { sip, rd }

extension RecurringKindX on RecurringKind {
  /// Short UI label.
  String get label => this == RecurringKind.sip ? 'SIP' : 'RD';

  /// Longer UI label.
  String get longLabel =>
      this == RecurringKind.sip ? 'SIP' : 'Recurring Deposit';

  /// Value persisted in the database.
  String get storage => this == RecurringKind.sip ? 'sip' : 'rd';

  static RecurringKind fromStorage(String? s) =>
      s == 'rd' ? RecurringKind.rd : RecurringKind.sip;
}

/// How a contribution came to be recorded.
enum ContributionSource { auto, manual }

extension ContributionSourceX on ContributionSource {
  String get storage => this == ContributionSource.auto ? 'auto' : 'manual';

  static ContributionSource fromStorage(String? s) =>
      s == 'auto' ? ContributionSource.auto : ContributionSource.manual;
}

/// A single recurring investment plan attached to a holding.
class RecurringPlan {
  final int? id;
  final int holdingId; // FK -> holdings.id
  final RecurringKind kind;

  /// Expected installment amount. Authoritative for matching only when
  /// [isFixed] is true; for variable plans it's a hint and matching falls back
  /// to the learned [payeeSignature] + due-day window.
  final double amount;
  final bool isFixed;

  /// Day of the month (1–31) the installment is debited. Clamped to the last
  /// day of shorter months when a concrete due date is needed.
  final int dueDay;

  /// Optional bounds. When both are set the UI can show contributed-vs-expected
  /// progress and a projected maturity.
  final DateTime? startDate;
  final DateTime? endDate;

  /// A normalized sender/merchant signature learned from the first
  /// user-confirmed match, used to silently auto-tag later months.
  final String? payeeSignature;

  /// 'YYYY-MM' of the most recent period for which a contribution was recorded.
  /// Drives "already handled this month" checks and the evening fallback.
  final String? lastMatchedPeriod;

  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecurringPlan({
    this.id,
    required this.holdingId,
    required this.kind,
    required this.amount,
    this.isFixed = true,
    required this.dueDay,
    this.startDate,
    this.endDate,
    this.payeeSignature,
    this.lastMatchedPeriod,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The concrete due date within [month], with [dueDay] clamped to the last
  /// day of that month (e.g. a "31" plan falls on Feb 28/29).
  DateTime dueDateIn(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, dueDay.clamp(1, lastDay));
  }

  /// Whether the plan is live for [when]: active and within any start/end bound.
  bool isLiveOn(DateTime when) {
    if (!active) return false;
    if (startDate != null && when.isBefore(_dayStart(startDate!))) return false;
    if (endDate != null && when.isAfter(_dayEnd(endDate!))) return false;
    return true;
  }

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _dayEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  /// 'YYYY-MM' key for [when].
  static String periodKey(DateTime when) =>
      '${when.year.toString().padLeft(4, '0')}-'
      '${when.month.toString().padLeft(2, '0')}';

  factory RecurringPlan.fromMap(Map<String, dynamic> m) => RecurringPlan(
        id: m['id'] as int?,
        holdingId: (m['holding_id'] as int?) ?? 0,
        kind: RecurringKindX.fromStorage(m['kind'] as String?),
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        isFixed: (m['is_fixed'] as int?) != 0,
        dueDay: (m['due_day'] as int?) ?? 1,
        startDate: _dateFrom(m['start_date'] as int?),
        endDate: _dateFrom(m['end_date'] as int?),
        payeeSignature: m['payee_signature'] as String?,
        lastMatchedPeriod: m['last_matched_period'] as String?,
        active: (m['active'] as int?) != 0,
        createdAt:
            _dateFrom(m['created_at'] as int?) ?? DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt:
            _dateFrom(m['updated_at'] as int?) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'holding_id': holdingId,
        'kind': kind.storage,
        'amount': amount,
        'is_fixed': isFixed ? 1 : 0,
        'due_day': dueDay,
        'start_date': startDate?.millisecondsSinceEpoch,
        'end_date': endDate?.millisecondsSinceEpoch,
        'payee_signature': payeeSignature,
        'last_matched_period': lastMatchedPeriod,
        'active': active ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  RecurringPlan copyWith({
    int? id,
    int? holdingId,
    RecurringKind? kind,
    double? amount,
    bool? isFixed,
    int? dueDay,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? payeeSignature,
    bool clearPayeeSignature = false,
    String? lastMatchedPeriod,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      RecurringPlan(
        id: id ?? this.id,
        holdingId: holdingId ?? this.holdingId,
        kind: kind ?? this.kind,
        amount: amount ?? this.amount,
        isFixed: isFixed ?? this.isFixed,
        dueDay: dueDay ?? this.dueDay,
        startDate: clearStartDate ? null : (startDate ?? this.startDate),
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        payeeSignature: clearPayeeSignature
            ? null
            : (payeeSignature ?? this.payeeSignature),
        lastMatchedPeriod: lastMatchedPeriod ?? this.lastMatchedPeriod,
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static DateTime? _dateFrom(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

/// One recorded installment for a [RecurringPlan]. Backs the "invested so far"
/// progress and the contribution ledger. [transactionId] links the originating
/// detected/manual transaction when there is one (manual confirmations made
/// when no SMS arrived may have none).
class RecurringContribution {
  final int? id;
  final int planId;
  final String period; // 'YYYY-MM'
  final double amount;
  final DateTime contributedAt;
  final int? transactionId;
  final ContributionSource source;

  RecurringContribution({
    this.id,
    required this.planId,
    required this.period,
    required this.amount,
    required this.contributedAt,
    this.transactionId,
    this.source = ContributionSource.manual,
  });

  factory RecurringContribution.fromMap(Map<String, dynamic> m) =>
      RecurringContribution(
        id: m['id'] as int?,
        planId: (m['plan_id'] as int?) ?? 0,
        period: m['period'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        contributedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['contributed_at'] as int?) ?? 0,
        ),
        transactionId: m['transaction_id'] as int?,
        source: ContributionSourceX.fromStorage(m['source'] as String?),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'plan_id': planId,
        'period': period,
        'amount': amount,
        'contributed_at': contributedAt.millisecondsSinceEpoch,
        'transaction_id': transactionId,
        'source': source.storage,
      };
}
