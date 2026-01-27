import 'package:flutter/material.dart';

/// Model representing a bank account added by the user
class BankAccount {
  final int? id;
  final String name;
  final String bankCode; // For SMS sender matching (e.g., "BOI", "HDFC")
  final double initialBalance;
  final double currentBalance;
  final DateTime createdAt;
  final Color? color; // Optional color for UI

  BankAccount({
    this.id,
    required this.name,
    required this.bankCode,
    required this.initialBalance,
    required this.currentBalance,
    required this.createdAt,
    this.color,
  });

  /// Create from database map
  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: map['id'] as int?,
      name: map['name'] as String,
      bankCode: map['bank_code'] as String,
      initialBalance: map['initial_balance'] as double,
      currentBalance: map['current_balance'] as double,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      color: map['color'] != null ? Color(map['color'] as int) : null,
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'bank_code': bankCode,
      'initial_balance': initialBalance,
      'current_balance': currentBalance,
      'created_at': createdAt.millisecondsSinceEpoch,
      'color': color?.value,
    };
  }

  /// Create a copy with updated fields
  BankAccount copyWith({
    int? id,
    String? name,
    String? bankCode,
    double? initialBalance,
    double? currentBalance,
    DateTime? createdAt,
    Color? color,
  }) {
    return BankAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      bankCode: bankCode ?? this.bankCode,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
    );
  }
}

/// Common Indian bank codes for auto-detection
class BankCodes {
  static const Map<String, List<String>> senderPatterns = {
    'SBI': ['SBIINB', 'SBIATM', 'SBIBNK', 'SBI'],
    'HDFC': ['HDFCBK', 'HDFC'],
    'ICICI': ['ICICIB', 'ICICIT', 'ICICI'],
    'AXIS': ['AXISBK', 'AXIS'],
    'KOTAK': ['KOTAKB', 'KOTAK'],
    'PNB': ['PNBSMS', 'PNB'],
    'BOI': ['BOIIND', 'BOI'],
    'CANARA': ['CANBNK', 'CANARA'],
    'UNION': ['UNIONB', 'UNION'],
    'IDFC': ['IDFCFB', 'IDFC'],
    'YES': ['YESBAK', 'YES'],
    'INDUSIND': ['INDUSB', 'INDUS'],
    'FEDERAL': ['FEDERA', 'FEDERAL'],
    'RBL': ['RBLBNK', 'RBL'],
    'PAYTM': ['PAYTMB', 'PAYTM'],
  };

  /// Detect bank code from SMS sender
  static String? detectBankCode(String sender) {
    final upperSender = sender.toUpperCase();

    for (final entry in senderPatterns.entries) {
      for (final pattern in entry.value) {
        if (upperSender.contains(pattern)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// Get bank display name
  static String getDisplayName(String bankCode) {
    switch (bankCode) {
      case 'SBI':
        return 'State Bank of India';
      case 'HDFC':
        return 'HDFC Bank';
      case 'ICICI':
        return 'ICICI Bank';
      case 'AXIS':
        return 'Axis Bank';
      case 'KOTAK':
        return 'Kotak Mahindra Bank';
      case 'PNB':
        return 'Punjab National Bank';
      case 'BOI':
        return 'Bank of India';
      case 'CANARA':
        return 'Canara Bank';
      case 'UNION':
        return 'Union Bank';
      case 'IDFC':
        return 'IDFC First Bank';
      case 'YES':
        return 'Yes Bank';
      case 'INDUSIND':
        return 'IndusInd Bank';
      case 'FEDERAL':
        return 'Federal Bank';
      case 'RBL':
        return 'RBL Bank';
      case 'PAYTM':
        return 'Paytm Payments Bank';
      default:
        return bankCode;
    }
  }

  /// Get suggested color for bank
  static Color getBankColor(String bankCode) {
    switch (bankCode) {
      case 'SBI':
        return const Color(0xFF1a4d8f);
      case 'HDFC':
        return const Color(0xFF004c8f);
      case 'ICICI':
        return const Color(0xFFf37021);
      case 'AXIS':
        return const Color(0xFF97144d);
      case 'KOTAK':
        return const Color(0xFFe4002b);
      case 'PNB':
        return const Color(0xFF0033a0);
      case 'BOI':
        return const Color(0xFFff6b00);
      case 'CANARA':
        return const Color(0xFF004b87);
      case 'UNION':
        return const Color(0xFF003366);
      case 'IDFC':
        return const Color(0xFF9c1d26);
      case 'YES':
        return const Color(0xFF00529b);
      case 'INDUSIND':
        return const Color(0xFF880000);
      case 'FEDERAL':
        return const Color(0xFF660099);
      case 'RBL':
        return const Color(0xFF00a0df);
      case 'PAYTM':
        return const Color(0xFF00baf2);
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// Get all available bank codes for dropdown
  static List<String> get allBankCodes => senderPatterns.keys.toList();
}
