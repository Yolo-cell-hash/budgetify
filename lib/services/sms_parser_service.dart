import '../models/transaction_model.dart';

/// Service for parsing bank SMS messages to extract transaction details
class SmsParserService {
  // Common Indian bank sender patterns
  static final List<String> _bankSenderPatterns = [
    'SBIINB',
    'SBIATM',
    'HDFCBK',
    'ICICIB',
    'ICICIT',
    'AXISBK',
    'KOTAKB',
    'PNBSMS',
    'BOIIND',
    'CANBNK',
    'UNIONB',
    'IABORB',
    'YESBAK',
    'INDUSB',
    'FEDERA',
    'IDFCFB',
    'RBLBNK',
    'PAYTMB',
    'GPAY',
    'PHONEPE',
    'PAYTM',
    'AMAZONP',
    'APAY',
  ];

  /// Merchant keywords for auto-categorization
  static const Map<String, List<String>> _merchantCategories = {
    'Food & Dining': [
      'SWIGGY',
      'ZOMATO',
      'DOMINOS',
      'MCDONALDS',
      'KFC',
      'STARBUCKS',
      'BURGER KING',
      'PIZZA HUT',
      'SUBWAY',
      'DUNKIN',
      'CAFE COFFEE',
      'CHAAYOS',
      'HALDIRAM',
    ],
    'Groceries': [
      'ZEPTO',
      'BLINKIT',
      'BIGBASKET',
      'JIOMART',
      'DMART',
      'GROFERS',
      'DUNZO',
      'INSTAMART',
      'SWIGGY INSTAMART',
      'MILKBASKET',
      'LICIOUS',
    ],
    'Shopping': [
      'AMAZON',
      'FLIPKART',
      'MYNTRA',
      'AJIO',
      'MEESHO',
      'SNAPDEAL',
      'NYKAA',
      'TATA CLIQ',
      'FIRSTCRY',
      'LENSKART',
      'CROMA',
    ],
    'Travel': [
      'IRCTC',
      'MAKEMYTRIP',
      'GOIBIBO',
      'CLEARTRIP',
      'YATRA',
      'IXIGO',
      'REDBUS',
      'ABHIBUS',
      'EASEMYTRIP',
      'INDIGO',
      'SPICEJET',
      'AIRINDIA',
    ],
    'Transportation': ['UBER', 'OLA', 'RAPIDO', 'MERU', 'METRO', 'DMRC'],
    'Entertainment': [
      'NETFLIX',
      'HOTSTAR',
      'PRIME VIDEO',
      'SPOTIFY',
      'GAANA',
      'SONY LIV',
      'ZEE5',
      'BOOKMYSHOW',
      'PVR',
      'INOX',
    ],
    'Health & Medical': [
      'APOLLO',
      'PHARMEASY',
      'NETMEDS',
      '1MG',
      'TATA 1MG',
      'PRACTO',
      'CULT.FIT',
    ],
    'Bills & Utilities': [
      'AIRTEL',
      'JIO',
      'VI ',
      'VODAFONE',
      'BSNL',
      'ELECTRICITY',
      'BESCOM',
      'TATA POWER',
      'DTH',
      'TATA SKY',
      'DISH TV',
    ],
    'Education': [
      'BYJU',
      'UNACADEMY',
      'VEDANTU',
      'UPGRAD',
      'COURSERA',
      'UDEMY',
    ],
  };

  /// Detect category from SMS message based on merchant keywords
  static String? detectCategory(String message) {
    final upperMessage = message.toUpperCase();

    for (final entry in _merchantCategories.entries) {
      for (final merchant in entry.value) {
        if (upperMessage.contains(merchant)) {
          return entry.key;
        }
      }
    }

    if (upperMessage.contains('SALARY') || upperMessage.contains('PAYROLL'))
      return 'Salary';
    if (upperMessage.contains('REFUND') || upperMessage.contains('REVERSAL'))
      return 'Refund';

    return null;
  }

