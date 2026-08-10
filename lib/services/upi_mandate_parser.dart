import '../models/upi_mandate.dart';
import 'sms_parser_service.dart';

/// Reads UPI-mandate (autopay) registration SMS.
///
/// A mandate SMS is the only moment a bank *tells you a subscription exists*.
/// Everything else the Recurring screen knows has to be typed in by hand, or
/// inferred from three months of look-alike debits — which means a new
/// subscription is invisible until its third charge. This parser turns the
/// registration alert into a suggestion on the day you subscribe.
///
/// The hard part is telling the two halves apart, because both say "UPI
/// Mandate":
///
///   creation  "Your UPI-Mandate for Rs.1950.00 is successfully created
///              towards Google Play from A/c No: XXXX…  -SBI"
///   execution "UPI Mandate: Sent Rs.1999.00 from HDFC Bank A/c 9463
///              To Google Play 11/06/26 Ref 258129441626"
///
/// Only the second one moved money. A creation is recognised by a
/// registration phrase ([_creationPhrases]) **and** the absence of any
/// completed-transaction verb once future-tense wording ("will be debited")
/// is discounted — see [looksLikeCreation]. Getting that boundary right
/// matters twice over: the creation must not be logged as a ₹1950 credit
/// (SBI's wording used to be), and the execution must not be swallowed as a
/// mere notice (ICICI's autopay debit used to be).
class UpiMandateParser {
  UpiMandateParser._();

  /// Wording that only appears when a mandate is being registered.
  static final RegExp _creationPhrases = RegExp(
    r'\bMANDATE\b[\s\S]{0,40}?\b(?:CREATED|SET|REGISTERED|ACTIVATED)\b'
    r'|\bMANDATE\s+SET\b'
    r'|\bUNIQUE\s+MANDATE\s+NUMBER\b'
    r'|\bUMN\b\s*[:\-]'
    r'|(?:WILL|SHALL)\s+BE\s+DEBITED[\s\S]{0,90}?\b(?:AUTOPAY|MANDATE)\b',
    caseSensitive: false,
  );

  /// Wording for a mandate's *later life* rather than one of its charges: the
  /// autopay being revoked, paused or modified, and the hold on the money
  /// being lifted. Nothing settles at any of these moments — the block a
  /// mandate places was never logged as a debit, so releasing it cannot be a
  /// credit.
  ///
  /// Reported from a device on 2026-08-10, from an allowlisted header, so no
  /// promo-route filter ever saw it:
  ///
  ///   "BOI UPI-Mandate revoked for Coursera Rs.2099.00.Funds unblocked from
  ///    A/C No. XXXXXXXXXXX7848 Umn 6c33…@okicici Ref no 603466871809"
  ///
  /// "unblocked from A/C" scored as a credit and nothing objected, so a
  /// cancelled subscription was logged as ₹2,099 of *income*.
  /// [_creationPhrases] could not catch it twice over: this UMN is written
  /// `Umn <id>` with no colon or dash, and "revoked" is not a registration
  /// verb.
  static final RegExp _lifecyclePhrases = RegExp(
    r'\bMANDATE\b[\s\S]{0,60}?'
    r'\b(?:REVOKED|CANCELLED|CANCELED|PAUSED|SUSPENDED|RESUMED|MODIFIED'
    r'|EXPIRED|DECLINED|STOPPED|FAILED)\b'
    r'|\b(?:REVOKED|CANCELLED|CANCELED|PAUSED|SUSPENDED|RESUMED|MODIFIED'
    r'|STOPPED)\b[\s\S]{0,60}?\bMANDATE\b'
    r'|\bFUNDS\s+(?:UN)?BLOCKED\b',
    caseSensitive: false,
  );

  /// Verbs that mean money actually moved. Deliberately narrower than the
  /// parser's own list: "DEBIT FOR" appears inside "will be debited for".
  static final RegExp _settledVerbs = RegExp(
    r'\b(?:DEBITED|CREDITED|WITHDRAWN|DEPOSITED|SPENT|SENT\s+RS|DR\.)\b',
    caseSensitive: false,
  );

  /// Future-tense wording, removed before looking for settled verbs so
  /// "will be debited for Rs 3000 on 23-Jul-26" doesn't read as a debit.
  static final RegExp _futureTense = RegExp(
    r'\b(?:WILL|SHALL)\s+BE\s+\w+(?:ED)?\b',
    caseSensitive: false,
  );

  /// Whether [message] announces a mandate being created rather than one
  /// being charged. Public because the transaction parser has to ask the same
  /// question — it must refuse to log these as income/spend.
  static bool looksLikeCreation(String message) {
    if (!_creationPhrases.hasMatch(message)) return false;
    final settled = message.replaceAll(_futureTense, ' ');
    return !_settledVerbs.hasMatch(settled);
  }

