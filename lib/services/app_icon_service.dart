import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/royal_avatars.dart';

/// The gem signature of each launcher-icon variant — the one vivid colour that
/// tells the six royal app icons apart, as the icon artwork itself wears it.
///
/// Tuned for a DARK ground (the icon tile, the splash), which is why these are
/// bright tints. Anything drawing on a light surface wants the royal's
/// `RoyalTheme.accentDeep` instead — see [RoyalNotificationSkin].
const Map<String, Color> kRoyalGemAccent = {
  'bronze': Color(0xFFE0A96B),
  'silver': Color(0xFFCBD5E1),
  'emerald': Color(0xFF34E0A8),
  'golden': Color(0xFFFFC93C),
  'ruby': Color(0xFFFF4658),
  'amethyst': Color(0xFFC08CFF),
  'sapphire': Color(0xFF7FB2FF),
  'absinthe': Color(0xFFB6E85C),
};

/// The launcher-icon variants that ship as activity-aliases (see
/// `android/app/src/main/AndroidManifest.xml`), one per royal avatar.
///
/// Pure data + decision logic — no platform calls — so the mapping is unit
/// tested in isolation. The variant *name* is the contract shared with the
/// native side (`MainActivity.iconAliases`) and the manifest alias
/// (`MainActivity<Variant>` / `@mipmap/ic_launcher_<variant>`).
class RoyalAppIcon {
  RoyalAppIcon._();

  /// Royal id → icon variant, themed to each royal's court: the Dark Prince's
  /// blood-moon court takes **ruby**, the Empress's violet **amethyst**, the
  /// Prince's radiant gold **golden**, the Apothecary's green **emerald**,
  /// the Sovereign **bronze**, the Princess **silver**, the Sentinel's steel
  /// court **sapphire**, and the Huntress's **absinthe**.
  static const Map<String, String> forRoyal = {
    'darkprince': 'ruby',
    'prince': 'golden',
    'royalmedic': 'emerald',
    'empress': 'amethyst',
    'sovereign': 'bronze',
    'princess': 'silver',
    'sentinel': 'sapphire',
    'huntress': 'absinthe',
  };

  /// Every variant name that has a launcher icon (roster order). Handy for
  /// tests and any UI preview.
  static const List<String> all = [
    'bronze',
    'silver',
    'emerald',
    'golden',
    'ruby',
    'amethyst',
    'sapphire',
    'absinthe',
  ];

  /// The icon variant an equipped avatar [seed] should show when the feature
  /// is [enabled], or `null` for the default Budgetify icon — returned when
  /// the feature is off, or the equipped avatar isn't a royal we map.
  static String? desiredIcon({required int seed, required bool enabled}) {
    if (!enabled) return null;
    final royal = royalAvatarAt(seed);
    if (royal == null) return null;
    return forRoyal[royal.id];
  }

  /// What the launcher icon should become, given what is already [applied].
  ///
  /// Split out from [AppIconService] so the whole decision is testable off a
  /// device: every method on the service starts with a `Platform.isAndroid`
  /// guard, so on a test host they all return early and the interesting logic —
  /// which is all of it — was unreachable. The service now calls this and
  /// keeps only the platform work.
  static ({String? target, bool changes}) plan({
    required int seed,
    required bool enabled,
    required String? applied,
  }) {
    final target = desiredIcon(seed: seed, enabled: enabled);
    return (target: target, changes: target != applied);
  }
}

/// Drives the Android launcher icon for the "match app icon to my royal"
/// feature. Android-only and purely cosmetic: any platform failure
/// (unsupported OS, OEM quirk) is swallowed so an icon swap can never surface
/// as an error.
///
/// Note: on Android, changing the launcher icon briefly relaunches the app and
/// the new icon appears once the launcher refreshes — an OS limitation of
/// alternate icons, not something the app controls. To avoid doing that
/// needlessly, [sync] remembers the last-applied variant and only calls the OS
/// when the target actually changes.
class AppIconService {
  AppIconService._();

  static const MethodChannel _channel = MethodChannel('budgetify/app_icon');

