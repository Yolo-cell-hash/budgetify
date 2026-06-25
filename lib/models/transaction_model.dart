import 'package:flutter/material.dart';
import '../services/custom_tag_service.dart';
import 'dart:convert';

/// Transaction model representing a detected bank SMS transaction
class TransactionModel {
  final int? id;
  final double amount;
  final TransactionType type;
  final String sender;
  final String message;
  final DateTime detectedAt;
  final bool isClassified;
  final String? category;
  final String? notes;
  final String? accountInfo;
  final String? merchantName;
  final bool isManual;
  final String? fingerprint;

  /// When this transaction is part of a split, the user's own share of it —
  /// the figure that counts toward spending totals instead of [amount]. Null
  /// for ordinary (unsplit) transactions.
  final double? splitShare;

  TransactionModel({
    this.id,
    required this.amount,
    required this.type,
    required this.sender,
    required this.message,
    required this.detectedAt,
    this.isClassified = false,
    this.category,
    this.notes,
    this.accountInfo,
    this.merchantName,
    this.isManual = false,
    this.fingerprint,
    this.splitShare,
  });

  /// The amount that counts as the user's real spend: their split share when
  /// the transaction is split, otherwise the full [amount].
  double get effectiveAmount => splitShare ?? amount;

  /// Compute a deterministic fingerprint for deduplication.
  /// Two SMS messages that represent the same real-world transaction will
  /// produce the same fingerprint even if their timestamps differ slightly.
  static String computeFingerprint({
    required double amount,
    required TransactionType type,
    required String sender,
    required String message,
    required DateTime detectedAt,
  }) {
    // Normalize the SMS body: uppercase, collapse whitespace, strip non-alnum
    final normalizedMsg = message
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Normalize the sender to its DLT core header: the operator+circle
    // prefix and route suffix vary per delivery ("BV-SBIUPI-S" vs
    // "AD-SBIUPI-T"), so the same alert must not fingerprint differently.
    final coreSender = sender
        .trim()
        .toUpperCase()
        .replaceFirst(RegExp(r'-[A-Z]$'), '')
        .replaceFirst(RegExp(r'^[A-Z]{2}-'), '');

    // Round timestamp to the nearest hour to tolerate minor differences
    final roundedDate = DateTime(
      detectedAt.year,
      detectedAt.month,
      detectedAt.day,
      detectedAt.hour,
    );

    // Build a canonical string and hash it
    final canonical =
        '${amount.toStringAsFixed(2)}|${type.index}|$coreSender|$normalizedMsg|${roundedDate.millisecondsSinceEpoch}';
    // Use a simple but effective hash: convert to bytes, compute hashCode-chain
    final bytes = utf8.encode(canonical);
    var hash = 0xcbf29ce484222325; // FNV-1a offset basis (64-bit)
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff; // FNV prime, keep 63 bits
    }
    return hash.toRadixString(36);
  }

  /// Return a copy of this transaction with the fingerprint computed and set.
  TransactionModel withFingerprint() {
    if (fingerprint != null) return this;
    return copyWith(
      fingerprint: computeFingerprint(
        amount: amount,
        type: type,
        sender: sender,
        message: message,
        detectedAt: detectedAt,
      ),
    );
  }

  /// Create a TransactionModel from a database map
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      amount: map['amount'] as double,
      type: TransactionType.values[map['type'] as int],
      sender: map['sender'] as String,
      message: map['message'] as String,
      detectedAt: DateTime.fromMillisecondsSinceEpoch(
        map['detected_at'] as int,
      ),
      isClassified: (map['is_classified'] as int) == 1,
      category: map['category'] as String?,
      notes: map['notes'] as String?,
      accountInfo: map['account_info'] as String?,
      merchantName: map['merchant_name'] as String?,
      isManual: (map['is_manual'] as int?) == 1,
      fingerprint: map['fingerprint'] as String?,
      splitShare: (map['split_share'] as num?)?.toDouble(),
    );
  }

  /// Convert to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'type': type.index,
      'sender': sender,
      'message': message,
      'detected_at': detectedAt.millisecondsSinceEpoch,
      'is_classified': isClassified ? 1 : 0,
      'category': category,
      'notes': notes,
      'account_info': accountInfo,
      'merchant_name': merchantName,
      'is_manual': isManual ? 1 : 0,
      'fingerprint': fingerprint,
      'split_share': splitShare,
    };
  }

  /// Copy with the tag removed (copyWith can't null out the category).
  TransactionModel untagged() {
    return TransactionModel(
      id: id,
      amount: amount,
      type: type,
      sender: sender,
      message: message,
      detectedAt: detectedAt,
      isClassified: false,
      category: null,
      notes: notes,
      accountInfo: accountInfo,
      merchantName: merchantName,
      isManual: isManual,
      fingerprint: fingerprint,
      splitShare: splitShare,
    );
  }

  /// Create a copy with updated fields
  TransactionModel copyWith({
    int? id,
    double? amount,
    TransactionType? type,
    String? sender,
    String? message,
    DateTime? detectedAt,
    bool? isClassified,
    String? category,
    String? notes,
    String? accountInfo,
    String? merchantName,
    bool? isManual,
    String? fingerprint,
    double? splitShare,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      sender: sender ?? this.sender,
      message: message ?? this.message,
      detectedAt: detectedAt ?? this.detectedAt,
      isClassified: isClassified ?? this.isClassified,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      accountInfo: accountInfo ?? this.accountInfo,
      merchantName: merchantName ?? this.merchantName,
      isManual: isManual ?? this.isManual,
      fingerprint: fingerprint ?? this.fingerprint,
      splitShare: splitShare ?? this.splitShare,
    );
  }
}

