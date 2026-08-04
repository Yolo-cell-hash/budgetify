// A UPI mandate (autopay) the bank told us about over SMS.
//
// When you subscribe to something that charges you automatically — Google
// Play, Spotify, a Groww SIP — your bank registers a UPI *mandate* and sends
// a confirmation SMS naming the merchant, the amount and, often, the date of
// the first debit. That message is a subscription announcing itself, which is
// exactly the thing the Recurring screen otherwise asks the user to type in
// by hand.
//
// A mandate is NOT a transaction: no money moves when it is created. The real
// debits arrive later as ordinary bank alerts and are captured (once) by the
// normal SMS pipeline. This model only records "a recurring commitment
// exists", so the app can *offer* to track it.
//
// Deliberately suggestion-only: a detected mandate never creates a
// RecurringPayment on its own. The user taps Track and the editor opens
// pre-filled, so nothing appears in their subscriptions that they didn't put
// there — the same contract the merchant-history suggestions already keep.

/// Where a detected mandate has got to in the user's hands.
enum MandateState {
  /// Detected, waiting to be offered on the Recurring screen.
  suggested,

  /// The user turned it into a RecurringPayment — don't offer it again.
  tracked,

  /// The user said no — don't offer it again either.
  dismissed,
}

extension MandateStateName on MandateState {
  String get name => switch (this) {
        MandateState.tracked => 'tracked',
        MandateState.dismissed => 'dismissed',
        MandateState.suggested => 'suggested',
      };

  static MandateState parse(String? s) => switch (s) {
        'tracked' => MandateState.tracked,
        'dismissed' => MandateState.dismissed,
        _ => MandateState.suggested,
      };
}

class UpiMandate {
  final int? id;

  /// Who gets paid — "Google Play", "Spotify India Pvt Ltd", "ICCL GROWW
  /// AUTO". Read straight out of the mandate SMS.
  final String merchant;

  /// The mandate's per-cycle amount.
  final double amount;

  /// The first debit date, when the message states one (ICICI does, most
  /// don't). Used as the schedule anchor for the suggested plan.
  final DateTime? firstDebitOn;

  /// The Unique Mandate Number, when present — the bank's own id for this
  /// mandate ("4a37de14c053467b8e7dfaa019ab432f@okicici"). The stable dedup
  /// key: the same mandate re-announced (or re-read on a rescan) must not
  /// become a second suggestion.
  final String? umn;

  /// Masked account the mandate is registered against, e.g. "XX197".
  final String? accountInfo;

  final String sender;
  final String message;
  final DateTime detectedAt;
  final MandateState state;

  const UpiMandate({
    this.id,
    required this.merchant,
    required this.amount,
    this.firstDebitOn,
    this.umn,
    this.accountInfo,
    required this.sender,
    required this.message,
    required this.detectedAt,
    this.state = MandateState.suggested,
  });

  /// The key two records of the same mandate share. Prefers the bank's own
  /// UMN; falls back to merchant + amount for banks that don't quote one
  /// (BOI and SBI's creation messages have no UMN).
  String get dedupKey {
    final u = umn?.trim().toLowerCase();
    if (u != null && u.isNotEmpty) return 'umn:$u';
    final m = merchant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return 'mp:$m:${amount.toStringAsFixed(2)}';
  }

  UpiMandate copyWith({
    int? id,
    String? merchant,
    double? amount,
    DateTime? firstDebitOn,
    String? umn,
    String? accountInfo,
    String? sender,
    String? message,
    DateTime? detectedAt,
    MandateState? state,
  }) =>
      UpiMandate(
        id: id ?? this.id,
        merchant: merchant ?? this.merchant,
        amount: amount ?? this.amount,
        firstDebitOn: firstDebitOn ?? this.firstDebitOn,
        umn: umn ?? this.umn,
        accountInfo: accountInfo ?? this.accountInfo,
        sender: sender ?? this.sender,
        message: message ?? this.message,
        detectedAt: detectedAt ?? this.detectedAt,
        state: state ?? this.state,
      );

  factory UpiMandate.fromMap(Map<String, dynamic> m) => UpiMandate(
        id: m['id'] as int?,
        merchant: m['merchant'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        firstDebitOn: _fromMs(m['first_debit_on'] as int?),
        umn: m['umn'] as String?,
        accountInfo: m['account_info'] as String?,
        sender: m['sender'] as String? ?? '',
        message: m['message'] as String? ?? '',
        detectedAt: _fromMs(m['detected_at'] as int?) ?? DateTime.now(),
        state: MandateStateName.parse(m['state'] as String?),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'merchant': merchant,
        'amount': amount,
        'first_debit_on': firstDebitOn?.millisecondsSinceEpoch,
        'umn': umn,
        'account_info': accountInfo,
        'sender': sender,
        'message': message,
        'detected_at': detectedAt.millisecondsSinceEpoch,
        'state': state.name,
        'dedup_key': dedupKey,
      };

  static DateTime? _fromMs(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}
