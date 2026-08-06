import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/royal_avatars.dart';
import 'app_icon_service.dart';

/// Each royal's notification colour: its launcher-icon gem, darkened to
/// survive a pale notification shade.
///
/// Neither existing palette worked here, and both failures were measured
/// rather than guessed:
///
///  • [kRoyalGemAccent] — the gem as the icon wears it — is tuned for the
///    icon's dark tile. Android runs a contrast pass over a notification
///    colour against the pale shade, so a light tint is darkened until it is
///    neutral: on Android 12 the Princess's `#CBD5E1` came out a flat grey
///    while the Dark Prince's ruby stayed vivid.
///  • `RoyalTheme.accentDeep` is dark enough, but three courts land in the
///    same red wedge — Sovereign `#8E1F2F` and Dark Prince `#B02838` are two
///    degrees of hue apart (ΔE 12.7), which is one colour, not two.
///
/// So each entry keeps the *hue* of that royal's gem — the identity the user
/// actually sees on the home screen — at a lightness that reads on white. The
/// result holds a minimum ΔE of ~33 between any two courts and at least
/// 4.4:1 contrast against the white glyph sitting inside the circle. Both are
/// asserted in `test/royal_notification_skin_test.dart`; change a value and
/// the suite re-checks the whole set.
const Map<String, Color> kRoyalNotificationAccent = {
  'bronze': Color(0xFF723C17), // copper
  'silver': Color(0xFF465A72), // slate
  'emerald': Color(0xFF127856),
  'golden': Color(0xFF987106), // amber
  'ruby': Color(0xFF9E0A19),
  'amethyst': Color(0xFF5C1C9C),
};

/// How an equipped royal dresses the app's notifications, so an alert reads as
/// coming from *that* court rather than from a generic app.
///
/// One lever, because Android offers exactly one: [accent] — `setColor`. The
/// system fills the circle behind the app's status-bar mark with it, so the
/// alert sits in the royal's colour beside every other app's. The mark's shape
/// never changes.
///
/// **What this cannot reach.** Android 16 and later draw the full-colour app
/// icon in the shade instead of the tinted mark, as do some OEM skins on
/// earlier versions, and there the colour simply doesn't appear. That icon is
/// the package's install-time application icon, which no runtime API can vary
/// — the royal activity-alias swap re-skins the *launcher* entry, not the
/// application record the shade reads. The one documented exception, filing
/// alerts as conversations so a chosen avatar takes that circle, was
/// prototyped and rejected: Android's guidance reserves it for "real-time
/// conversations", not "activities unrelated to conversations", and
/// MessagingStyle ignores setContentTitle, which permanently demotes the
/// amount below a person's name.
///
/// Pure data — no I/O, no platform calls — so the mapping is unit tested in
/// isolation. [RoyalSkinService] does the persistence.
@immutable
class RoyalNotificationSkin {
  /// The equipped royal's id (`princess`, `darkprince`, …).
  final String royalId;

  /// The launcher-icon variant this royal wears — the same value
  /// [RoyalAppIcon] gives the home-screen icon, so the notification and the
  /// app icon can never disagree about which gem is in play.
  final String variant;

  /// This royal's gem, darkened for the shade — see
  /// [kRoyalNotificationAccent].
  final Color accent;

  const RoyalNotificationSkin({
    required this.royalId,
    required this.variant,
    required this.accent,
  });

  /// The skin for [royalId], or null when no royal is equipped (or the id is
  /// one we don't know — a profile from a newer build, say).
  static RoyalNotificationSkin? forRoyal(String? royalId) {
    if (royalId == null) return null;
    final variant = RoyalAppIcon.forRoyal[royalId];
    final accent = kRoyalNotificationAccent[variant];
    if (variant == null || accent == null) return null;
    return RoyalNotificationSkin(
      royalId: royalId,
      variant: variant,
      accent: accent,
    );
  }

  /// The royal id an avatar [seed] stands for, or null when it isn't a royal.
  static String? royalIdForSeed(int seed) => royalAvatarAt(seed)?.id;
}

/// Keeps the equipped royal on disk, where any isolate can reach it.
///
/// Transaction alerts fire from the **background isolate** (the WorkManager
/// SMS scan), which has no platform channels bound and cannot load the
/// gamification profile the way a screen would. So the equipped royal is
/// mirrored to a single SharedPreferences key from the UI isolate, and the
/// notification path just reads that string back.
///
/// The whole thing is cosmetic: every failure is swallowed — a court that
/// can't be resolved costs the alert its colour, never the alert.
class RoyalSkinService {
  RoyalSkinService._();

  /// Equipped royal's id (absent = no royal, or a non-royal avatar).
  @visibleForTesting
  static const String royalKey = 'royal_notification_court';

  /// Reconcile the stored royal to the avatar [seed]. Safe to call on every
  /// profile save and once at startup.
  static Future<void> sync(int seed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final royalId = RoyalNotificationSkin.royalIdForSeed(seed);
      if (royalId == null) {
        await prefs.remove(royalKey);
      } else {
        await prefs.setString(royalKey, royalId);
      }
    } catch (e) {
      debugPrint('RoyalSkinService.sync failed (continuing): $e');
    }
  }

  /// The skin to dress notifications in right now, or null for the default
  /// Budgetify look. Cheap enough to call per notification — a cached prefs
  /// read. Never throws.
  static Future<RoyalNotificationSkin?> current() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return RoyalNotificationSkin.forRoyal(prefs.getString(royalKey));
    } catch (e) {
      debugPrint('RoyalSkinService.current failed (continuing): $e');
      return null;
    }
  }
}