  /// Check if the SMS is from a bank
  static bool isBankSms(String sender) {
    final upperSender = sender.toUpperCase();
    return _bankSenderPatterns.any(
          (pattern) => upperSender.contains(pattern),
        ) ||
        // Generic patterns for bank SMS
        upperSender.contains('BANK') ||
        RegExp(r'^[A-Z]{2}-[A-Z]+$').hasMatch(upperSender);
  }

  /// Parse an SMS message to extract transaction details
  /// Returns null if the message is not a valid transaction SMS
  static TransactionModel? parseTransaction(
    String sender,
    String message,
    DateTime receivedAt,
  ) {
    if (!isBankSms(sender)) return null;

    final upperMessage = message.toUpperCase();

    // Skip non-transaction messages
    if (_isNonTransactionMessage(upperMessage)) return null;

    // Determine transaction type
    final type = _getTransactionType(upperMessage);
    if (type == null) return null;

    // Extract amount
    final amount = _extractAmount(message);
    if (amount == null || amount <= 0) return null;

    // Extract account info
    final accountInfo = _extractAccountInfo(message);

    // Auto-detect category from merchant
    final category = detectCategory(message);

    return TransactionModel(
      amount: amount,
      type: type,
      sender: sender,
      message: message,
      detectedAt: receivedAt,
      accountInfo: accountInfo,
      category: category,
    );
  }

  /// Check if this is a non-transaction message (OTP, alerts, etc.)
  static bool _isNonTransactionMessage(String upperMessage) {
    final nonTransactionKeywords = [
      'OTP',
      'ONE TIME PASSWORD',
      'VERIFICATION CODE',
      'PIN',
      'CVV',
      'CARD BLOCKED',
      'CARD ACTIVATED',
      'LOGIN',
      'LOGGED IN',
      'PASSWORD CHANGED',
      'UPDATED YOUR',
      'REGISTERED',
      'LINKED',
      'REWARD POINTS',
      'CASHBACK EARNED',
      'OFFER',
      'PROMO',
      'DISCOUNT',
      'DUE DATE',
      'MINIMUM DUE',
      'STATEMENT',
      'BILL GENERATED',
    ];

    return nonTransactionKeywords.any(
      (keyword) => upperMessage.contains(keyword),
    );
  }

