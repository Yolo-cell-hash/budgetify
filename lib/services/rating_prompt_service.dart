import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entitlement_service.dart';

/// Asks for a Play Store rating once the user has actually lived with the app.
///
/// Called "rating", not "review", on purpose: everywhere else in this codebase
/// "review" means the tidy-up queue of low-confidence transactions, and a
/// `ReviewService` sitting next to `RemovalService` would read as part of that.
///
/// ## Why the timing is what it is
///
/// The window is four weeks from **first install**, not from first launch of
/// the current data. [EntitlementService.firstLaunchAt] is the right clock
/// because it is already floored to Android's package install record and
/// carried across a reinstall by the portable anchor — so clearing app data or
/// reinstalling does not hand someone a fresh four weeks, and, more to the
/// point, does not re-ask a user who already answered.
///
/// ## Play's rules, which shape the API here
///
/// Google's in-app review guidelines forbid pre-prompting — no "Enjoying
/// Budgetify?" gate, no custom dialog in front, nothing that filters who gets
/// asked by predicted sentiment. So there is deliberately no UI in this file:
/// it calls the platform and Google renders its own card, in the user's own
/// Play language, which is also why this needed no new l10n strings.
///
/// The call is quota-limited and gives back **no signal** — not whether the
/// card appeared, not whether anyone rated. So "we asked" is the strongest
/// thing that can ever be recorded, and [maybeAsk] is written to be honest
/// about that: a throw or an unavailable platform re-arms rather than burning
/// the one chance.
class RatingPromptService {
  RatingPromptService._();
  static final RatingPromptService instance = RatingPromptService._();

  /// Four weeks from first install, per product decision.
  static const Duration waitAfterInstall = Duration(days: 28);

  /// A user with almost nothing logged has nothing to review yet, and asking
  /// them is how you collect one-star "doesn't do anything" ratings. This is a
  /// floor on *having something to say*, not a second time gate.
  static const int minTransactions = 5;

  /// Gap between attempts once one has been made. Play may silently show
  /// nothing (quota), so a single attempt cannot be treated as the answer —
  /// but nor should the app nag.
  static const Duration retryAfter = Duration(days: 60);

  /// Stop after this many attempts, ever. Someone who has ignored the card
  /// three times has answered.
  static const int maxAsks = 3;

  static const String _askCountKey = 'rating_prompt_ask_count';
  static const String _lastAskedKey = 'rating_prompt_last_asked_at';

  @visibleForTesting
  static const String askCountKey = _askCountKey;
  @visibleForTesting
  static const String lastAskedKey = _lastAskedKey;

  /// Swappable so tests never reach the platform channel.
  @visibleForTesting
  InAppReview platform = InAppReview.instance;

  /// Whether [maybeAsk] would ask, given the world as described.
  ///
  /// Pure and separated from the plumbing because this is the part worth
  /// testing: the platform call cannot be exercised in a unit test, and cannot
  /// be exercised on a sideloaded build either.
  ///
  /// Both time comparisons are between absolute instants, not local midnights,
  /// so they are unaffected by the DST date-diff trap that bites
  /// `difference().inDays` elsewhere in this codebase.
  @visibleForTesting
  static bool shouldAsk({
    required DateTime now,
    required DateTime? firstLaunch,
    required DateTime? lastAsked,
    required int askCount,
    required int transactionCount,
  }) {
    // No anchor means EntitlementService has not initialized yet. Silence is
    // the safe answer — the next launch will have one.
    if (firstLaunch == null) return false;
    if (askCount >= maxAsks) return false;
    if (transactionCount < minTransactions) return false;
    // Negative durations (clock moved back, or an anchor floored to a future
    // install record) read as "not yet", never as "overdue".
    if (now.difference(firstLaunch) < waitAfterInstall) return false;
    if (lastAsked != null && now.difference(lastAsked) < retryAfter) {
      return false;
    }
    return true;
  }

  /// Ask, if it is time to. Safe to call on every Home appearance.
  ///
  /// [transactionCount] is passed in rather than queried so this never opens
  /// the database on the UI path — Home already knows the number.
  ///
  /// Every failure is silent and leaves the counter untouched, so an
  /// unavailable platform (no Play Store, a sideloaded build, an emulator
  /// without Play services) costs nothing and simply tries again next time.
  Future<void> maybeAsk({required int transactionCount, DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = now ?? DateTime.now();
      final lastAskedMs = prefs.getInt(_lastAskedKey);

      if (!shouldAsk(
        now: at,
        firstLaunch: EntitlementService().firstLaunchAt,
        lastAsked: lastAskedMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastAskedMs),
        askCount: prefs.getInt(_askCountKey) ?? 0,
        transactionCount: transactionCount,
      )) {
        return;
      }

      // Checked immediately before asking, not cached: availability depends on
      // the Play Store app being present and signed in, which can change
      // between launches.
      if (!await platform.isAvailable()) return;

      await platform.requestReview();

      // Recorded only after the call came back without throwing. If it threw,
      // nothing was shown and nothing is spent.
      await prefs.setInt(_askCountKey, (prefs.getInt(_askCountKey) ?? 0) + 1);
      await prefs.setInt(_lastAskedKey, at.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('RatingPromptService.maybeAsk skipped: $e');
    }
  }

  /// Open the store listing directly — for the explicit "Rate Budgetify" row
  /// in Settings, where the user asked for it and the quota-limited in-app
  /// card would be the wrong tool (it may simply not appear).
  Future<void> openStoreListing() async {
    try {
      await platform.openStoreListing(appStoreId: null);
    } catch (e) {
      debugPrint('RatingPromptService.openStoreListing failed: $e');
    }
  }

  /// Clear the counters. Used by the "Clear all data" path so a wiped install
  /// behaves like the fresh one it is presenting itself as.
  @visibleForTesting
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_askCountKey);
    await prefs.remove(_lastAskedKey);
  }
}
