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

  /// Nothing at all could be extracted — a template miss that belongs in the
  /// review queue. The parser used to answer this case with the account
  /// number itself; it no longer does, because the account is one side of
  /// the transaction and so can never be the other (see
  /// SmsParserService.isAccountLikePayee). Rows written before that change
  /// carried such a payee; the schema-28 migration re-reads them with today's
  /// parser (DatabaseService.rereadAccountFallbackPayee), and
  /// DatabaseService.isAccountFallbackPayee still recognises the shape so no
  /// leftover can ever be taught as an alias.
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

  /// Whether the payee needs a user glance: no template or generic pattern
  /// could name the counterparty.
  bool get payeeUnknown => kind == PayeeSource.none;
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

  /// A counterparty the shape itself identifies, with nothing to capture —
  /// e.g. Canara's "…CREDITED to your account … towards interest", where the
  /// other party is the bank paying you interest. When set, [pattern] only
  /// has to match: the name is this, and no capture group is required.
  final String? fixedName;

  BankTemplate(
    this.rail,
    String pattern, {
    this.nameIsVpa = false,
    this.verified = true,
    this.fixedName,
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
    // Spelled with "BANK" so the mention is as specific as a substring test
    // can make it — bare "IDBI" also sits inside "SIDBI".
    ('IDBI BANK', 'IDBI'),
    // Canara signs off as "- Canara Bank" or "-CanaraBank"; the mention is
    // spelled without the space so both forms are recognised. Listed last so
    // a message that names two banks still tries the others first.
    ('CANARA', 'Canara'),
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
      // ACH/NACH narration — dividends, interest warrants, mandate debits:
      //   "ICICI Bank Account XX197 credited:Rs. 11.50 on 05-Jun-26.
      //    Info ACH*IRB INFRASTRUCTURE D*164. Available Balance is …"
      //   "… Info ACH*BANK OF BARODA*13975693. …"
      // The counterparty is the star-delimited segment between the rail and
      // the numeric reference. These messages name nobody with "from"/"to",
      // so every one of them used to land in the review queue unnamed. The
      // remitter is often an institution ("BANK OF BARODA"), which the
      // generic "from {PAYER}" rule deliberately refuses — a registered
      // template is exactly the right place to allow it.
      BankTemplate('ACH credit', r'\bInfo:?\s*N?ACH\*([^*]+?)\*'),
    ],
    'HDFC': [
      // "for NEFT Cr-ICIC0099999-GODREJ AND BOYCE MFG CO LTD-…" — the
      // remitter is the 2nd dash-delimited segment, after the IFSC.
      BankTemplate('NEFT credit', r'NEFT\s+Cr-[A-Za-z0-9]+-([^-]+)-'),
      // "For IMPS -BUREAUIDIndia- 618502233593" — remitter between dashes,
      // before the numeric ref.
      BankTemplate('IMPS credit', r'IMPS\s*-\s*([^-]+?)\s*-\s*\d'),
      // "UPDATE: INR 1,96,901.00 debited from HDFC Bank XX9463 on 27-AUG-26.
      //  Info: FLYWIRE TXN RFX 270826FLYT03707. Avl bal:INR 2,021.93"
      //
      // HDFC's "UPDATE:" alerts carry the counterparty in a free-text Info
      // narration instead of a "to"/"from" clause, so nothing in the generic
      // cascade could reach it and a real payment (Flywire, the tuition
      // remitter — device report, Aug '26) landed in the review queue with
      // no payee at all. The narration is "{NAME} {ref tokens}": the name is
      // the leading letters-and-spaces run, ending at a reference keyword,
      // at the first digit-bearing token, or at the first character that
      // cannot be part of a name.
      //
      // Listed LAST in the pack so the two rail templates above keep their
      // messages. Narrations that open with a rail code or with pure
      // transaction narration are refused outright rather than filed as a
      // payee: those shapes are read elsewhere ("UPI-<ref>-<name>" by the
      // generic cascade, "TRANSFER TO {NAME}" by its "paid/sent/transfer to"
      // rule), and refusing simply leaves today's behaviour — the review
      // queue — in place instead of inventing a payee named "Payment".
      //
      // The colon is load-bearing: it is what makes this the narration FIELD
      // rather than the word. Footers say "For more info visit hdfcbank.com"
      // and "for more info, call 18002586161", and an optional colon let the
      // capture run into those and file "Visit Hdfcbank" as the payee.
      BankTemplate(
        'Info narration',
        r'\bInfo:\s*'
        r'(?!(?:UPI|N?ACH|NEFT|IMPS|RTGS|ECS|EDC|POS|ATM|ATW|NWD|EMI|CHQ'
        r'|BRN|TPT|MMT|VPS|INF|IB|MB|CC|DC|SI|FT'
        r'|PAYMENT|PAYMT|TRANSFER|TRF|CASH|DEBIT|CREDIT|DEPOSIT|WITHDRAWAL'
        r'|REV|REVERSAL|CHARGES?|FEES?|GST|TAX|INT|INTEREST|SALARY'
        r'|BAL|AVL|ACCOUNT|SELF)\b)'
        r'([A-Za-z][A-Za-z& ]{2,}?)'
        r'(?:\s+(?:TXN|TRANSACTION|TRAN|REF|RFX|RRN|UTR|ID)\b'
        r'|\s+\S*\d'
        r'|(?![A-Za-z& ]))',
      ),
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
    'IDBI': [
      // "IDBI Bank Acct XX450 debited for Rs 10.00 on 14-Aug-26;
      //  Bal Rs 2020.93 Indian Railways credited. UPI:622698872431.
      //  To Block UPI send SMS UPIBLOCK <Mob. No> to 07799000423 ..."
      //
      // IDBI names the counterparty by its own side of the ledger — "{NAME}
      // credited" — and prints the running balance between the two sides, so
      // no "to"/"from" rule could reach the name and every UPI spend
      // collapsed to the "UPI Transfer" placeholder (four device reports,
      // Aug '26: Indian Railways, MR DIY, Blinkit). Consuming the balance
      // figure explicitly is what keeps the capture from starting at "Bal".
      BankTemplate(
        'UPI transfer-out',
        r'\bdebited\b[\s\S]*?[;:]\s*Bal\s+(?:Rs|INR)\.?\s*[\d,]+(?:\.\d+)?'
        r'\s+([A-Za-z][A-Za-z0-9 .&\-]{1,}?)\s+credited\b',
      ),
      // The mirror: money arriving names the payer with "debited". Drafted
      // from the debit format above — no incoming sample yet, so it stays
      // unverified. Listed second because a debit alert also contains the
      // word "credited"; the debit template above claims those first.
      BankTemplate(
        'UPI credit',
        r'\bcredited\b[\s\S]*?[;:]\s*Bal\s+(?:Rs|INR)\.?\s*[\d,]+(?:\.\d+)?'
        r'\s+([A-Za-z][A-Za-z0-9 .&\-]{1,}?)\s+debited\b',
        verified: false,
      ),
    ],
    'Canara': [
      // "An amount of INR 149.00 has been CREDITED to your account XXXX2278
      //  on 28/06/2026 towards interest. Total Avail.bal INR 14,995.54.
      //  - Canara Bank" — a savings-interest payout. Nobody is named because
      // the other party is the bank itself, so the generic "towards {X}"
      // rule read the literal word ("Interest"). Name it for what it is, the
      // same way fee debits are named "Bank Charges", so every interest
      // credit across accounts groups under one payee and one tag rule.
      BankTemplate(
        'interest credit',
        r'\bcredit(?:ed)?\b[\s\S]*?\btowards\s+interest\b',
        fixedName: 'Bank Interest',
      ),
      // "Dear Customer, Acct XXXX2278 Dr. INR 20,000.00 on 02/07/26 to
      //  pinkygala77@; UPI: 654976813375; Bal INR 14,995.54.Not you?SMS
      //  BLOCKUPI to 9901771222-CanaraBank"
      // Canara masks the UPI handle away, leaving a VPA that stops at the
      // "@" — no generic VPA rule matches it, so the payee collapsed to the
      // "UPI Transfer" placeholder even though the message names the person.
      // Anchored on the "Dr." debit marker so it can never read a credit,
      // and on an "@"-bearing token so the trailing "SMS BLOCKUPI to
      // 9901771222" instruction can't be mistaken for a payee.
      BankTemplate(
        'UPI transfer-out',
        r'\bDr\.\s[\s\S]*?\bto\s+([\w.\-]+@[\w.\-]*)',
        nameIsVpa: true,
      ),
    ],
  };
}
