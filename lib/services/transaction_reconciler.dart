import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_model.dart';
import 'app_events.dart';
import 'database_service.dart';
import 'notification_parser_service.dart';

/// One transaction row that might be the "other half" of an incoming capture.
/// A value type so the twin-picking rules stay pure and unit-testable without
/// a database, mirroring how the statement importer tests its dedup.
class TwinCandidate {
  final int id;
  final int detectedAtMs;
  final String? merchantName;
  final bool isManual;

  const TwinCandidate({
    required this.id,
    required this.detectedAtMs,
    this.merchantName,
    this.isManual = false,
  });
}

/// Matches the two captures of one real-world payment — the bank SMS and the
/// payment-app notification — so it is counted exactly once.
///
/// Why this exists: fingerprints cannot do it. A fingerprint hashes the full
/// message text and sender, and the SMS ("Rs.250 debited from A/c…") and the
/// notification ("₹250 paid to Swiggy") share neither, so the unique index
/// happily stores both. The twin test is therefore fuzzy — same type, same
/// amount, close in time — plus a payee guard so two real ₹50 autos to
/// different people half an hour apart are never merged into one.
///
/// Direction of resolution is asymmetric, by data richness:
///  - An SMS arriving second **absorbs** its notification twin: the row keeps
///    its identity (id, payment-time, every user edit) but takes the SMS's
///    sender/message/account/fingerprint, because the SMS names the account
///    and reference and — critically — its fingerprint must be in the table
///    so the next inbox rescan recognises the payment as already captured.
///  - A notification arriving second is simply **dropped**: the SMS (or the
///    user's own manual entry) already tells the story better.
///
/// Everything here is gated behind [captureEverEnabled]: until the user has
/// switched notification capture on at least once, the SMS pipeline never
/// even runs the twin query, keeping the pre-feature hot path byte-identical.
class TransactionReconciler {
  /// How far apart the two captures of one payment can land. Bank SMS
  /// usually trails the app notification by seconds-to-minutes; half an hour
  /// absorbs congested-telco stragglers while staying far too narrow to
  /// merge genuinely separate same-amount payments (which the payee guard
  /// protects against as well). Deliberately narrower than the statement
  /// importer's ±1 day: that flow shows a review UI before dropping
  /// anything, this one decides silently, so it must be conservative.
  static const Duration twinWindow = Duration(minutes: 30);

  /// Preference key remembering that capture was enabled at least once.
  /// Never reset — leftover NOTIF rows may need absorbing even after the
  /// user turns the feature back off.
  static const String everEnabledKey = 'notif_capture_ever_enabled';

  static bool? _everEnabledMemo;

  /// Test seam: reset the memoised flag between tests.
  static void resetMemoForTest() => _everEnabledMemo = null;

  final DatabaseService _db = DatabaseService();

  /// Whether the twin machinery should run at all. Memoised true-forever
  /// once seen; false is re-read (cheap cached-prefs hit) so enabling the
  /// feature takes effect without a restart in every isolate.
  static Future<bool> captureEverEnabled() async {
    if (_everEnabledMemo == true) return true;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(everEnabledKey) ?? false;
    if (v) _everEnabledMemo = true;
    return v;
  }

