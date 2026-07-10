/// Per-bank SMS template packs.
///
/// TRAI's DLT regime forces banks to register their SMS templates, so each
/// bank's alert formats are a small, stable set. Instead of one global
/// pattern cascade (where every new pattern risks colliding with another
/// bank's wording — Kotak/IPPB/HDFC/BOM patterns all had to be retro-scoped
/// after collisions), each bank with known formats gets its own pack of
/// anchored templates, tried FIRST. The generic cascade in
/// SmsParserService only runs when no template matches, and its output is
/// marked lower-confidence so the review queue can surface it.
///
/// Every template regex here is moved VERBATIM from the previously
/// bank-scoped patterns in SmsParserService._extractMerchant — behaviour is
/// pinned by the corpus in test/sms_parser_test.dart. Add new banks (PNB,
/// BoB, Canara, Union…) only from real message samples; drafted formats
/// must be marked with [BankTemplate.verified] = false so their hits still
/// land in the review queue until confirmed.
library;

/// Where a payee/merchant name came from — the parser's confidence signal.
enum PayeeSource {
  /// Matched a registered bank template — highest confidence.
  bankTemplate,

  /// Matched one of the generic cross-bank patterns — a named counterparty,
  /// but from heuristics rather than a known template.
  generic,

  /// A curated placeholder the parser is sure about ("ATM", "Bank Charges",
  /// "UPI Transfer") — accurate, but not an individual identity.
  placeholder,

  /// The account-number fallback — the parser found no counterparty; this
  /// is a template miss and belongs in the review queue.
  accountFallback,

  /// Nothing at all could be extracted.
  none,
}

/// The result of merchant extraction: the name plus its provenance.
class MerchantExtraction {
  final String? name;

  /// Human-readable origin, e.g. "HDFC · NEFT credit" or "General patterns".
  /// Shown as fine print on the transaction detail screen and stored on the
  /// transaction for debugging user reports.
  final String source;

  final PayeeSource kind;

  const MerchantExtraction(this.name, this.source, this.kind);

  /// Whether the payee needs a user glance: the parser either guessed from
  /// an unmatched template (account fallback) or found nothing.
  bool get payeeUnknown =>
      kind == PayeeSource.accountFallback || kind == PayeeSource.none;
}

/// One registered SMS shape for a bank: how to read the counterparty out of
/// a message that matches [pattern] (the name is capture group 1).
class BankTemplate {
  /// Short rail label for the parse-source line, e.g. "NEFT credit".
  final String rail;

  final RegExp pattern;

  /// When true, group(1) may be a UPI VPA ("paytm.s21upj5@pty") — render
  /// its local part ("Paytm S21upj5") instead of cleaning it as a name.
  final bool nameIsVpa;

  /// Templates drafted without a real message sample must set this false so
  /// their extractions still land in the review queue until confirmed.
  final bool verified;

  BankTemplate(
    this.rail,
    String pattern, {
    this.nameIsVpa = false,
    this.verified = true,
  }) : pattern = RegExp(pattern, caseSensitive: false);
}

class BankTemplates {
  /// Message-mention → bank id, in priority order. Identification is
  /// message-based (not sender-based) deliberately: the pre-pack patterns
  /// were scoped on message mentions, and DatabaseService keys payee
  /// aliases via extractMerchantStatic(message) where no sender exists —
  /// message-based identification keeps parse-time and alias-key extraction
  /// byte-identical.
  static const List<(String, String)> _mentions = [
    ('ICICI', 'ICICI'),
    ('HDFC', 'HDFC'),
    ('KOTAK', 'Kotak'),
    ('IPPB', 'IPPB'),
    ('BANK OF MAHARASHTRA', 'BOM'),
  ];

  /// Banks named in [message] that have a template pack, in priority order.
  /// A message can mention two banks (e.g. an HDFC credit naming an ICICI
  /// IFSC in the narration) — every mentioned pack gets a chance, and a
  /// wrong first guess just falls through to the next.
  static List<String> identifyBanks(String message) {
    final upper = message.toUpperCase();
    return [
      for (final (mention, bank) in _mentions)
        if (upper.contains(mention)) bank,
    ];
  }