  /// Determine if it's a credit or debit transaction using weighted scoring
  static TransactionType? _getTransactionType(String upperMessage) {
    // SPECIAL CASE: UPI Transfer pattern
    // "Rs.X debited... and credited to [recipient]" = This is a DEBIT
    // The "credited to" refers to the recipient, not to your account
    if (upperMessage.contains('DEBITED') &&
        (upperMessage.contains('CREDITED TO') ||
            upperMessage.contains('AND CREDITED'))) {
      return TransactionType.debit;
    }

    // SPECIAL CASE: Money received pattern
    // "Rs.X credited... from [sender]" or "received from" = This is a CREDIT
    if ((upperMessage.contains('CREDITED') ||
            upperMessage.contains('RECEIVED')) &&
        upperMessage.contains(' FROM ') &&
        !upperMessage.contains('DEBITED')) {
      return TransactionType.credit;
    }

    // Strong indicators - these are definitive keywords
    final strongDebitKeywords = [
      'DEBITED',
      'DEBITED FROM',
      'WITHDRAWN',
      'SPENT',
      'DR.',
      'DR ',
      'ATM WDL',
      'MONEY SENT',
      'SENT TO',
      'PAID TO',
      'TRANSFERRED TO',
    ];

    final strongCreditKeywords = [
      'CREDITED',
      'RECEIVED',
      'DEPOSITED',
      'CR.',
      'CR ',
      'MONEY RECEIVED',
      'RECEIVED FROM',
      'CREDITED FROM',
      'REFUND',
      'CASHBACK',
      'REVERSAL',
      'REVERSED',
    ];

    // Weak indicators - these could appear in either context
    final weakDebitKeywords = [
      'PAID',
      'TRANSFERRED',
      'PURCHASE',
      'PAYMENT',
      'SENT',
      'TXN',
      'TRANSACTION',
      'VIA UPI',
    ];

    final weakCreditKeywords = ['ADDED', 'CREDIT'];

    int debitScore = 0;
    int creditScore = 0;

    // Check strong keywords first (weight: 10 points)
    for (final keyword in strongDebitKeywords) {
      if (upperMessage.contains(keyword)) {
        debitScore += 10;
      }
    }

    for (final keyword in strongCreditKeywords) {
      if (upperMessage.contains(keyword)) {
        creditScore += 10;
      }
    }

    // If we have a clear winner from strong keywords, return immediately
    if (debitScore > 0 && creditScore == 0) {
      return TransactionType.debit;
    }
    if (creditScore > 0 && debitScore == 0) {
      return TransactionType.credit;
    }

    // Check weak keywords (weight: 2 points)
    for (final keyword in weakDebitKeywords) {
      if (upperMessage.contains(keyword)) {
        debitScore += 2;
      }
    }

    for (final keyword in weakCreditKeywords) {
      if (upperMessage.contains(keyword)) {
        creditScore += 2;
      }
    }

    // Context-based adjustments for UPI/IMPS transfers
    // Pattern: "to [name]" suggests money going OUT (debit)
    if (RegExp(r'\bTO\s+[A-Z]').hasMatch(upperMessage)) {
      debitScore += 5;
    }

    // Pattern: "from [name]" without debited suggests money coming IN (credit)
    if (RegExp(r'\bFROM\s+[A-Z]').hasMatch(upperMessage) &&
        !upperMessage.contains('DEBITED')) {
      creditScore += 5;
    }

    // Determine result based on scores
    if (debitScore > creditScore) {
      return TransactionType.debit;
    } else if (creditScore > debitScore) {
      return TransactionType.credit;
    }

    // If scores are equal and both > 0, favor debit (more common in banking SMS)
    if (debitScore > 0 && creditScore > 0) {
      return TransactionType.debit;
    }

    return null;
  }

  /// Extract amount from the message
  static double? _extractAmount(String message) {
    // Patterns to match amounts in various formats
    final patterns = [
      // Rs. 1,234.56 or Rs 1234.56 or Rs.1234
      RegExp(r'RS\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
      // INR 1,234.56 or INR1234
      RegExp(r'INR\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
      // ₹1,234.56 or ₹ 1234
      RegExp(r'₹\s*([\d,]+\.?\d*)'),
      // Rupees 1234
      RegExp(r'RUPEES?\s*([\d,]+\.?\d*)', caseSensitive: false),
      // Amount: 1234.56 or Amt: 1234
      RegExp(r'AMT\.?:?\s*RS?\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
      // for Rs.1234 (specific format)
      RegExp(r'(?:FOR|OF)\s+RS\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.group(1) != null) {
        // Remove commas and parse
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    return null;
  }

  /// Extract account information (last 4 digits of account/card)
  static String? _extractAccountInfo(String message) {
    // Patterns to match account numbers
    final patterns = [
      // A/c XX1234 or A/c No. XX1234 or Acct XX1234
      RegExp(
        r'A/?C(?:CT)?\.?\s*(?:NO\.?)?\s*[X*]*(\d{4})',
        caseSensitive: false,
      ),
      // Account ending 1234 or Account XX1234
      RegExp(r'ACCOUNT\s*(?:ENDING)?\s*[X*]*(\d{4})', caseSensitive: false),
      // Card XX1234 or Card ending 1234
      RegExp(r'CARD\s*(?:ENDING|NO\.?)?\s*[X*]*(\d{4})', caseSensitive: false),
      // **1234 or XX1234 followed by typical separators
      RegExp(r'[X*]{2,}(\d{4})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.group(1) != null) {
        return 'XX${match.group(1)}';
      }
    }

    return null;
  }
}