  static Future<void> markEverEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(everEnabledKey, true);
    _everEnabledMemo = true;
  }

  // ── Pure decision core ───────────────────────────────────────────────────

  /// Normalise a payee for the guard: case/spacing/punctuation-insensitive.
  static String _normPayee(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Whether two payee names could describe the same counterparty. Unknown
  /// (null/empty) on either side allows the match — the amount+time+type
  /// test carries it; a containment check tolerates "Swiggy" vs "Swiggy
  /// Limited". Two known, unrelated names veto the twin.
  static bool payeesCompatible(String? a, String? b) {
    if (a == null || b == null) return true;
    final na = _normPayee(a), nb = _normPayee(b);
    if (na.isEmpty || nb.isEmpty) return true;
    return na.contains(nb) || nb.contains(na);
  }

  /// Pick the twin of a capture at [detectedAtMs] with payee [merchantName]
  /// from same-type same-amount [candidates]: the nearest-in-time candidate
  /// inside [twinWindow] whose payee doesn't contradict. Null when none fit.
  static TwinCandidate? pickTwin({
    required int detectedAtMs,
    required String? merchantName,
    required List<TwinCandidate> candidates,
  }) {
    TwinCandidate? best;
    int? bestGap;
    for (final c in candidates) {
      final gap = (c.detectedAtMs - detectedAtMs).abs();
      if (gap > twinWindow.inMilliseconds) continue;
      if (!payeesCompatible(merchantName, c.merchantName)) continue;
      if (bestGap == null || gap < bestGap) {
        best = c;
        bestGap = gap;
      }
    }
    return best;
  }

  // ── SMS side: absorb into the notification twin ──────────────────────────

  /// Called from the SMS insert paths (after their own fingerprint-exists
  /// check said "new"). When a notification-sourced twin exists, merge the
  /// SMS identity into that row and report true so the caller skips its
  /// insert — and its alert, which the notification already fired.
  ///
  /// First line is the global gate: for users who never enabled capture this
  /// returns false before touching the database.
  Future<bool> absorbIntoNotifTwin(TransactionModel smsTxn) async {
    if (!await captureEverEnabled()) return false;

    final rows = await _db.findTwinCandidates(
      type: smsTxn.type,
      amount: smsTxn.amount,
      around: smsTxn.detectedAt,
      window: twinWindow,
      notificationSourced: true,
    );
    if (rows.isEmpty) return false;

    final twin = pickTwin(
      detectedAtMs: smsTxn.detectedAt.millisecondsSinceEpoch,
      merchantName: smsTxn.merchantName,
      candidates: [
        for (final r in rows)
          TwinCandidate(
            id: r['id'] as int,
            detectedAtMs: r['detected_at'] as int,
            merchantName: r['merchant_name'] as String?,
          ),
      ],
    );
    if (twin == null) return false;

    final row = await _db.getTransactionById(twin.id);
    if (row == null) return false;

    // Merge: the row keeps its identity and every user edit; the SMS
    // contributes the richer capture. Taking the SMS fingerprint is the
    // load-bearing part — the next inbox rescan must find this payment.
    final merged = row.copyWith(
      sender: smsTxn.sender,
      message: smsTxn.message,
      accountInfo: smsTxn.accountInfo ?? row.accountInfo,
      fingerprint: smsTxn.fingerprint,
      parseSource: smsTxn.parseSource,
      // A payee the notification failed to extract (or that the user
      // hasn't touched) upgrades to the SMS's; a user-classified row's
      // stays put.
      merchantName: (row.isClassified && row.merchantName != null)
          ? row.merchantName
          : (smsTxn.merchantName ?? row.merchantName),
    );
    // copyWith can't null out review flags; a row the user already
    // confirmed (or that parsed clean) must not get re-flagged by the merge.
    final upgraded = (row.reviewReasons == null || row.reviewReasons!.isEmpty)
        ? merged.confirmedReview()
        : merged;
    await _db.updateTransaction(upgraded);
    // Live screens show the absorbed row; a bare notifier bump, so calling
    // this from the background isolate (no listeners there) is a no-op.
    notifyAppDataChanged();
    return true;
  }

  // ── Notification side: defer to anything already there ───────────────────

  /// Whether an incoming notification capture should be dropped because the
  /// payment is already represented: by an SMS row, by the user's own manual
  /// entry (they logged the chai themselves — respect it), or by a tombstone
  /// (they deleted this payment minutes ago; a second capture channel must
  /// not resurrect what the first channel's deletion tombstoned).
  Future<bool> shouldDropIncomingNotifTxn(TransactionModel notifTxn) async {
    final rows = await _db.findTwinCandidates(
      type: notifTxn.type,
      amount: notifTxn.amount,
      around: notifTxn.detectedAt,
      window: twinWindow,
      notificationSourced: false,
    );
    final twin = pickTwin(
      detectedAtMs: notifTxn.detectedAt.millisecondsSinceEpoch,
      merchantName: notifTxn.merchantName,
      candidates: [
        for (final r in rows)
          TwinCandidate(
            id: r['id'] as int,
            detectedAtMs: r['detected_at'] as int,
            merchantName: r['merchant_name'] as String?,
            isManual: (r['is_manual'] as int? ?? 0) == 1,
          ),
      ],
    );
    if (twin != null) return true;

    return _db.deletedTwinExists(
      type: notifTxn.type,
      amount: notifTxn.amount,
      around: notifTxn.detectedAt,
      window: twinWindow,
    );
  }
}

/// Convenience used by exports/UI to recognise the source without importing
/// the parser.
bool isNotificationSourced(TransactionModel t) =>
    NotificationParserService.isNotificationSender(t.sender);