/// Transaction type - credit or debit
enum TransactionType { credit, debit }

/// Extension for display-friendly transaction type names
extension TransactionTypeExtension on TransactionType {
  String get displayName {
    switch (this) {
      case TransactionType.credit:
        return 'Credit';
      case TransactionType.debit:
        return 'Debit';
    }
  }

  String get emoji {
    switch (this) {
      case TransactionType.credit:
        return '💰';
      case TransactionType.debit:
        return '💸';
    }
  }
}

/// Predefined expense categories
class ExpenseCategories {
  static const List<String> predefined = [
    'Food & Dining',
    'Groceries',
    'Shopping',
    'Transportation',
    'Bills & Utilities',
    'Entertainment',
    'Health & Medical',
    'Travel',
    'Education',
    'Salary',
    'Transfer',
    'Self Transfer',
    'Investments',
    'Settlement',
    'Refund',
    'Cash',
    'Cash Conversion',
    'Other',
  ];

  /// Categories that are NOT real income or spending and must be excluded from
  /// every total: moving money between your own accounts, money put into
  /// investments (still yours, just relocated), and **settlements** —
  /// repaying/being repaid for money one of you fronted (e.g. you cover a
  /// group bill and friends pay you back; the repayment isn't income, and your
  /// share was already counted when you split the bill).
  static const Set<String> nonExpense = {
    'Self Transfer',
    'Investments',
    'Settlement',
  };

  /// Whether a debit in [category] should count toward expense totals.
  static bool isExpenseCategory(String? category) =>
      category == null || !nonExpense.contains(category);

  /// Whether a credit in [category] counts as real income. Mirrors
  /// [isExpenseCategory]: money moved between your own accounts (Self
  /// Transfer) or pulled back from Investments isn't income, so it must be
  /// excluded for a true savings rate.
  static bool isIncomeCategory(String? category) =>
      category == null || !nonExpense.contains(category);

  /// Backward-compatible alias for predefined categories
  static List<String> get categories => allCategories;

  /// All categories: predefined + user-created custom tags, minus any the
  /// user has deleted/hidden.
  static List<String> get allCategories {
    final service = CustomTagService();
    final visiblePredefined =
        predefined.where((c) => !service.isHidden(c)).toList();
    final custom = service
        .getCustomTags()
        .map((t) => t.name)
        .where((name) => !predefined.contains(name))
        .toList();
    return [...visiblePredefined, ...custom];
  }

  /// Get icon for category (supports custom tags)
  static String getIcon(String category) {
    // Check custom tags first
    final customEmoji = CustomTagService().getTagEmoji(category);
    if (customEmoji != null) return customEmoji;

    switch (category) {
      case 'Food & Dining':
        return '🍔';
      case 'Groceries':
        return '🥬';
      case 'Shopping':
        return '🛍️';
      case 'Transportation':
        return '🚗';
      case 'Bills & Utilities':
        return '📄';
      case 'Entertainment':
        return '🎬';
      case 'Health & Medical':
        return '🏥';
      case 'Travel':
        return '✈️';
      case 'Education':
        return '📚';
      case 'Salary':
        return '💼';
      case 'Transfer':
        return '🔄';
      case 'Self Transfer':
        return '🔁';
      case 'Investments':
        return '📈';
      case 'Settlement':
        return '🤝';
      case 'Refund':
        return '↩️';
      case 'Cash':
        return '💵';
      case 'Cash Conversion':
        return '💱';
      default:
        return '📌';
    }
  }

  /// Get color for category (supports custom tags)
  static Color getColor(String category) {
    // Check custom tags — generate a deterministic color from the name
    if (CustomTagService().isCustomTag(category)) {
      return CustomTagService.colorFromName(category);
    }

    switch (category) {
      case 'Food & Dining':
        return const Color(0xFFFF6B6B);
      case 'Groceries':
        return const Color(0xFF4CAF50);
      case 'Shopping':
        return const Color(0xFF9B59B6);
      case 'Transportation':
        return const Color(0xFF3498DB);
      case 'Bills & Utilities':
        return const Color(0xFF1ABC9C);
      case 'Entertainment':
        return const Color(0xFFE74C3C);
      case 'Health & Medical':
        return const Color(0xFF2ECC71);
      case 'Travel':
        return const Color(0xFFF39C12);
      case 'Education':
        return const Color(0xFF8E44AD);
      case 'Salary':
        return const Color(0xFF27AE60);
      case 'Transfer':
        return const Color(0xFF7F8C8D);
      case 'Self Transfer':
        return const Color(0xFF5B7C99);
      case 'Investments':
        return const Color(0xFF2E8B7A);
      case 'Settlement':
        return const Color(0xFF5E8B9E);
      case 'Refund':
        return const Color(0xFF16A085);
      case 'Cash':
        return const Color(0xFF2ECC40);
      case 'Cash Conversion':
        return const Color(0xFFFF851B);
      default:
        return const Color(0xFF95A5A6);
    }
  }
}

