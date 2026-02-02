import 'package:flutter/material.dart';

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
  final bool isManual;

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
    this.isManual = false,
  });

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
      isManual: (map['is_manual'] as int?) == 1,
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
      'is_manual': isManual ? 1 : 0,
    };
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
    bool? isManual,
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
      isManual: isManual ?? this.isManual,
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
  static const List<String> categories = [
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
    'Refund',
    'Cash',
    'Cash Conversion',
    'Other',
  ];

  /// Get icon for category
  static String getIcon(String category) {
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

  /// Get color for category
  static Color getColor(String category) {
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
