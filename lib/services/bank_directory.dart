import '../models/transaction_model.dart';
import 'bank_alias_service.dart';
import 'bank_directory_data.dart';
import 'sms_parser_service.dart';
import 'statement_import_service.dart';

/// Where a transaction came from, once its sender has been read.
enum BankKind {
  /// Resolved to a real bank in the DLT header registry.
  bank,

  /// A statement import whose label named no bank we recognise — grouped
  /// under the label the user typed.
  imported,

  /// Typed in by hand; there is no sender to read.
  manual,

  /// A bank SMS whose header isn't in the registry. Grouped under the raw
  /// header, which is at least stable and distinct per bank.
  unknown,
}

/// One money source: a bank, an import label, or manual entry.
///
/// [id] is the stable grouping key — everything (filters, exports, totals) is
/// wired to it, and it is derived from the sender header alone. [name] is
/// only what the user reads: their own name for this bank when they have set
/// one, otherwise [defaultName], what the directory detected.
///
/// Renaming therefore never moves money between rows; it changes a label.
class BankIdentity {
  final String id;
  final String name;

  /// What the directory detected, before any user rename — the "reset to"
  /// value, and what a fresh install would show.
  final String defaultName;

  final BankKind kind;

  const BankIdentity(this.id, this.name, this.kind, {String? defaultName})
      : defaultName = defaultName ?? name;

  /// Whether the user has given this bank a name of their own.
  bool get isRenamed => name != defaultName;

  static const String manualId = '__manual__';

  /// Manual entries carry the localised "Manual entry" text as their sender,
  /// so they're grouped on the flag instead — a language switch must not
  /// split one bucket in two.
  static const BankIdentity manual =
      BankIdentity(manualId, 'Manual entry', BankKind.manual);

  static const String unnamedId = '__unknown__';

  /// A transaction that came from somewhere, but the sender was blank — a
  /// malformed message or a bad import. Deliberately NOT [manual]: nobody
  /// typed it in, and filing it under the user's own entries would be a
  /// quiet lie about where their money went.
  static const BankIdentity unnamed =
      BankIdentity(unnamedId, 'Unknown', BankKind.unknown);

  /// Whether this is the nameless bucket above — there is no header to show
  /// alongside the "unknown" label.
  bool get isUnnamed => id == unnamedId;

  @override
  bool operator ==(Object other) => other is BankIdentity && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'BankIdentity($id)';
}

/// Reads the bank behind a transaction from its SMS sender header.
///
/// Indian bank alerts arrive under DLT-registered sender headers — "HDFCBK",
/// "SBIUPI", "BOIIND" — and `list_of_banks.txt` maps 1525 of them to the
/// filing entity. [kHeadersByBank] is that registry, collapsed to one display
/// name per bank (see `tool/gen_bank_directory.py`), which is what makes
/// bank-wise totals possible at all: the 273 headers State Bank of India
/// files under have to land in one bucket, not 273.
class BankDirectory {
  BankDirectory._();