  /// Key holding the last variant we successfully applied (absent = default).
  static const String _currentKey = 'royal_app_icon_current';

  /// In-memory copy of [_currentKey], so the splash can pick the matching gem
  /// skin synchronously at cold start (no async gap, no flash). Populated by
  /// [loadActiveVariant] in `main()` and kept current by [sync].
  static String? _cachedCurrent;

  /// The launcher icon variant currently applied (null = default Budgetify
  /// icon). Synchronous — read [loadActiveVariant] once at startup first.
  static String? get activeVariant => _cachedCurrent;

  /// Warm [activeVariant] from disk. Call once before `runApp` so the very
  /// first splash frame already knows which gem is active.
  static Future<void> loadActiveVariant() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedCurrent = prefs.getString(_currentKey);
  }

  /// Whether calling [sync] with these inputs would actually swap the launcher
  /// icon (the target differs from what's applied). Lets the UI confirm before
  /// a swap — which closes the app — instead of surprising the user with it.
  static Future<bool> willChange({
    required int equippedSeed,
    required bool enabled,
  }) async {
    if (!Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return RoyalAppIcon.plan(
      seed: equippedSeed,
      enabled: enabled,
      applied: prefs.getString(_currentKey),
    ).changes;
  }

  /// Reconcile the launcher icon to the [equippedSeed] avatar under the
  /// [enabled] toggle. No-op unless the target differs from what's already
  /// applied, so an ordinary avatar edit (or the feature staying off) never
  /// relaunches the app.
  static Future<void> sync({
    required int equippedSeed,
    required bool enabled,
  }) async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    final p = RoyalAppIcon.plan(
      seed: equippedSeed,
      enabled: enabled,
      applied: prefs.getString(_currentKey),
    );
    if (!p.changes) return; // already applied
    // Record the target *before* applying it: the swap disables the running
    // launcher component and can tear the app down, so persisting first keeps
    // the next launch from reading a stale gem (or re-triggering the swap).
    _cachedCurrent = p.target;
    if (p.target == null) {
      await prefs.remove(_currentKey);
    } else {
      await prefs.setString(_currentKey, p.target as String);
    }
    await _apply(p.target); // cosmetic; may tear down / relaunch the app
  }

  /// Bring the launcher icon back in line with what is actually equipped,
  /// without asking and without relaunching.
  ///
  /// [sync] only ever ran from the equip flow, so the icon could be left
  /// stranded by anything that changed the avatar or the opt-in by another
  /// route: restoring a backup, a royal being revoked, leaving developer mode,
  /// or simply turning the switch off and closing the sheet without saving.
  /// Nothing reconciled it afterwards, so the launcher kept showing a royal
  /// the user no longer wore — in some cases permanently, since the equip flow
  /// only fires when the avatar CHANGES.
  ///
  /// Safe to call unprompted because the swap itself does not restart anything
  /// (the native side passes `DONT_KILL_APP`); only the deliberate [relaunch]
  /// does, and this never calls it. The new artwork appears whenever the
  /// launcher next refreshes.
  static Future<void> reconcile({
    required int equippedSeed,
    required bool enabled,
  }) =>
      sync(equippedSeed: equippedSeed, enabled: enabled);

  /// Ask the platform to switch to [variant] (null → default). Returns whether
  /// it was applied; never throws.
  static Future<bool> _apply(String? variant) async {
    try {
      final ok = await _channel.invokeMethod<bool>('setIcon', {
        'icon': variant,
      });
      return ok ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Restart the app onto the launcher component [sync] just enabled.
  ///
  /// An icon swap wants a fresh start before launchers reliably show the new
  /// artwork, and the app used to get that by closing and asking the user to
  /// reopen it — which drops them on their home screen mid-task for a change
  /// they made two taps ago. This does the same restart without the errand.
  ///
  /// Returns false when the platform can't (non-Android, no resolvable launch
  /// intent, channel missing in tests), so callers can fall back to closing.
  static Future<bool> relaunch() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('relaunch') ?? false;
    } catch (_) {
      return false;
    }
  }
}
