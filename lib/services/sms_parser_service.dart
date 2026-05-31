import '../models/transaction_model.dart';

/// Service for parsing bank SMS messages to extract transaction details
class SmsParserService {
  // Common Indian bank sender patterns
  static final List<String> _bankSenderPatterns = [
    'SBIINB',
    'SBIATM',
    'SBISMS',
    'HDFCBK',
    'ICICIB',
    'ICICIT',
    'AXISBK',
    'KOTAKB',
    'PNBSMS',
    'BOIIND',
    'BOISMS',
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
    'MAHABNK',
    'BOMSMS',
    'CENTBK',
    'SCBSMS',
    'CITIBNK',
    'DBISHR',
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

    // Extract merchant/payee name from SMS body
    final merchantName = _extractMerchant(message, accountInfo);

    // Auto-detect category from merchant
    final category = detectCategory(message);

    return TransactionModel(
      amount: amount,
      type: type,
      sender: sender,
      message: message,
      detectedAt: receivedAt,
      accountInfo: accountInfo,
      merchantName: merchantName,
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

    // HDFC-style: "Sent Rs.X" at beginning is a strong debit
    if (RegExp(r'^\s*SENT\s+RS', caseSensitive: false).hasMatch(upperMessage)) {
      debitScore += 15;
    }

    // SBI-style: "UPI frm A/c" is a strong debit (money going from your account)
    if (upperMessage.contains('UPI FRM') || upperMessage.contains('UPI FROM')) {
      debitScore += 15;
    }

    // "IS DEBITED" pattern (BOM, ICICI)
    if (upperMessage.contains('IS DEBITED')) {
      debitScore += 15;
    }

    // "DEBITED BY" pattern (BOM)
    if (upperMessage.contains('DEBITED BY')) {
      debitScore += 15;
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
      // A/c XX1234 or A/c No. XX1234 or Acct XX1234 or Ac XXXXXX1234
      RegExp(
        r'A/?C(?:CT)?\.?\s*(?:NO\.?)?\s*[X*]*([\d]{4})',
        caseSensitive: false,
      ),
      // Account ending 1234 or Account XX1234
      RegExp(r'ACCOUNT\s*(?:ENDING)?\s*[X*]*([\d]{4})', caseSensitive: false),
      // Card XX1234 or Card ending 1234
      RegExp(r'CARD\s*(?:ENDING|NO\.?)?\s*[X*]*([\d]{4})', caseSensitive: false),
      // a/c **1234 or a/c *1234 (Axis, Kotak style)
      RegExp(r'A/?C\s*\*+([\d]{4})', caseSensitive: false),
      // **1234 or XX1234 followed by typical separators
      RegExp(r'[X*]{2,}([\d]{4})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.group(1) != null) {
        return 'XX${match.group(1)}';
      }
    }

    return null;
  }

  /// Public static method to extract merchant from a message.
  /// Used by DatabaseService during backfill operations.
  static String? extractMerchantStatic(String message, String? accountInfo) {
    return _extractMerchant(message, accountInfo);
  }

  /// Extract merchant/payee name from the SMS body.
  ///
  /// Tries multiple bank-specific and generic patterns. Falls back to
  /// the account number if no merchant name can be determined.
  ///
  /// Priority order:
  /// 1. ICICI Info: field — `Info: UPI-RefNo-MerchantName`
  /// 2. BOI/generic — `credited to {NAME} via UPI`
  /// 3. HDFC — `To {NAME}` (on same or next line)
  /// 4. Generic — `paid to / sent to / transferred to {NAME}`
  /// 5. UPI VPA — `VPA {name}@bank` or `{name}@{bank}` → extract name
  /// 6. Axis — `to VPA {name}@{bank}`
  /// 7. Fallback — account number (A/cXX1234)
  static String? _extractMerchant(String message, String? accountInfo) {
    String? merchant;

    // --- Pattern 1: ICICI "Info:" field ---
    // "Info: UPI-123456789012-MerchantName"
    // "Info: UPI/123456789012/MerchantName"
    final infoMatch = RegExp(
      r'Info:\s*UPI[-/]\d+[-/](.+?)(?:\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (infoMatch != null) {
      merchant = _cleanMerchant(infoMatch.group(1));
      if (merchant != null) return merchant;
    }

    // --- Pattern 2: BOI "credited to {NAME} via UPI" ---
    // "debited...and credited to KIRTI PRAHALAD PANCHAL via UPI"
    final creditedToVia = RegExp(
      r'credited\s+to\s+(.+?)\s+via\b',
      caseSensitive: false,
    ).firstMatch(message);
    if (creditedToVia != null) {
      merchant = _cleanMerchant(creditedToVia.group(1));
      if (merchant != null) return merchant;
    }

    // --- Pattern 3: HDFC "To {NAME}" ---
    // "Sent Rs.30.00\nFrom HDFC Bank A/C *9463\nTo Mumbai Metro Ghatkopar"
    final toPattern = RegExp(
      r'(?:^|\n)\s*To\s+(.+?)(?:\n|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toPattern != null) {
      final candidate = toPattern.group(1)?.trim();
      // Make sure it's not "To block" or "To 7308080808" (instruction text)
      if (candidate != null &&
          candidate.length > 2 &&
          !RegExp(r'^\d+$').hasMatch(candidate) &&
          !candidate.toUpperCase().startsWith('BLOCK') &&
          !candidate.toUpperCase().startsWith('REPORT')) {
        merchant = _cleanMerchant(candidate);
        if (merchant != null) return merchant;
      }
    }

    // --- Pattern 4: Generic "paid to / sent to / transferred to {NAME}" ---
    // Avoid matching "sent to 9215676766" or "call to ..."
    final paidTo = RegExp(
      r'(?:paid|sent|transferred)\s+to\s+(.+?)(?:\s*\.|,|\s+on\s|\s+via\s|\s+ref\b|\s+Ref\b|\n|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (paidTo != null) {
      final candidate = paidTo.group(1)?.trim();
      if (candidate != null &&
          candidate.length > 2 &&
          !RegExp(r'^\d+$').hasMatch(candidate) &&
          !candidate.toUpperCase().startsWith('BLOCK')) {
        merchant = _cleanMerchant(candidate);
        if (merchant != null) return merchant;
      }
    }

    // --- Pattern 5: UPI VPA in body ---
    // "to VPA username@okaxis" or just "username@okaxis" or "username@ybl"
    final vpaPatterns = [
      // "to VPA username@bank"
      RegExp(r'(?:to\s+)?VPA\s+([\w.]+)@[\w.]+', caseSensitive: false),
      // Standalone UPI VPA like "username@okaxis", "name@ybl", "name@paytm"
      RegExp(
        r'\b([\w.]{3,})@(?:ok(?:axis|icici|sbi|hdfc)|ybl|paytm|upi|apl|ibl|axl|sbi|okhdfcbank|okbizaxis)\b',
        caseSensitive: false,
      ),
    ];
    for (final vpaRegex in vpaPatterns) {
      final vpaMatch = vpaRegex.firstMatch(message);
      if (vpaMatch != null) {
        final vpaName = vpaMatch.group(1);
        if (vpaName != null && vpaName.length > 2) {
          // Clean up VPA name: replace dots/underscores with spaces, title case
          final cleaned = vpaName
              .replaceAll(RegExp(r'[._]'), ' ')
              .trim();
          if (cleaned.isNotEmpty) {
            return _titleCase(cleaned);
          }
        }
      }
    }

    // --- Pattern 6: "by UPI Ref No" with merchant in preceding text ---
    // BOM: "debited by Rs 500.00 on 30-05-26 by UPI Ref No 123456789012"
    // No merchant info available here, fall through

    // --- Fallback: Use account number as merchant identifier ---
    if (accountInfo != null && accountInfo.isNotEmpty) {
      return accountInfo;
    }

    return null;
  }

  /// Clean up extracted merchant string
  static String? _cleanMerchant(String? raw) {
    if (raw == null) return null;

    // Trim whitespace and trailing punctuation
    var cleaned = raw.trim().replaceAll(RegExp(r'[.,;:!\s]+$'), '');

    // Remove trailing "Ref" or "Ref No" fragments
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*Ref(?:\s*No)?\.?\s*\d*\s*$', caseSensitive: false),
      '',
    ).trim();

    // Remove phone numbers and "call/SMS/click" instructions
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*(?:call|sms|click|fwd|forward)\s.*$', caseSensitive: false),
      '',
    ).trim();

    // Remove "Not You?" or "If not done by u" trailing text
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*(?:Not\s*You|If\s+not).*$', caseSensitive: false),
      '',
    ).trim();

    // If too short or just numbers, return null
    if (cleaned.length < 2 || RegExp(r'^\d+$').hasMatch(cleaned)) {
      return null;
    }

    return _titleCase(cleaned);
  }

  /// Title-case a string: "MUMBAI METRO GHATKOPAR" → "Mumbai Metro Ghatkopar"
  static String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
