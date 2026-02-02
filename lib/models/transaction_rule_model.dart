/// Model for transaction classification rules
/// Used for auto-classifying similar transactions
class TransactionRule {
  final int? id;
  final String senderPattern;
  final String? messageKeywords;
  final String category;
  final String? notes;
  final bool applyToFuture;
  final DateTime createdAt;

  TransactionRule({
    this.id,
    required this.senderPattern,
    this.messageKeywords,
    required this.category,
    this.notes,
    this.applyToFuture = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from database map
  factory TransactionRule.fromMap(Map<String, dynamic> map) => TransactionRule(
    id: map['id'] as int?,
    senderPattern: map['sender_pattern'] as String,
    messageKeywords: map['message_keywords'] as String?,
    category: map['category'] as String,
    notes: map['notes'] as String?,
    applyToFuture: map['apply_to_future'] == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
  );

  /// Convert to database map
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'sender_pattern': senderPattern,
    'message_keywords': messageKeywords,
    'category': category,
    'notes': notes,
    'apply_to_future': applyToFuture ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  /// Check if a transaction matches this rule
  bool matches(String sender, String message) {
    // Check sender pattern (case-insensitive contains)
    if (!sender.toLowerCase().contains(senderPattern.toLowerCase())) {
      return false;
    }

    // If message keywords specified, check those too
    if (messageKeywords != null && messageKeywords!.isNotEmpty) {
      final keywords = messageKeywords!
          .toLowerCase()
          .split(',')
          .map((k) => k.trim());
      final msgLower = message.toLowerCase();
      return keywords.any((keyword) => msgLower.contains(keyword));
    }

    return true;
  }

  TransactionRule copyWith({
    int? id,
    String? senderPattern,
    String? messageKeywords,
    String? category,
    String? notes,
    bool? applyToFuture,
    DateTime? createdAt,
  }) {
    return TransactionRule(
      id: id ?? this.id,
      senderPattern: senderPattern ?? this.senderPattern,
      messageKeywords: messageKeywords ?? this.messageKeywords,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      applyToFuture: applyToFuture ?? this.applyToFuture,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
