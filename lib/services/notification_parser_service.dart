import '../models/transaction_model.dart';
import 'sms_parser_service.dart';

/// Parser for payment-app notifications ("₹250 paid to Swiggy") — the second
/// capture source next to bank SMS.
///
/// Philosophy: **precision over recall, strictly.** A missed sub-₹100 chai is
/// the status quo (banks no longer SMS it either); a false positive corrupts
/// the spending totals the whole app is built on. So a notification only
/// parses when it names an amount AND a completed-action verb, and a long
/// reject list runs first. Anything ambiguous returns null and is forgotten.
///
/// This is deliberately a separate parser, not an extension of
/// [SmsParserService]: bank-SMS narration and app-notification copy are
/// different languages (DLT headers vs package names, "debited from A/c
/// XX1234" vs "You paid Ramesh"), and keeping the grammars apart means the
/// battle-tested SMS path is not touched at all by this feature.
/// How much of a payment app's activity its notifications can actually
/// account for. Not every app on the allowlist is equally useful, and the app
/// says which is which rather than letting the user assume "enabled" means
/// "complete".
enum NotifCoverage {
  /// **Both directions.** The app posts a notification for money going out
  /// *and* money coming in, so its alerts alone keep the ledger whole even
  /// when the bank sends no SMS at all.
  bothWays,

  /// **Money in only.** The app announces credits, but confirms the user's
  /// own payments on a success *screen* inside the app instead of posting a
  /// notification — there is nothing to read for a debit. This is not a gap
  /// in Budgetify's grammar; the alert is never posted, so no parser could
  /// catch it. Spends through these apps still depend on the bank SMS.
  creditsOnly,
}

class NotificationParserService {
  /// Mirror of the Kotlin allowlist (TxnNotificationListener.kt), package →
  /// label + how much that app's alerts cover. Kotlin filters FIRST —
  /// nothing off that list ever reaches Dart — this mirror is the second
  /// gate and the source of both the label and the coverage note in the UI.
  /// Keep the two in sync when adding an app.
  ///
  /// Coverage is observed behaviour, not a promise by the app: UPI apps
  /// showing a confirmation screen at the end of a payment have no reason to
  /// also post a notification the user would only see by pulling down the
  /// shade they are already past. PayZapp is the exception that does both.
  static const Map<String, WatchedApp> watchedPackages = {
    'com.google.android.apps.nbu.paisa.user':
        WatchedApp('GPay', NotifCoverage.creditsOnly),
    'com.phonepe.app': WatchedApp('PhonePe', NotifCoverage.creditsOnly),
    'net.one97.paytm': WatchedApp('Paytm', NotifCoverage.creditsOnly),
    'in.org.npci.upiapp': WatchedApp('BHIM', NotifCoverage.creditsOnly),
    'com.dreamplug.androidapp': WatchedApp('CRED', NotifCoverage.creditsOnly),
    'in.amazon.mShop.android.shopping':
        WatchedApp('Amazon Pay', NotifCoverage.creditsOnly),
    'com.mobikwik_new': WatchedApp('MobiKwik', NotifCoverage.creditsOnly),
    'com.freecharge.android':
        WatchedApp('Freecharge', NotifCoverage.creditsOnly),
    // HDFC's UPI/wallet app, and the one app that alerts on both directions
    // ("Payment sent successfully — Your payment of Rs.200 to … was
    // successful" / "Received Money — You received Rs.1 from …"). It is not
    // the HDFC Bank app — that one stays off the list, its payments already
    // arriving as richer bank SMS.
    'com.enstage.wibmo.hdfc': WatchedApp('PayZapp', NotifCoverage.bothWays),
  };

  /// Apps whose alerts cover both directions, in allowlist order. Drives the
  /// "these apps see everything" group in Settings.
  static List<WatchedApp> get bothWaysApps => [
        for (final a in watchedPackages.values)
          if (a.coverage == NotifCoverage.bothWays) a,
      ];

  /// Apps that only ever announce money coming in, in allowlist order.
  static List<WatchedApp> get creditsOnlyApps => [
        for (final a in watchedPackages.values)
          if (a.coverage == NotifCoverage.creditsOnly) a,
      ];