  /// Headers the app's own sender allowlist carries that the DLT registry
  /// file doesn't map. Hand-curated; each one is unambiguous by prefix.
  static const Map<String, String> _extraHeaders = {
    // State Bank of India
    'SBISMS': 'State Bank of India',
    'SBIYONO': 'State Bank of India',
    'CSBSBI': 'State Bank of India',
    // HDFC
    'HDFCCN': 'HDFC Bank',
    'HDFCTX': 'HDFC Bank',
    'HDFCBF': 'HDFC Bank',
    // ICICI
    'ICICIT': 'ICICI Bank',
    'ICICIP': 'ICICI Bank',
    'ICICIC': 'ICICI Bank',
    'ICICIA': 'ICICI Bank',
    // Axis
    'AXISBNK': 'Axis Bank',
    'AXISBI': 'Axis Bank',
    'AXCHG': 'Axis Bank',
    // Public sector
    'PNBINF': 'Punjab National Bank',
    'BOISMS': 'Bank of India',
    'CNRBNK': 'Canara Bank',
    'CANARA': 'Canara Bank',
    'UBIINB': 'Union Bank of India',
    'IDBIMS': 'IDBI Bank',
    'BARODA': 'Bank of Baroda',
    'MAHABNK': 'Bank of Maharashtra',
    'BOMSMS': 'Bank of Maharashtra',
    // Private
    'YESBAK': 'YES Bank',
    'FEDERA': 'Federal Bank',
    'RBLSMS': 'RBL Bank',
    'INDUSN': 'IndusInd Bank',
    'INDUSI': 'IndusInd Bank',
    'SIBLTD': 'South Indian Bank',
    'KVBLTD': 'Karur Vysya Bank',
    'JKBNK': 'J&K Bank',
    'SARBNK': 'Saraswat Co-operative Bank',
    'KBLSMS': 'Karnataka Bank',
    'KVBBNK': 'Karur Vysya Bank',
    'KVBSMS': 'Karur Vysya Bank',
    'SIBBNK': 'South Indian Bank',
    'SIBPLZ': 'South Indian Bank',
    'SARASW': 'Saraswat Co-operative Bank',
    'BANDHN': 'Bandhan Bank',
    'BDHNBK': 'Bandhan Bank',
    'BNDHNB': 'Bandhan Bank',
    'CBIINB': 'Central Bank of India',
    'IOBAST': 'Indian Overseas Bank',
    'UCOFTN': 'UCO Bank',
    // Foreign
    'SCBSMS': 'Standard Chartered',
    'SCBLTD': 'Standard Chartered',
    'CITIBNK': 'Citibank',
    'DBISHR': 'Deutsche Bank',
    'HSBNK': 'HSBC',
    // Payments / small finance
    'IPPBANK': 'India Post Payments Bank',
    'IPPSMS': 'India Post Payments Bank',
    'AIRTELP': 'Airtel Payments Bank',
    'JIOSMS': 'Jio Payments Bank',
    'JIOBPY': 'Jio Payments Bank',
    'AUBNK': 'AU Small Finance Bank',
    'AUSFB': 'AU Small Finance Bank',
    'ESFB': 'Equitas Small Finance Bank',
    'EQUIBNK': 'Equitas Small Finance Bank',
    // Wallets and pay apps. Not banks, but they are where the money moved
    // from as far as the alert is concerned, so they get their own bucket
    // rather than being lumped in with an unreadable header.
    'GPAY': 'Google Pay',
    'PHONEPE': 'PhonePe',
    'PAYTM': 'Paytm',
    'AMAZONP': 'Amazon Pay',
    'APAY': 'Amazon Pay',
    'SIMPLPL': 'Simpl',
    'MOBIKW': 'MobiKwik',
    'KWIK24': 'MobiKwik',
    'FREECH': 'Freecharge',
    'ATLPAY': 'Airtel Payments Bank',
    // Neobanks: they front a partner bank, but the alerts come under their
    // own header and users think of them as the account.
    'JUPITR': 'Jupiter',
    'FIMONY': 'Fi Money',
    'NIYOGB': 'Niyo',
    'BAJAJF': 'Bajaj Finserv',
    'BJFLTX': 'Bajaj Finserv',
  };

  /// Bank names spelled out in a sender or import label, longest and most
  /// specific first. Only consulted when the header lookup misses, which is
  /// where full-name senders ("Bank of Maharashtra") and user-typed import
  /// labels ("HDFC Savings") land.
  ///
  /// Keys are deliberately long enough not to collide with the hundreds of
  /// co-operative banks in the directory — "Citi" would claim "Citizen
  /// Co-operative Bank", so the key is "CITIBANK"; "Jana" would claim
  /// "Janata Sahakari Bank", so the key is "JANA SMALL". Order matters where
  /// one key contains another: every "… Bank of India" has to be tried
  /// before the bare "Bank of India" that sits inside it.
  static const List<(String, String)> _mentions = [
    ('STATE BANK OF INDIA', 'State Bank of India'),
    ('CENTRAL BANK OF INDIA', 'Central Bank of India'),
    ('UNION BANK OF INDIA', 'Union Bank of India'),
    ('UNITED BANK OF INDIA', 'United Bank of India'),
    ('BANK OF MAHARASHTRA', 'Bank of Maharashtra'),
    ('BANK OF BARODA', 'Bank of Baroda'),
    ('BANK OF AMERICA', 'Bank of America'),
    ('BANK OF INDIA', 'Bank of India'),
    ('UNION BANK', 'Union Bank of India'),
    ('PUNJAB NATIONAL', 'Punjab National Bank'),
    ('PUNJAB AND SIND', 'Punjab & Sind Bank'),
    ('PUNJAB & SIND', 'Punjab & Sind Bank'),
    ('INDIAN OVERSEAS', 'Indian Overseas Bank'),
    ('STANDARD CHARTERED', 'Standard Chartered'),
    ('AMERICAN EXPRESS', 'American Express'),
    ('TAMILNAD MERCANTILE', 'Tamilnad Mercantile Bank'),
    ('KARNATAKA BANK', 'Karnataka Bank'),
    ('KARUR VYSYA', 'Karur Vysya Bank'),
    ('CITY UNION', 'City Union Bank'),
    ('SOUTH INDIAN BANK', 'South Indian Bank'),
    ('INDIAN BANK', 'Indian Bank'),
    ('INDIA POST', 'India Post Payments Bank'),
    ('AU SMALL', 'AU Small Finance Bank'),
    ('JANA SMALL', 'Jana Small Finance Bank'),
    ('KOTAK', 'Kotak Mahindra Bank'),
    ('INDUSIND', 'IndusInd Bank'),
    ('FEDERAL BANK', 'Federal Bank'),
    ('DHANLAXMI', 'Dhanlaxmi Bank'),
    ('BANDHAN', 'Bandhan Bank'),
    ('EQUITAS', 'Equitas Small Finance Bank'),
    ('UJJIVAN', 'Ujjivan Small Finance Bank'),
    ('SURYODAY', 'Suryoday Small Finance Bank'),
    ('UTKARSH', 'Utkarsh Small Finance Bank'),
    ('CITIBANK', 'Citibank'),
    ('CITI BANK', 'Citibank'),
    ('CANARA', 'Canara Bank'),
    ('HDFC', 'HDFC Bank'),
    ('ICICI', 'ICICI Bank'),
    ('AXIS', 'Axis Bank'),
    ('IDFC', 'IDFC FIRST Bank'),
    ('IDBI', 'IDBI Bank'),
    ('HSBC', 'HSBC'),
    ('AMEX', 'American Express'),
    ('ESAF', 'ESAF Small Finance Bank'),
    ('PAYTM', 'Paytm Payments Bank'),
    ('AIRTEL', 'Airtel Payments Bank'),
    ('IPPB', 'India Post Payments Bank'),
    ('FINO', 'Fino Payments Bank'),
    ('UCO BANK', 'UCO Bank'),
    ('YES BANK', 'YES Bank'),
    ('RBL', 'RBL Bank'),
    ('DCB BANK', 'DCB Bank'),
    ('CSB BANK', 'CSB Bank'),
    ('DBS', 'DBS Bank'),
    ('SBI', 'State Bank of India'),
    ('PNB', 'Punjab National Bank'),
  ];

