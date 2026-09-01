import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/plus_offers.dart';
import '../models/plus_products.dart';

/// Owns the local "trial clock" — the timestamp of first app use plus a
/// monotonic last-seen guard against device-clock rollback — and, since the
/// paywall-prep phase, the local cache of PAID entitlements: whether the user
/// owns Plus (either lifetime or a still-valid subscription window) and which
/// royal avatars they've bought.
///
/// Every gate resolves through [allows], which is `trialActive || hasPlus`, so
/// nothing user-visible changes until a free window actually expires.
///
/// The COUNTDOWN stays invisible by product decision — no badge, no timer, no
/// nagging. The ENDING does not: [pendingTrialNotice] surfaces two dismissible
/// heads-ups in the last fortnight, and [shouldSendLapseNotice] arms the single
/// notification that fires when Plus-only alerts first go quiet. Without that
/// last one the gates fail silently, and four of the seven Plus features are
/// notifications — they would simply stop, teaching the user the app is broken
/// rather than that there is something to buy.
///
/// Ownership recorded here is a CACHE, not the truth. Once Play Billing is
/// wired (see BillingService), the truth is Play's `queryPurchases()` answer;
/// this cache is what lets an offline app keep working between checks.
/// Fail-open on uncertainty: a user who paid must never get locked out
/// because state was unreadable.
///
/// Storage lives in a singleton service (mirroring [CustomTagService] /
/// [GamificationService]) rather than a ChangeNotifier provider, because the
/// backup service needs to read/write the anchor without a BuildContext. The
/// reactive provider layer (trial countdown, paywall) comes later and will
/// wrap this service.
class EntitlementService {
  /// First moment the app was ever opened on this install (ms since epoch).
  static const String _firstLaunchKey = 'entitlement_first_launch_at';

  /// Monotonic "latest wall-clock we've observed" (ms since epoch). Only ever
  /// moves forward, so winding the device clock back can't rewind the trial.
  static const String _lastSeenKey = 'entitlement_last_seen_at';

  /// Whether the one-time lifetime Plus purchase is owned.
  static const String _plusLifetimeKey = 'entitlement_plus_lifetime';

  /// End of the currently-paid subscription window + grace (ms since epoch).
  /// 0 / absent = no subscription. Extended on purchase/renewal/restore.
  static const String _plusUntilKey = 'entitlement_plus_until';

  /// Royal avatar ids bought outright (₹49 one-time each). Distinct from the
  /// streak-picked royals, which GamificationService owns.
  static const String _ownedRoyalsKey = 'entitlement_owned_royals';

  /// Length of the free window.
  ///
  /// Shortened from 182 days on 2026-07-27. The binding constraint is feedback
  /// latency, not conversion: with no analytics of any kind (the release
  /// manifest strips INTERNET, so there is no telemetry SDK), Play Console
  /// revenue is the only conversion signal there is — and a six-month window
  /// meant one pricing experiment per year. Ninety days is still long enough
  /// for the habit and the history to form, which is what the paywall is
  /// actually selling back.
  static const Duration trialDuration = Duration(days: 90); // 3 months

  /// How long the one-shot welcome offer runs once the free window closes.
  static const Duration welcomeOfferDuration = Duration(days: 7);

  /// No free window is treated as having started before this instant.
  ///
  /// A one-line restart for the closed-testing cohort: an install whose anchor
  /// predates this gets its full 90 days from here, while a newer install
  /// keeps its own, later anchor. Deliberately NOT a migration flag — a
  /// "have I reset yet?" pref would live in app data, so clearing data would
  /// buy a fresh trial every single time. Clamping is idempotent instead: a
  /// wipe re-derives the SAME restart, never a new one, and the install-record
  /// floor keeps working underneath it untouched.
  ///
  /// SHIPPING NOTE: testers get their 90 days from THIS instant, not from when
  /// they install the update. Move it forward if the release slips past it.
  static final DateTime trialRestartAt = DateTime.utc(2026, 8, 15);

