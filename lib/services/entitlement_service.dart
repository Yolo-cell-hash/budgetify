import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the local "trial clock": the timestamp of first app use plus a
/// monotonic last-seen guard against device-clock rollback.
///
/// PHASE 0 — this service ONLY records time. Nothing in the UI reads it and no
/// feature is gated on it yet; gating arrives in a later phase. Recording the
/// anchor from the earliest possible build matters because the eventual free
/// window must count from a real first-use date, not from whenever gating
/// happens to ship. There is deliberately no user-facing surface for any of
/// this.
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

  /// Length of the free window. Not consulted by any gate yet (Phase 0).
  static const Duration trialDuration = Duration(days: 182); // ~6 months

  static final EntitlementService _instance = EntitlementService._internal();
  factory EntitlementService() => _instance;
  EntitlementService._internal();

  DateTime? _firstLaunch;
  DateTime? _lastSeen;
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

    _initialized = true;
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
  /// NOTHING gates on this in Phase 0 — it exists for later phases.
  bool get trialActive {
    final first = _firstLaunch;
    if (first == null) return true;
    return _effectiveNow.difference(first) < trialDuration;
  }

  /// Whole days left in the free window (0 once elapsed). For later UI.
  int get trialDaysLeft {
    final first = _firstLaunch;
    if (first == null) return trialDuration.inDays;
    final left = trialDuration - _effectiveNow.difference(first);
    return left.isNegative ? 0 : left.inDays;
  }

  /// Export the trial anchor for inclusion in an encrypted backup.
  ///
  /// Only the first-launch anchor travels; the last-seen rollback guard is
  /// device-local by design — a stale or forward-dated value carried in from
  /// another device must never be able to prematurely end the trial.
  Future<Map<String, dynamic>> exportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_firstLaunchKey);
    return {if (ms != null) 'first_launch_at': ms};
  }

  /// Merge a restored trial anchor. The EARLIEST first-launch wins, so a
  /// restore can only preserve (or pull back) the true origin date — never
  /// push it forward to extend the trial. Idempotent and null-safe.
  Future<void> importSettings(Map<String, dynamic>? settings) async {
    if (settings == null) return;
    final restored = settings['first_launch_at'];
    if (restored is! int) return;

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_firstLaunchKey);
    final earliest =
        (current == null || restored < current) ? restored : current;
    if (earliest != current) {
      await prefs.setInt(_firstLaunchKey, earliest);
      _firstLaunch = DateTime.fromMillisecondsSinceEpoch(earliest);
    }
  }

  /// Clears in-memory state so a fresh [initialize] re-reads persisted prefs.
  /// Test-only — production stamps once per process.
  @visibleForTesting
  void resetForTest() {
    _initialized = false;
    _firstLaunch = null;
    _lastSeen = null;
  }
}
