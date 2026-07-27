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
/// GATES ARE WIRED BUT DORMANT. Every gate resolves through [allows], which is
/// `trialActive || hasPlus` — and the 6-month trial makes every check pass on
/// every current install. Nothing user-visible changes until a trial actually
/// expires, and the trial clock itself stays invisible (no countdown, no
/// toast) by explicit product decision.
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

  /// Developer-mode hook (dev-mode branch only): when true, [trialActive]
  /// reports false so the post-trial experience — locked gates, the Plus
  /// paywall, suppressed Plus-only notifications — can be previewed on a
  /// fresh install. Session-static like
  /// [GamificationService.sessionAvatarOverride]: never persisted here (the
  /// DevMode overlay owns persistence) and never consulted by trial STORAGE —
  /// the real anchor keeps ticking untouched underneath.
  static bool debugSimulateTrialExpired = false;

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

  /// First recorded app use, or null if not yet stamped. Fail-open callers
  /// (later phases) should treat null as "still in trial".
  DateTime? get firstLaunchAt => _firstLaunch;

  /// Rollback-guarded "now" — never earlier than the last time we ran.
  DateTime get _effectiveNow {
    final now = DateTime.now();
    final seen = _lastSeen;
    return (seen != null && seen.isAfter(now)) ? seen : now;
  }

  /// Whether the free window is still open. Fail-open: unknown ⇒ true.
  bool get trialActive {
    if (debugSimulateTrialExpired) return false;
    final first = _firstLaunch;
    if (first == null) return true;
    return _effectiveNow.difference(first) < trialDuration;
  }

  /// Whole days left in the free window (0 once elapsed). For later UI.
  int get trialDaysLeft {
    if (debugSimulateTrialExpired) return 0;
    final first = _firstLaunch;
    if (first == null) return trialDuration.inDays;
    final left = trialDuration - _effectiveNow.difference(first);
    return left.isNegative ? 0 : left.inDays;
  }

  /// When the free window closes, or null if first launch was never stamped.
  DateTime? get trialEndsAt => _firstLaunch?.add(trialDuration);

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
      final welcomeEnds = ends.add(welcomeOfferDuration);
      if (now.isBefore(welcomeEnds)) {
        return PlusOffer(
          id: 'welcome',
          kind: PlusOfferKind.welcome,
          startsAt: ends,
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
  /// backup import). For subscriptions the paid window extends from the later
  /// of now / the current expiry, so stacking a renewal never loses time.
  /// [purchaseTimeMs] anchors the window for restores of an old purchase.
  Future<void> registerPlusPurchase(String productId,
      {int? purchaseTimeMs}) async {
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
        final start =
            anchorMs > _plusUntilMs ? anchorMs : _plusUntilMs; // stack renewals
        final until = start + (period + kPlusSubscriptionGrace).inMilliseconds;
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
  /// back. Not tamper-proof (nothing client-side is) — just no longer a
  /// one-line edit.
  Future<void> importSettings(Map<String, dynamic>? settings,
      {int? backupCreatedAtMs}) async {
    if (settings == null && backupCreatedAtMs == null) return;
    final prefs = await SharedPreferences.getInstance();

    // Every witness is a floor; the earliest one wins. Garbage and
    // forward-dated values fall through untouched.
    final current = prefs.getInt(_firstLaunchKey);
    var earliest = current;
    for (final witness in <Object?>[
      settings?['first_launch_at'],
      backupCreatedAtMs,
    ]) {
      if (witness is int &&
          witness > 0 &&
          (earliest == null || witness < earliest)) {
        earliest = witness;
      }
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
  }
}