  /// The registered template packs. Regexes are verbatim moves of the
  /// previously inline bank-scoped patterns; tests pin each one.
  static final Map<String, List<BankTemplate>> packs = {
    'ICICI': [
      // "Info: UPI-123456789012-MerchantName" (also UPI/…/…)
      BankTemplate('UPI narration', r'Info:\s*UPI[-/]\d+[-/](.+?)(?:\.|$)'),
      // "Acct XX197 debited for Rs 73.00 on 16-Jun-26; JAY RAJESH KEER
      // credited." — recipient named BEFORE the verb, after a semicolon.
      BankTemplate(
        'UPI transfer-out',
        r'\bdebited\b[\s\S]*?[;:]\s*([A-Za-z][A-Za-z .&\-]{2,}?)\s+credited\b',
      ),
    ],
    'HDFC': [
      // "for NEFT Cr-ICIC0099999-GODREJ AND BOYCE MFG CO LTD-…" — the
      // remitter is the 2nd dash-delimited segment, after the IFSC.
      BankTemplate('NEFT credit', r'NEFT\s+Cr-[A-Za-z0-9]+-([^-]+)-'),
      // "For IMPS -BUREAUIDIndia- 618502233593" — remitter between dashes,
      // before the numeric ref.
      BankTemplate('IMPS credit', r'IMPS\s*-\s*([^-]+?)\s*-\s*\d'),
    ],
    'Kotak': [
      // "Sent Rs.60.00 from Kotak Bank AC X9883 to paytm.s21upj5@pty on
      // 27-06-26" — counterparty between "to" and " on <date>". Kotak
      // credits say "from … on", never "to {X} on", so this stays debit-only.
      BankTemplate('UPI transfer-out', r'\bto\s+(.+?)\s+on\b', nameIsVpa: true),
    ],
    'IPPB': [
      // "A/C X4434 Debit Rs.20.00 for UPI to ramjeet on 29-06-26 Ref …"
      BankTemplate('UPI transfer-out', r'\bto\s+(.+?)\s+on\b', nameIsVpa: true),
      // "received a payment of Rs. 140.00 … from padarthi santhosh ku thru
      // IPPB" — payer between "from" and "thru/through".
      BankTemplate('UPI credit', r'\bfrom\s+(.+?)\s+thr(?:u|ough)\b'),
    ],
    'BOM': [
      // "A/c XX7763 credited with Rs. 453.00 on 01-Jul-26 from Miss
      // AISHWARYA RRN: 125560855601" — payer between "from" and the
      // RRN/ref/footer. BOM debits say "debited", so requiring "credited"
      // first keeps them out.
      BankTemplate(
        'UPI credit',
        r'\bcredited\b[\s\S]*?\bfrom\s+([A-Za-z][A-Za-z. ]+?)'
        r'(?:\s+RRN\b|\s+Ref(?:\s*No)?\b|\s+UTR\b|\s*[-.,]|\s+on\b|\n|$)',
      ),
      // "A/c X7763 debited by Rs. 101.00 for UPI payment to aish872k okaxis
      // on 09-Jul-26. RRN: 619085826595 …" — counterparty between
      // "UPI payment to" and the " on <date>" that always follows. Names
      // real people ("SANTOSH ANANT G") and VPAs alike; BOM strips the "@"
      // from VPAs ("aish872k okaxis"), which the nameIsVpa renderer
      // recognises by the trailing UPI-handle token. The nameless shape
      // ("debited … by UPI Ref No …") has no "payment to" and still rides
      // the generic cascade.
      BankTemplate(
        'UPI transfer-out',
        r'\bdebited\b[\s\S]*?\bUPI payment to\s+(.+?)\s+on\b',
        nameIsVpa: true,
      ),
    ],
  };
}