  /// Sender prefix marking a notification-sourced transaction, following the
  /// statement importer's 'IMPORT-<label>' convention. Everything downstream
  /// (tombstones, exports, the reconciler) keys off this.
  static const String senderPrefix = 'NOTIF-';

  static bool isNotificationSender(String sender) =>
      sender.startsWith(senderPrefix);

  // ── Reject grammar ───────────────────────────────────────────────────────
  // Shapes that are ABOUT money but are not a completed payment by the user.
  // Each entry is a double-count or noise vector:
  //  - requests/collect: "Rahul requested ₹500" — nothing moved yet.
  //  - failed/pending/scheduled: not completed (and may complete later via a
  //    second notification, which would then double with this one).
  //  - refunds: land as a bank credit days later — the bank SMS is the truth.
  //  - cashback/rewards/offers/scratch cards: promo noise, tiny amounts.
  //  - wallet top-ups: the bank-side debit SMS already records the money
  //    leaving; counting the wallet's "added" copy would double it.
  //  - reminders/due: recurring-bill territory, not a transaction.
  static final RegExp _rejectRegex = RegExp(
    r'request|failed|declined|unsuccessful|pending|processing|will be\b'
    r'|scheduled|reminder|overdue|\bdue\b|expir|offer|cashback|reward'
    r'|scratch|\bwin\b|\bwon\b|invite|refer|coupon|voucher|deal\b|% ?off'
    r'|loan|kyc|verify|\botp\b|refund|added to (?:your )?wallet'
    r'|wallet balance|low balance|autopay set|mandate|bill generated'
    r'|अनुरोध|विफल|असफल|लंबित|रिफ़ंड|रिफंड|कैशबैक|ऑफ़र|ऑफर',
    caseSensitive: false,
  );

  // ── Accept grammar ───────────────────────────────────────────────────────
  // Completed-action verbs only. Present/future tense never matches.
  static final RegExp _debitRegex = RegExp(
    r"\bpaid\b|\bsent\b|\bdebited\b|payment (?:of .{0,40})?(?:successful|completed|done)"
    r'|purchase of|transferred to|money sent'
    r'|भुगतान (?:किया|सफल|हुआ)|भेजे गए|भेजा गया|का भुगतान',
    caseSensitive: false,
  );

  static final RegExp _creditRegex = RegExp(
    r'\breceived\b|\bcredited\b|\bdeposited\b|money received'
    r'|प्राप्त (?:हुए|हुई|किया)|जमा (?:हुए|किया)',
    caseSensitive: false,
  );

