import 'transaction_model.dart';

/// Model for transaction classification rules
/// Rules match on the merchant/payee name extracted from SMS body,
/// NOT on the bank sender address. This ensures that rules like
/// "Swiggy → Food & Dining" only apply to Swiggy transactions,
/// not to every transaction from the same bank.
class TransactionRule {
  final int? id;
  final String senderName; // Stores the merchant/payee name (DB column kept for compat)
  final TransactionType
  transactionType; // debit or credit - rules only apply to matching types
  final String category;
  final String? notes;
  final bool isActive; // Whether this rule is active
  final DateTime createdAt;

  TransactionRule({
    this.id,
    required this.senderName,
    required this.transactionType,
    required this.category,
    this.notes,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// The merchant name stored in this rule (alias for senderName)
  String get merchantPattern => senderName;

  /// Create from database map
  factory TransactionRule.fromMap(Map<String, dynamic> map) => TransactionRule(
    id: map['id'] as int?,
    senderName: map['sender_name'] as String,
    transactionType: TransactionType.values[map['transaction_type'] as int],
    category: map['category'] as String,
    notes: map['notes'] as String?,
    isActive: map['is_active'] == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
  );

  /// Convert to database map
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'sender_name': senderName,
    'transaction_type': transactionType.index,
    'category': category,
    'notes': notes,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  /// Check if a transaction matches this rule based on merchant name + type.
  ///
  /// [merchantName] is the extracted merchant/payee from the SMS body.
  /// [type] is the transaction type (debit/credit).
  bool matches(String? merchantName, TransactionType type) {
    // Transaction type must match exactly
    if (transactionType != type) return false;

    // If no merchant name provided, can't match
    if (merchantName == null || merchantName.isEmpty) return false;

    return namesMatch(senderName, merchantName);
  }

  /// Rail words that name the payment method rather than the payee. Dropped
  /// as whole tokens only — they used to be deleted as raw substrings, which
  /// ate the middle out of ordinary names ("Rupinder" → "rnder", because
  /// "upi" sits inside it) and left two unrelated people matching each other.
  static const Set<String> _railTokens = {
    'vpa',
    'upi',
    'neft',
    'imps',
    'rtgs',
  };

  /// A payee name reduced to its comparable words: lower-cased, split on any
  /// run of non-alphanumerics, with rail words removed.
  ///
  /// Tokens, not one squashed string. The old form stripped every separator
  /// before comparing, which destroyed the word boundaries and left raw
  /// substring containment as the only available test — see [namesMatch].
  static List<String> nameTokens(String name) => name
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty && !_railTokens.contains(t))
      .toList();

  /// Whether two payee names refer to the same payee, for the purpose of
  /// applying a rule or sweeping existing rows.
  ///
  /// One name matches the other when its words appear as a **contiguous run
  /// of whole words** in the other — "Swiggy" matches "Swiggy Instamart" and
  /// "Order From Swiggy", and the reverse direction lets a rule taught on
  /// "Swiggy Instamart" still catch a later bare "Swiggy". That reverse case
  /// is why rules are useful at all after one tag, so it stays.
  ///
  /// What it no longer does is match inside a word. The previous test was raw
  /// substring containment in both directions with no boundary and no floor
  /// (KI-001), so a rule taught on "Ola" claimed "Motorola Service", "Sola
  /// Foods" and "Gola Sweets", while a rule on "Amazon Pay" claimed payees
  /// called "Maz" and "Azo". Short payee names are not rare — VPA local parts
  /// and initials routinely produce them.
  ///
  /// Two guards sit on top of the run test:
  ///
  /// - A name with no words left after rail removal matches nothing. A rule
  ///   whose pattern is bare "UPI" would otherwise compare as empty, and an
  ///   empty run sits inside every name — one rule silently tagging the whole
  ///   ledger.
  /// - A lone word of one or two characters must match exactly. Initials are
  ///   too weak to carry a run: "BP" should tag "BP", not "BP Singh". Three
  ///   characters is where real brands start ("KFC", "PVR"), so the floor
  ///   stops below them.
  static bool namesMatch(String a, String b) {
    final ta = nameTokens(a);
    final tb = nameTokens(b);
    if (ta.isEmpty || tb.isEmpty) return false;

    if (ta.length == tb.length) {
      for (var i = 0; i < ta.length; i++) {
        if (ta[i] != tb[i]) return false;
      }
      return true;
    }

    final shorter = ta.length < tb.length ? ta : tb;
    final longer = ta.length < tb.length ? tb : ta;

    // Initials cannot claim a longer name; only exact equality, handled above.
    if (shorter.length == 1 && shorter.first.length <= 2) return false;

    for (var start = 0; start + shorter.length <= longer.length; start++) {
      var all = true;
      for (var i = 0; i < shorter.length; i++) {
        if (longer[start + i] != shorter[i]) {
          all = false;
          break;
        }
      }
      if (all) return true;
    }
    return false;
  }

  TransactionRule copyWith({
    int? id,
    String? senderName,
    TransactionType? transactionType,
    String? category,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return TransactionRule(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      transactionType: transactionType ?? this.transactionType,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    final typeStr = transactionType == TransactionType.debit
        ? 'Debit'
        : 'Credit';
    return 'Rule: $senderName ($typeStr) → $category';
  }
}
