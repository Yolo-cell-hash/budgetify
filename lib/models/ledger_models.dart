/// Models for the offline "split ledger" — a personal, single-user record of
/// shared expenses (a Splitwise you keep entirely on your own device). Other
/// people are just **names**, never accounts; nothing syncs anywhere.
///
/// Sign convention for a person's balance: **positive ⇒ they owe you**,
/// **negative ⇒ you owe them**.
library;

/// One shared expense.
class SplitEntry {
  final int? id;
  final String title;
  final double totalAmount;

  /// Your own portion of [totalAmount]. This is what counts as your *real*
  /// spending — when the split is linked to a transaction, that transaction's
  /// contribution to every spend total is reduced to this figure.
  final double myShare;

  /// Who fronted the money: `null` means **you** paid; otherwise the name of
  /// the person who paid.
  final String? payer;

  final DateTime date;
  final String? note;

  /// Optional link to a detected/manual transaction, so paying ₹1,200 for a
  /// group dinner can correctly count as only your ₹400 share.
  final int? transactionId;

  final DateTime createdAt;

  const SplitEntry({
    this.id,
    required this.title,
    required this.totalAmount,
    required this.myShare,
    this.payer,
    required this.date,
    this.note,
    this.transactionId,
    required this.createdAt,
  });

  bool get paidByMe => payer == null;

  factory SplitEntry.fromMap(Map<String, dynamic> m) => SplitEntry(
        id: m['id'] as int?,
        title: m['title'] as String,
        totalAmount: (m['total_amount'] as num).toDouble(),
        myShare: (m['my_share'] as num).toDouble(),
        payer: m['payer'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        note: m['note'] as String?,
        transactionId: m['transaction_id'] as int?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'total_amount': totalAmount,
        'my_share': myShare,
        'payer': payer,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'transaction_id': transactionId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}

/// One other person's share within a split (your own share lives on
/// [SplitEntry.myShare], not here).
class SplitParticipant {
  final int? id;
  final int? splitId;
  final String person;
  final double share;

  const SplitParticipant({
    this.id,
    this.splitId,
    required this.person,
    required this.share,
  });

  factory SplitParticipant.fromMap(Map<String, dynamic> m) => SplitParticipant(
        id: m['id'] as int?,
        splitId: m['split_id'] as int?,
        person: m['person'] as String,
        share: (m['share'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (splitId != null) 'split_id': splitId,
        'person': person,
        'share': share,
      };
}

/// A repayment between you and a person, which moves their balance toward zero.
class Settlement {
  final int? id;
  final String person;
  final double amount; // always > 0
  /// true: the person paid *you* back; false: *you* paid the person.
  final bool paidToMe;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  const Settlement({
    this.id,
    required this.person,
    required this.amount,
    required this.paidToMe,
    required this.date,
    this.note,
    required this.createdAt,
  });

  factory Settlement.fromMap(Map<String, dynamic> m) => Settlement(
        id: m['id'] as int?,
        person: m['person'] as String,
        amount: (m['amount'] as num).toDouble(),
        paidToMe: (m['paid_to_me'] as int) == 1,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        note: m['note'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'person': person,
        'amount': amount,
        'paid_to_me': paidToMe ? 1 : 0,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}

/// A person's net balance with you.
class PersonBalance {
  final String person;
  final double net; // >0 they owe you; <0 you owe them

  const PersonBalance(this.person, this.net);

  /// Treat sub-rupee residue as settled (avoids "₹0 owes you" rows).
  static const double _eps = 0.5;
  bool get owesMe => net > _eps;
  bool get iOwe => net < -_eps;
  bool get isSettled => !owesMe && !iOwe;
}

/// Whole-ledger roll-up used by the summary header.
class LedgerSummary {
  final List<PersonBalance> people; // sorted by magnitude, settled ones last
  final double owedToMe;
  final double iOwe;

  const LedgerSummary({
    required this.people,
    required this.owedToMe,
    required this.iOwe,
  });

  double get net => owedToMe - iOwe;
  bool get isEmpty => people.isEmpty;
  int get activeCount => people.where((p) => !p.isSettled).length;
}

/// Pure ledger arithmetic — no I/O, fully unit-testable. The whole
/// owes-who-what model is small enough to derive on the fly from the raw rows.
class LedgerMath {
  const LedgerMath._();

  /// Net balance per person from splits, their participants and settlements.
  /// Positive ⇒ the person owes you; negative ⇒ you owe them.
  static Map<String, double> balances({
    required List<SplitEntry> splits,
    required Map<int, List<SplitParticipant>> participantsBySplit,
    required List<Settlement> settlements,
  }) {
    final bal = <String, double>{};
    void add(String person, double delta) =>
        bal[person] = (bal[person] ?? 0) + delta;

    for (final s in splits) {
      if (s.paidByMe) {
        // You fronted it, so each other participant owes you their share.
        for (final p in participantsBySplit[s.id] ?? const <SplitParticipant>[]) {
          add(p.person, p.share);
        }
      } else {
        // Someone else paid, so you owe them your share.
        add(s.payer!, -s.myShare);
      }
    }

    for (final st in settlements) {
      // Person paid you back ⇒ they owe you less. You paid them ⇒ moves toward
      // them owing you (you owe less).
      add(st.person, st.paidToMe ? -st.amount : st.amount);
    }
    return bal;
  }

  /// Roll the raw balances into a sorted [LedgerSummary].
  static LedgerSummary summarize(Map<String, double> bal) {
    final people = bal.entries
        .map((e) => PersonBalance(e.key, e.value))
        .toList()
      ..sort((a, b) {
        // Active balances first, then by magnitude, then alphabetically.
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        final byMag = b.net.abs().compareTo(a.net.abs());
        if (byMag != 0) return byMag;
        return a.person.toLowerCase().compareTo(b.person.toLowerCase());
      });
    final owed =
        people.where((p) => p.owesMe).fold<double>(0, (a, p) => a + p.net);
    final owe =
        people.where((p) => p.iOwe).fold<double>(0, (a, p) => a - p.net);
    return LedgerSummary(people: people, owedToMe: owed, iOwe: owe);
  }
}

/// How the user chose to divide a split in the editor. The persisted model
/// only stores resolved rupee shares; this enum lives in the UI layer to
/// compute them.
enum SplitMethod { equal, exact, percent, shares }