  /// Test-only override for [trialRestartAt]. A restart dated in the future
  /// puts every install inside its free window, which is the whole point in
  /// production and useless in a suite that needs to exercise an expired one —
  /// tests set this to a date in the deep past to make the clamp inert, or to
  /// a specific instant to exercise the restart itself. Mirrors dev mode's
  /// `debugSimulateTrialExpired`. Set it in `setUp`; nothing clears it.
  @visibleForTesting
  static DateTime? debugTrialRestartAt;

  DateTime get _restartFloor => debugTrialRestartAt ?? trialRestartAt;

  /// Days-left marks at which the paywall heads-up appears. Two, and only two:
  /// the countdown itself stays hidden by design, so these are the whole of
  /// the warning a user gets before their alerts go quiet.
  static const List<int> trialNoticeThresholds = [14, 3];

  /// Heads-ups the user has dismissed, tagged with the trial end they belong
  /// to — so any change to the window (a restart, a purchase) re-arms them.
  static const String _noticeDismissedKey =
      'entitlement_trial_notice_dismissed';

  /// The trial end for which the "alerts are paused" notice has been sent.
  static const String _lapseNoticeKey = 'entitlement_lapse_notice_for';

  /// Android's package install record (see MainActivity.kt). Read-only, no
  /// permission, absent everywhere else — callers must tolerate null.
  static const MethodChannel _installChannel =
      MethodChannel('budgetify/install_info');

  static final EntitlementService _instance = EntitlementService._internal();
  factory EntitlementService() => _instance;
  EntitlementService._internal();

  DateTime? _firstLaunch;
  DateTime? _lastSeen;
  bool _plusLifetime = false;
  int _plusUntilMs = 0;
  Set<String> _ownedRoyals = <String>{};
  Set<String> _dismissedNotices = <String>{};
  bool _initialized = false;

  /// Stamp first-launch once (ever) and advance the monotonic clock. Safe to
  /// call on every cold start — the first-launch stamp is written only once.
  /// Call as early as possible in `main()` so the anchor survives even if a
  /// later startup step fails.
  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    // Work in millisecond precision throughout so the in-memory value always
    // equals the persisted truth (SharedPreferences stores ms since epoch).
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final storedFirst = prefs.getInt(_firstLaunchKey);
    final firstMs = storedFirst ?? nowMs;
    if (storedFirst == null) {
      await prefs.setInt(_firstLaunchKey, firstMs);
    }
    _firstLaunch = DateTime.fromMillisecondsSinceEpoch(firstMs);

    // Monotonic last-seen: keep the later of stored value and now, and persist
    // only when it advances. Trial math (later) uses the later of wall-clock
    // now and this value, so setting the clock back can't extend the trial.
    final storedSeen = prefs.getInt(_lastSeenKey);
    final advanced = storedSeen == null || nowMs > storedSeen;
    final seenMs = advanced ? nowMs : storedSeen;
    if (advanced) {
      await prefs.setInt(_lastSeenKey, seenMs);
    }
    _lastSeen = DateTime.fromMillisecondsSinceEpoch(seenMs);

    _plusLifetime = prefs.getBool(_plusLifetimeKey) ?? false;
    _plusUntilMs = prefs.getInt(_plusUntilKey) ?? 0;
    _ownedRoyals =
        (prefs.getStringList(_ownedRoyalsKey) ?? const <String>[]).toSet();
    _dismissedNotices =
        (prefs.getStringList(_noticeDismissedKey) ?? const <String>[]).toSet();