  /// Whether [message] reports what became of a mandate — revoked, paused,
  /// modified, or its held funds released — rather than a charge under one.
  /// Public for the same reason as [looksLikeCreation]: the transaction
  /// parser has to refuse to log these.
  ///
  /// Guarded by the same escape hatch, so an execution that happens to
  /// mention a cancellation ("Rs 500 debited … mandate cancelled") is still
  /// the debit it says it is.
  static bool looksLikeLifecycleNotice(String message) {
    if (!_lifecyclePhrases.hasMatch(message)) return false;
    final settled = message.replaceAll(_futureTense, ' ');
    return !_settledVerbs.hasMatch(settled);
  }

  /// Parse a mandate registration. Returns null when [message] isn't one, or
  /// when the merchant/amount can't be read — a suggestion with no name or no
  /// figure is worse than no suggestion.
  static UpiMandate? parse(String sender, String message, DateTime receivedAt) {
    if (SmsParserService.senderTrust(sender) == SenderTrust.none) return null;
    if (!looksLikeCreation(message)) return null;

    final amount = _amount(message);
    if (amount == null || amount <= 0) return null;

    final merchant = _merchant(message);
    if (merchant == null) return null;

    return UpiMandate(
      merchant: merchant,
      amount: amount,
      firstDebitOn: _firstDebit(message),
      umn: _umn(message),
      accountInfo: SmsParserService.extractAccountInfo(message),
      sender: sender,
      message: message,
      detectedAt: receivedAt,
    );
  }

  /// Who the mandate pays, tried most-specific first. Each bank frames it
  /// differently, and the generic "towards {X}" catch-all runs last so a
  /// better-anchored read always wins.
  static String? _merchant(String message) {
    final patterns = <RegExp>[
      // ICICI: "…towards Autopay for ICCL GROWW AUTO, UPI Mandate, Unique…"
      RegExp(
        r'\btowards\s+Autopay\s+for\s+(.+?)(?:\s*,|\s+on\b|\.|\n|$)',
        caseSensitive: false,
      ),
      // BOI / SBI: "…is successfully created towards SPOTIFY INDIA PVT LTD
      // for Rs.139.00." / "…created towards Google Play from A/c No:…"
      RegExp(
        r'\bcreated\s+towards\s+(.+?)'
        r'(?:\s+for\s+Rs\b|\s+from\b|\s*,|\.|\n|$)',
        caseSensitive: false,
      ),
      // HDFC: "Mandate Set\nRs.1999.00\nFor Google Play\nFrom HDFC Bank…"
      RegExp(r'(?:^|\n)\s*For\s+(.+?)(?:\n|$)', caseSensitive: false),
      // Anything else that names the beneficiary after "towards".
      RegExp(
        r'\btowards\s+(.+?)(?:\s+for\s+Rs\b|\s+from\b|\s*,|\.|\n|$)',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final raw = p.firstMatch(message)?.group(1)?.trim();
      if (raw == null || raw.length < 3) continue;
      // "for Rs.1999" and bare reference numbers are not merchants.
      if (RegExp(r'^(?:rs\.?|inr|₹)?[\d,.]+$', caseSensitive: false)
          .hasMatch(raw)) {
        continue;
      }
      final cleaned = SmsParserService.cleanMerchantName(raw);
      if (cleaned != null) return cleaned;
    }
    return null;
  }

  static double? _amount(String message) {
    // Mandate alerts quote one figure, but strip any balance for safety so a
    // bank that appends "Avl Bal" can't hand us the wrong number.
    final cleaned = message.replaceAll(
      RegExp(
        r'\b(?:AVL|AVBL|AVAILABLE|TOTAL)?\.?\s*BAL(?:ANCE)?\.?\s*'
        r'(?:IS|:|-)?\s*(?:RS\.?|INR|₹)?\s*[\d,]+(?:\.\d+)?',
        caseSensitive: false,
      ),
      ' ',
    );
    final m = RegExp(
      r'(?:\bRS\.?|\bINR\.?|₹)\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    final raw = m?.group(1)?.replaceAll(',', '');
    return raw == null ? null : double.tryParse(raw);
  }

  /// The stated first-debit date, e.g. ICICI's "…for Rs 3000.00 on 23-Jul-26".
  static DateTime? _firstDebit(String message) {
    final m = RegExp(
      r'\bon\s+(\d{1,2})[-/\s]([A-Za-z]{3}|\d{1,2})[-/\s](\d{2,4})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!);
    final monthRaw = m.group(2)!;
    final month = int.tryParse(monthRaw) ?? _monthNames[monthRaw.toLowerCase()];
    var year = int.tryParse(m.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  static const Map<String, int> _monthNames = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// The bank's own id for the mandate — the dedup key when present.
  static String? _umn(String message) {
    final m = RegExp(
      r'(?:Unique\s+Mandate\s+Number|\bUMN\b)\s*[:\-]?\s*([\w.\-]+@[\w.\-]*|[\w\-]{8,})',
      caseSensitive: false,
    ).firstMatch(message);
    final umn = m?.group(1)?.trim();
    return (umn == null || umn.isEmpty) ? null : umn;
  }
}
