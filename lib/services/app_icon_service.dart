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
  /// Prince's radiant gold **golden**, the Royal Medic's green **emerald**,
  /// the Sovereign **bronze**, and the Princess **silver**.
  static const Map<String, String> forRoyal = {
    'darkprince': 'ruby',
    'prince': 'golden',
    'royalmedic': 'emerald',
    'empress': 'amethyst',
    'sovereign': 'bronze',
    'princess': 'silver',
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
    final desired = RoyalAppIcon.desiredIcon(
      seed: equippedSeed,
      enabled: enabled,
    );
    final prefs = await SharedPreferences.getInstance();
    return desired != prefs.getString(_currentKey);
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
    final desired = RoyalAppIcon.desiredIcon(
      seed: equippedSeed,
      enabled: enabled,
    );
    final prefs = await SharedPreferences.getInstance();
    if (desired == prefs.getString(_currentKey)) return; // already applied
    // Record the target *before* applying it: the swap disables the running
    // launcher component and can tear the app down, so persisting first keeps
    // the next launch from reading a stale gem (or re-triggering the swap).
    _cachedCurrent = desired;
    if (desired == null) {
      await prefs.remove(_currentKey);
    } else {
      await prefs.setString(_currentKey, desired);
    }
    await _apply(desired); // cosmetic; may tear down / relaunch the app
  }

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