    _initialized = true;
  }

  /// Pull the trial anchor back to Android's package install record when that
  /// is older than whatever we have stamped.
  ///
  /// Why this closes a hole: SharedPreferences is app data, so "Clear data"
  /// wipes the anchor and the next launch would stamp today — a free window,
  /// no uninstall required. The package install record is NOT app data. It
  /// survives a wipe (and app updates) and resets only on uninstall or factory
  /// reset, so it still knows the true origin date.
  ///
  /// Deliberate limit: it does NOT survive an uninstall, because a reinstall
  /// starts a fresh record. This closes the "Clear data" reset, not the
  /// "uninstall and start over" one — the latter is priced in the user's own
  /// history, which a fresh install doesn't have.
  ///
  /// Kept OUT of [initialize] on purpose. This reaches over a platform
  /// channel, and [initialize] is on the gate path — [allowsAsync] runs in the
  /// background isolate, where no channel is bound and the call would stall a
  /// notification. Call it once from `main()` after [initialize]; nothing
  /// needs to await the result. Purely a floor, so a missing or wrong value
  /// can shorten the free window but never extend it.
  Future<void> applyInstallRecordFloor() async {
    final installMs = await _platformFirstInstallMs();
    if (installMs == null) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_firstLaunchKey);
    if (current != null && installMs >= current) return;
    await prefs.setInt(_firstLaunchKey, installMs);
    _firstLaunch = DateTime.fromMillisecondsSinceEpoch(installMs);
  }

  /// When Android first installed this package (ms since epoch), or null when
  /// unavailable — every non-Android platform, an unbound channel, a platform
  /// error, or a channel that doesn't answer promptly. The timeout matters:
  /// an unanswered channel future would otherwise hang whoever awaited it.
  Future<int?> _platformFirstInstallMs() async {
    try {
      final ms = await _installChannel
          .invokeMethod<int>('firstInstallTime')
          .timeout(const Duration(seconds: 5));
      return (ms != null && ms > 0) ? ms : null;
    } catch (_) {
      return null; // unknown here — the stored anchor stands
    }
  }

  /// Read the anchor back from the one file Android's automatic backup is
  /// allowed to carry, then write the current one into it.
  ///
  /// This is the only witness that survives an UNINSTALL. The other three all
  /// die with the app: preferences and the anchor file are app data, and the
  /// package install record resets on reinstall. Android restores this file
  /// from the user's own Google Drive before first launch, so someone who
  /// uninstalls and reinstalls resumes the window they were in.
  ///
  /// Scope is the whole point. `res/xml/backup_rules.xml` whitelists this file
  /// and nothing else, so what travels is one timestamp — never a
  /// transaction, a message or a balance. See the privacy policy, which says
  /// so in as many words.
  ///
  /// Read AND write, because the file has to stay true: the anchor can be
  /// pulled back later by the install record or a restored backup, and a
  /// stale copy here would quietly undo that on the next reinstall.
  ///
  /// A floor like the rest — it can only ever move the anchor earlier. Kept
  /// out of [initialize] for the same reason as [applyInstallRecordFloor]:
  /// this reaches over a platform channel, and the gate path runs in the
  /// background isolate where no channel is bound. Call it from `main()`;
  /// nothing needs to await the result, and every failure is silent.
  Future<void> syncPortableAnchor() async {
    try {
      final restored = await _installChannel
          .invokeMethod<int>('readTrialAnchor')
          .timeout(const Duration(seconds: 5));
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_firstLaunchKey);

      if (restored != null && restored > 0 &&
          (current == null || restored < current)) {
        await prefs.setInt(_firstLaunchKey, restored);
        _firstLaunch = DateTime.fromMillisecondsSinceEpoch(restored);
      }

      final anchor = prefs.getInt(_firstLaunchKey);
      if (anchor != null && anchor > 0 && anchor != restored) {
        await _installChannel
            .invokeMethod<void>('writeTrialAnchor', {'ms': anchor})
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Unavailable everywhere but Android, and never worth a crash: the
      // stored anchor simply stands.
    }
  }

  /// First recorded app use, or null if not yet stamped. Fail-open callers
  /// (later phases) should treat null as "still in trial".
  DateTime? get firstLaunchAt => _firstLaunch;

  /// Rollback-guarded "now" — never earlier than the last time we ran.
  DateTime get _effectiveNow {
    final now = DateTime.now();
    final seen = _lastSeen;
    return (seen != null && seen.isAfter(now)) ? seen : now;
  }

  /// When this install's free window is considered to have begun — its own
  /// anchor, or [trialRestartAt] for anyone who was already here before it.
  DateTime? get _trialStart {
    final first = _firstLaunch;
    if (first == null) return null;
    final floor = _restartFloor;
    return first.isBefore(floor) ? floor : first;
  }

  /// Whether the free window is still open. Fail-open: unknown ⇒ true.
  bool get trialActive {
    final start = _trialStart;
    if (start == null) return true;
    return _effectiveNow.difference(start) < trialDuration;
  }

  /// Whole days left in the free window (0 once elapsed).
  int get trialDaysLeft {
    final start = _trialStart;
    if (start == null) return trialDuration.inDays;
    final left = trialDuration - _effectiveNow.difference(start);
    if (left.isNegative) return 0;
    // A restart dated in the future would otherwise report more than a full
    // window remaining.
    return left > trialDuration ? trialDuration.inDays : left.inDays;
  }

  /// When the free window closes, or null if first launch was never stamped.
  DateTime? get trialEndsAt => _trialStart?.add(trialDuration);

  // ── Telling the user the free window is ending ────────────────────────
  //
  // The countdown stays hidden — no badge, no timer, no nagging. What does
  // NOT stay hidden is the ending: four of the seven Plus features are
  // notifications, and a notification that stops firing teaches the user the
  // app is broken, not that there is something to buy. So: silence until the
  // last fortnight, two dismissible heads-ups, and one notice when alerts
  // actually go quiet.

  String _noticeTag(DateTime trialEnd, int threshold) =>
      '${trialEnd.millisecondsSinceEpoch}:$threshold';

  /// The heads-up that should be on screen right now, as its days-left
  /// threshold, or null for the great majority of a trial. The most urgent
  /// applicable mark wins, and dismissing it means silence rather than
  /// falling back to a gentler one.
  int? get pendingTrialNotice {
    if (hasPlus || !trialActive) return null;
    final ends = trialEndsAt;
    if (ends == null) return null;
    final left = trialDaysLeft;
    for (final threshold in [...trialNoticeThresholds]..sort()) {
      if (left <= threshold) {
        return _dismissedNotices.contains(_noticeTag(ends, threshold))
            ? null
            : threshold;
      }
    }
    return null;
  }

  /// Put the current heads-up away. Idempotent.
  Future<void> dismissTrialNotice(int threshold) async {
    final ends = trialEndsAt;
    if (ends == null) return;
    if (!_dismissedNotices.add(_noticeTag(ends, threshold))) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _noticeDismissedKey, _dismissedNotices.toList()..sort());
  }

  /// Whether the one-time "your alerts are paused" notice is still owed for
  /// the current window. Safe to call from the background isolate — it reads
  /// prefs fresh, since the foreground may have sent it since this isolate
  /// last loaded them.
  Future<bool> shouldSendLapseNotice() async {
    try {
      await initialize();
      if (hasPlus || trialActive) return false;
      final ends = trialEndsAt;
      if (ends == null) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getInt(_lapseNoticeKey) != ends.millisecondsSinceEpoch;
    } catch (_) {
      return false; // never risk a spurious notice on broken state
    }
  }

  /// Record that the lapse notice went out for this window. Called BEFORE the
  /// notification is shown: a notice that silently fails to appear is a much
  /// smaller harm than one that repeats.
  Future<void> markLapseNoticeSent() async {
    final ends = trialEndsAt;
    if (ends == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lapseNoticeKey, ends.millisecondsSinceEpoch);
  }

  // ── Offer windows ─────────────────────────────────────────────────────

  /// The discount running right now, or null at the everyday price.
  ///
  /// The welcome week takes precedence over a festive window that happens to
  /// overlap it. They carry the same prices, so this only picks which label
  /// the paywall shows — and a user's one-shot welcome offer is the more
  /// specific, more urgent story.
  ///
  /// Uses the rollback-guarded clock, so winding the device clock backwards
  /// can't re-open a window that has already closed. Winding it *forwards*
  /// into a festive window is possible, and deliberately not defended against:
  /// the displayed price is only ever a display, Play charges whatever the
  /// Console has configured, and the same tampering also burns the user's own
  /// trial.
  PlusOffer? get activeOffer => offerAt(_effectiveNow);

  /// [activeOffer] against an explicit clock. Production reads the getter,
  /// which supplies the rollback-guarded now; tests pin [now] so a suite run
  /// during Diwali doesn't see different prices than one run in July.
  PlusOffer? offerAt(DateTime now) {
    final ends = trialEndsAt;
    // Post-trial welcome week. Guarded on trialActive rather than on the date
    // alone so a simulated expiry (dev mode) previews the offer too.
    if (ends != null && !trialActive) {
      // Anchored on the moment free access actually STOPPED, so the window is
      // always the seven days that follow it. Clamped to `now` for the one
      // case where the two disagree: a simulated expiry leaves the real anchor
      // ticking months out, and anchoring on it would count the offer down to
      // a date the tester does not reach for another quarter ("ends in 114
      // days"), which is neither a welcome week nor a believable preview.
      final startsAt = ends.isAfter(now) ? now : ends;
      final welcomeEnds = startsAt.add(welcomeOfferDuration);
      if (now.isBefore(welcomeEnds)) {
        return PlusOffer(
          id: 'welcome',
          kind: PlusOfferKind.welcome,
          startsAt: startsAt,
          endsAt: welcomeEnds,
        );
      }
    }
    return activeFestiveOffer(now);
  }

  /// Whether any discount is live. Convenience for pricing call sites that
  /// don't care which campaign it is.
  bool get offerActive => activeOffer != null;

  // ── Plus entitlement (dormant until billing ships) ────────────────────

  /// Whether the user owns Plus right now: the lifetime unlock, or a
  /// subscription window (incl. grace) that hasn't elapsed. Uses the
  /// rollback-guarded clock so winding the clock back can't stretch a lapsed
  /// subscription.
  bool get hasPlus =>
      _plusLifetime ||
      (_plusUntilMs > 0 &&
          _effectiveNow.millisecondsSinceEpoch <= _plusUntilMs);

  /// The master gate: everything Plus-locked is open while the free window
  /// runs OR the user has paid. Fail-open — an uninitialized service reports
  /// trialActive=true, so a gate consulted before [initialize] completes can
  /// only ever err on the side of letting the user through.
  bool get hasFullAccess => trialActive || hasPlus;

  /// Whether [feature] is usable right now. All Plus features currently share
  /// the master gate; the per-feature enum exists so a later phase can vary
  /// messaging (or grandfather a feature) without re-touching call sites.
  bool allows(PlusFeature feature) => hasFullAccess;

  /// Async form of [allows] for callers that can't guarantee [initialize] ran
  /// (the background isolate, notification choke points). Initialization is
  /// idempotent and cheap; any failure falls open to "allowed".
  Future<bool> allowsAsync(PlusFeature feature) async {
    try {
      await initialize();
      return allows(feature);
    } catch (_) {
      return true; // fail-open: never let broken state lock a user out
    }
  }

  /// Record a completed Plus purchase (from BillingService, a restore, or a
  /// backup import). For subscriptions the paid window only ever moves
  /// forward, so no replay can lose or duplicate time.
  /// [purchaseTimeMs] anchors the window for restores of an old purchase.
  ///
  /// [confirmedActiveNow] means Play answered `queryPurchases` with this
  /// product a moment ago — i.e. the account owns it *at this instant*. Only
  /// the live store may set it; a backup import or a replayed receipt must
  /// not, since neither proves anything about now.
  Future<void> registerPlusPurchase(String productId,
      {int? purchaseTimeMs, bool confirmedActiveNow = false}) async {
    final plan = PlusPlan.byProductId(productId);
    if (plan == null) return;
    final prefs = await SharedPreferences.getInstance();
    switch (plan) {
      case PlusPlan.lifetime:
        _plusLifetime = true;
        await prefs.setBool(_plusLifetimeKey, true);
      case PlusPlan.monthly:
      case PlusPlan.yearly:
        final period = plan == PlusPlan.monthly
            ? const Duration(days: 31)
            : const Duration(days: 366);
        final anchorMs = purchaseTimeMs ?? _effectiveNow.millisecondsSinceEpoch;
        // ABSOLUTE window, always measured from the purchase itself, then kept
        // only if it reaches further than what we already hold. This makes a
        // re-grant IDEMPOTENT: buying and then tapping "Restore" replays the
        // same purchase, computes the same instant, and changes nothing. (The
        // old form measured from the later of anchor/current expiry, so a
        // replay silently bought the user another month.)
        final anchored =
            anchorMs + (period + kPlusSubscriptionGrace).inMilliseconds;
        // A LIVE sighting is the second, independent witness — and the only
        // one that survives a renewal. Play keeps the same purchase token
        // across renewals, so [anchored] recomputes to the same stale instant
        // forever; without this a monthly subscriber would go dark on day 34
        // while still being charged. See [kPlusLiveSightingWindow].
        final sighted = confirmedActiveNow
            ? _effectiveNow.millisecondsSinceEpoch +
                kPlusLiveSightingWindow.inMilliseconds
            : 0;
        final until = anchored > sighted ? anchored : sighted;
        if (until > _plusUntilMs) {
          _plusUntilMs = until;
          await prefs.setInt(_plusUntilKey, until);
        }
    }
  }

  // ── Royal avatar purchases (₹49 each, dormant until billing ships) ────

  /// Royal ids bought outright. Streak-picked royals live in
  /// GamificationService; callers wanting "everything equippable" should ask
  /// GamificationService.unlockedRoyalIds(), which unions both.
  Set<String> get purchasedRoyalIds => Set.unmodifiable(_ownedRoyals);

  /// Whether royal [id] was bought (not streak-picked).
  bool ownsRoyal(String id) => _ownedRoyals.contains(id);

  /// Record a completed royal purchase. Idempotent.
  Future<void> registerRoyalPurchase(String royalId) async {
    if (!_ownedRoyals.add(royalId)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_ownedRoyalsKey, _ownedRoyals.toList()..sort());
  }

  /// Export the trial anchor and the paid-entitlement cache for inclusion in
  /// an encrypted backup.
  ///
  /// The last-seen rollback guard stays device-local by design — a stale or
  /// forward-dated value carried in from another device must never be able to
  /// prematurely end the trial. The paid cache travels so a restore keeps the
  /// app usable offline; once billing ships, Play's `queryPurchases` remains
  /// the authority and re-verifies whatever a backup claimed.
  Future<Map<String, dynamic>> exportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_firstLaunchKey);
    final owned = prefs.getStringList(_ownedRoyalsKey) ?? const <String>[];
    final untilMs = prefs.getInt(_plusUntilKey) ?? 0;
    return {
      if (ms != null) 'first_launch_at': ms,
      if (prefs.getBool(_plusLifetimeKey) ?? false) 'plus_lifetime': true,
      if (untilMs > 0) 'plus_until': untilMs,
      if (owned.isNotEmpty) 'owned_royals': owned,
    };
  }

  /// Merge a restored payload. The EARLIEST first-launch wins, so a restore
  /// can only preserve (or pull back) the true origin date — never push it
  /// forward to extend the trial. Paid entitlements merge additively (union /
  /// max), mirroring how a Play restore can only ever ADD ownership.
  /// Idempotent and null-safe.
  ///
  /// [backupCreatedAtMs] is when the backup FILE was written — a second,
  /// independent witness to the same fact, supplied by BackupService from the
  /// envelope. It counts because it lives OUTSIDE this payload: deleting the
  /// entitlement block from a decrypted backup no longer buys a clean trial,
  /// since a file written five months in still dates the install five months
  /// back.
  ///
  /// [carriesHistory] says the payload brought real transaction history with
  /// it, and closes the last way out: strip BOTH witnesses and the restore
  /// used to fall open to a clean 90 days with every tagged transaction
  /// intact. A backup this app wrote always stamps `createdAt` on the
  /// envelope, unconditionally, so a payload that restores a year of history
  /// while claiming no age at all was assembled by hand. That case now fails
  /// CLOSED — the window is treated as already elapsed — which inverts the
  /// economics: tampering costs the remaining trial instead of buying one.
  ///
  /// Still not tamper-proof; nothing client-side is. A plain reinstall with no
  /// restore keeps giving a fresh window on purpose, since re-tagging
  /// everything by hand is its own price.
  Future<void> importSettings(
    Map<String, dynamic>? settings, {
    int? backupCreatedAtMs,
    bool carriesHistory = false,
  }) async {
    if (settings == null && backupCreatedAtMs == null && !carriesHistory) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();

    // Every witness is a floor; the earliest one wins. Garbage and
    // forward-dated values fall through untouched.
    final current = prefs.getInt(_firstLaunchKey);
    var earliest = current;
    var sawWitness = false;
    for (final witness in <Object?>[
      settings?['first_launch_at'],
      backupCreatedAtMs,
    ]) {
      if (witness is int && witness > 0) {
        sawWitness = true;
        if (earliest == null || witness < earliest) earliest = witness;
      }
    }

    // History with no age at all: date the install a full window back, so the
    // free period reads as spent. Folded in as one more floor rather than a
    // special case, which keeps the whole method monotonic — every path here
    // can only ever move the anchor EARLIER, so no input, however hostile,
    // can lengthen a free window.
    //
    // Note [trialRestartAt] sits above this: while the restart is still in the
    // future, EVERY anchor — this one included — is clamped up to it, so the
    // rule cannot be observed until that date passes. That is the restart
    // doing its job for the testing cohort, not this failing.
    if (carriesHistory && !sawWitness) {
      final spent =
          _effectiveNow.subtract(trialDuration).millisecondsSinceEpoch;
      if (earliest == null || spent < earliest) earliest = spent;
    }

    if (earliest != null && earliest != current) {
      await prefs.setInt(_firstLaunchKey, earliest);
      _firstLaunch = DateTime.fromMillisecondsSinceEpoch(earliest);
    }

    if (settings?['plus_lifetime'] == true && !_plusLifetime) {
      _plusLifetime = true;
      await prefs.setBool(_plusLifetimeKey, true);
    }
    final until = settings?['plus_until'];
    if (until is int && until > _plusUntilMs) {
      _plusUntilMs = until;
      await prefs.setInt(_plusUntilKey, until);
    }
    final royals = settings?['owned_royals'];
    if (royals is List) {
      final merged = {..._ownedRoyals, ...royals.map((e) => e.toString())};
      if (merged.length != _ownedRoyals.length) {
        _ownedRoyals = merged;
        await prefs.setStringList(
            _ownedRoyalsKey, _ownedRoyals.toList()..sort());
      }
    }
  }

  /// Clears in-memory state so a fresh [initialize] re-reads persisted prefs.
  /// Test-only — production stamps once per process.
  @visibleForTesting
  void resetForTest() {
    _initialized = false;
    _firstLaunch = null;
    _lastSeen = null;
    _plusLifetime = false;
    _plusUntilMs = 0;
    _ownedRoyals = <String>{};
    _dismissedNotices = <String>{};
  }
}