  /// ₹ / Rs / INR amounts, Indian digit grouping included ("1,23,456.78").
  static final RegExp _amountRegex = RegExp(
    r'(?:₹|Rs\.?\s?|INR\s?)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  /// "to [payee]" / "at [payee]" for debits, "from [payee]" for credits.
  /// The lazy capture stops at connective words, punctuation, a currency
  /// marker, or the em-dash [parse] joins title and body with, so trailing
  /// copy ("via HDFC Bank", "— Paid successfully") stays out of the name.
  ///
  /// `was`/`were` are in the connective list for PayZapp's shape, which puts
  /// the verdict *after* the name ("… to Ashokkumar Sharma was successful.")
  /// where every other app puts it before. Without them the capture runs to
  /// the full stop and the payee becomes "Ashokkumar Sharma Was".
  static final RegExp _payeeToRegex = RegExp(
    r'\b(?:to|at)\s+([^.,\n₹—]{2,60}?)(?=\s+(?:via|using|from|on|for|is|was|were|has|था|में)\b|\s*(?:₹|Rs\.?\s|INR\s)|[.,\n!—]|$)',
    caseSensitive: false,
  );
  static final RegExp _payeeFromRegex = RegExp(
    r'\bfrom\s+([^.,\n₹—]{2,60}?)(?=\s+(?:via|using|on|for|is|was|were|has)\b|\s*(?:₹|Rs\.?\s|INR\s)|[.,\n!—]|$)',
    caseSensitive: false,
  );

  /// Parse one captured notification into a transaction, or null when it
  /// doesn't clearly describe a completed payment. Never throws.
  static TransactionModel? parse({
    required String packageName,
    required String title,
    required String text,
    String bigText = '',
    required DateTime postedAt,
  }) {
    // Second privacy gate: a package Dart doesn't recognise (version skew
    // against the Kotlin list) is dropped, not guessed at.
    final app = watchedPackages[packageName];
    if (app == null) return null;
    final appLabel = app.label;

    // The visible copy, title first — payment apps lead with the amount
    // there ("₹250 paid to Swiggy"). BIG_TEXT replaces TEXT when it extends
    // it (expanded style), so prefer the longer of the two.
    final body = bigText.length > text.length ? bigText : text;
    final composed = [title, body]
        .where((s) => s.trim().isNotEmpty)
        .join(' — ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (composed.isEmpty) return null;

    // Reject first: a "payment request" also contains the word "payment".
    if (_rejectRegex.hasMatch(composed)) return null;

    final isDebit = _debitRegex.hasMatch(composed);
    final isCredit = _creditRegex.hasMatch(composed);
    // Both ("received your payment towards…") is ambiguous → drop; the
    // reject-first rule already removed the request/collect shapes.
    if (isDebit == isCredit) return null;
    final type = isDebit ? TransactionType.debit : TransactionType.credit;

    final amountMatch = _amountRegex.firstMatch(composed);
    if (amountMatch == null) return null;
    final amount =
        double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    // Sanity bounds: zero/negative never; ≥ ₹10 crore is not a phone payment.
    if (amount == null || amount <= 0 || amount >= 100000000) return null;

    final payee = _extractPayee(composed, debit: isDebit);

    var txn = TransactionModel(
      amount: amount,
      type: type,
      sender: '$senderPrefix$appLabel',
      message: composed,
      detectedAt: postedAt,
      merchantName: payee,
      category: SmsParserService.detectCategory(composed),
      isManual: false,
      parseSource: 'app alert · $appLabel',
      // No payee extracted → same one-tap review flow SMS template misses
      // use, so the user can name it and (via aliases) teach the parser.
      reviewReasons: payee == null ? ReviewReasons.payeeUnknown : null,
    );

    // Reuse the merchant-keyword table exactly as the SMS paths do.
    txn = SmsParserService.classifyFromMerchantName(txn);
    return txn;
  }

  /// Pull the counterparty out of "to/at/from [name]" copy and clean it into
  /// a display name; null when nothing trustworthy is there.
  static String? _extractPayee(String composed, {required bool debit}) {
    final match = debit
        ? _payeeToRegex.firstMatch(composed)
        : _payeeFromRegex.firstMatch(composed);
    var raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;

    // A VPA ("swiggy@axis", "q674828@ybl"): keep the handle before the '@'
    // when it reads like a name, else give up rather than store noise.
    if (raw.contains('@')) {
      final handle = raw.split('@').first.trim();
      final letters = RegExp(r'[a-zA-Z]').allMatches(handle).length;
      if (letters < 3 || RegExp(r'^\d+$').hasMatch(handle)) return null;
      raw = handle;
    }

    // Strip leftover currency/trailing verbs the lookahead may have kept.
    raw = raw
        .replaceAll(RegExp(r'\b(successfully|successful|completed)\b',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (raw.length < 2) return null;
    if (raw.length > 40) raw = raw.substring(0, 40).trim();

    // Pure digits / masked accounts are the "payee unknown" case, not a name.
    if (RegExp(r'^[\dXx*\- ]+$').hasMatch(raw)) return null;

    return _titleCase(raw);
  }

  static String _titleCase(String input) => input
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : (w.length == 1
              ? w.toUpperCase()
              : w[0].toUpperCase() + w.substring(1).toLowerCase()))
      .join(' ');
}

/// One entry of the payment-app allowlist: the short name shown to the user
/// and how much of that app's activity its notifications can account for.
class WatchedApp {
  /// Short display name, also the suffix of the row's sender ("NOTIF-GPay")
  /// and of its "Read by" line ("app alert · GPay").
  final String label;

  /// What that app's alerts actually announce — see [NotifCoverage].
  final NotifCoverage coverage;

  const WatchedApp(this.label, this.coverage);
}
