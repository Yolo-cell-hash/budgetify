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

    // Normalized comparison for robust matching
    final normalizedMerchant = _normalizeName(merchantName);
    final normalizedPattern = _normalizeName(senderName);

    // Either the merchant contains our pattern, or pattern contains the merchant
    return normalizedMerchant.contains(normalizedPattern) ||
        normalizedPattern.contains(normalizedMerchant);
  }

  /// Normalize a name for comparison
  /// Removes common prefixes and standardizes format
  String _normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '') // Remove special chars
        .replaceAll('vpa', '') // Remove UPI prefixes
        .replaceAll('upi', '')
        .replaceAll('neft', '')
        .replaceAll('imps', '')
        .replaceAll('rtgs', '')
        .trim();
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