  /// header → bank name, reversed from [kHeadersByBank] on first use.
  static Map<String, String>? _index;

  static Map<String, String> get _headerIndex {
    final cached = _index;
    if (cached != null) return cached;
    final built = <String, String>{};
    for (final entry in kHeadersByBank.entries) {
      for (final header in entry.value) {
        built[header] = entry.key;
      }
    }
    built.addAll(_extraHeaders);
    return _index = built;
  }

  /// The bank registered to a bare DLT header ("HDFCBK" → "HDFC Bank"), or
  /// null when the header isn't in the registry.
  static String? bankForHeader(String header) =>
      _headerIndex[header.trim().toUpperCase()];

  /// What [bankId] currently reads as: the user's name for it when they have
  /// set one, otherwise [detected]. For call sites that hold an id but not a
  /// live identity (a toast after a rename, a saved filter).
  static String forId(String bankId, String detected) =>
      BankAliasService().aliasFor(bankId) ?? detected;

  /// The bank named inside free text — a full-name sender or an import label.
  static String? bankMentionedIn(String text) {
    final upper = text.toUpperCase();
    for (final (mention, bank) in _mentions) {
      if (upper.contains(mention)) return bank;
    }
    return null;
  }

  /// Build an identity, letting the user's own name for it win over the
  /// detected one. The id is untouched, so renaming is purely cosmetic.
  static BankIdentity _named(String id, String detected, BankKind kind) {
    final alias = BankAliasService().aliasFor(id);
    return BankIdentity(id, alias ?? detected, kind, defaultName: detected);
  }

  /// The money source behind [transaction].
  static BankIdentity resolve(TransactionModel transaction) =>
      transaction.isManual
          ? _named(BankIdentity.manualId, BankIdentity.manual.name,
              BankKind.manual)
          : forSender(transaction.sender);

  /// The money source behind a raw SMS sender / import sender string.
  static BankIdentity forSender(String sender) {
    final trimmed = sender.trim();
    if (trimmed.isEmpty) {
      return _named(BankIdentity.unnamedId, BankIdentity.unnamed.name,
          BankKind.unknown);
    }

    if (trimmed.toUpperCase().startsWith(StatementImportService.senderPrefix)) {
      final label =
          trimmed.substring(StatementImportService.senderPrefix.length).trim();
      // An "HDFC Savings" statement is HDFC money — merge it with the bank's
      // SMS rather than standing up a second row for the same account.
      final bank = bankMentionedIn(label);
      if (bank != null) return _named(bank, bank, BankKind.bank);
      final name = label.isEmpty ? 'Statement' : label;
      return _named('import:$name', name, BankKind.imported);
    }

    final header = SmsParserService.normalizeSender(trimmed);
    final byHeader = bankForHeader(header);
    if (byHeader != null) return _named(byHeader, byHeader, BankKind.bank);

    final byMention = bankMentionedIn(trimmed);
    if (byMention != null) return _named(byMention, byMention, BankKind.bank);

    // An unrecognised header is still a consistent per-bank key, so it groups
    // correctly even though we can't put a name to it — and it is the case
    // renaming helps most, turning "ZZZTOP" into whatever the user calls it.
    final fallback = header.isEmpty ? trimmed.toUpperCase() : header;
    return _named(fallback, fallback, BankKind.unknown);
  }
}
