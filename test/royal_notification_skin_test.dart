import 'package:budget_tracker/services/app_icon_service.dart';
import 'package:budget_tracker/services/royal_notification_skin.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure mapping tests for the royal notification dress — which colour an
/// equipped royal paints its alerts. The persistence side (RoyalSkinService)
/// needs SharedPreferences, so it is verified on device.
void main() {
  group('RoyalNotificationSkin.forRoyal', () {
    test('no royal equipped → no skin (the default Budgetify look)', () {
      expect(RoyalNotificationSkin.forRoyal(null), isNull);
    });

    test('an unknown royal id → no skin, never a half-dressed one', () {
      expect(RoyalNotificationSkin.forRoyal('archduke'), isNull);
    });

    test('every royal in the roster resolves to a full skin', () {
      for (final r in kRoyalAvatars) {
        final skin = RoyalNotificationSkin.forRoyal(r.id);
        expect(skin, isNotNull, reason: 'royal "${r.id}" has no skin');
        expect(RoyalAppIcon.all, contains(skin!.variant));
      }
    });

    test('the skin names the same gem as the launcher icon', () {
      // Whatever the home-screen icon shows, the notification belongs to the
      // same court.
      for (final r in kRoyalAvatars) {
        expect(
          RoyalNotificationSkin.forRoyal(r.id)!.variant,
          RoyalAppIcon.forRoyal[r.id],
          reason: '"${r.id}" notification gem disagrees with its app icon',
        );
      }
    });

    test('the accent is the court\'s DEEP shade, not the icon gem', () {
      // Measured on Android 12: Android darkens a light notification colour
      // for contrast against the pale shade, so the Princess's icon silver
      // (#CBD5E1) came out a flat grey. The deep court colours survive it.
      // Guarding this keeps a well-meaning "use the gem, it matches the icon"
      // change from quietly draining the colour back out.
      for (final r in kRoyalAvatars) {
        final skin = RoyalNotificationSkin.forRoyal(r.id)!;
        expect(skin.accent, r.theme.accentDeep);
        expect(
          skin.accent,
          isNot(kRoyalGemAccent[skin.variant]),
          reason: '"${r.id}" fell back to the light icon gem',
        );
      }
    });

    test('the named pairings hold: Princess silver, Prince golden', () {
      expect(RoyalNotificationSkin.forRoyal('princess')!.variant, 'silver');
      expect(RoyalNotificationSkin.forRoyal('prince')!.variant, 'golden');
    });

    test('each court gets a distinct accent', () {
      final accents = kRoyalAvatars
          .map((r) => RoyalNotificationSkin.forRoyal(r.id)!.accent)
          .toList();
      expect(accents.toSet().length, accents.length);
    });

    test('accents are opaque and dark enough to read on a pale shade', () {
      for (final r in kRoyalAvatars) {
        final c = RoyalNotificationSkin.forRoyal(r.id)!.accent;
        expect(c.a, 1.0, reason: '"${r.id}" accent is translucent');
        expect(
          c.computeLuminance(),
          lessThan(0.4),
          reason: '"${r.id}" accent is too light — it will grey out',
        );
      }
    });
  });

  group('gem accents (launcher icon / splash)', () {
    test('every launcher-icon variant has a gem colour', () {
      for (final v in RoyalAppIcon.all) {
        expect(kRoyalGemAccent.containsKey(v), isTrue, reason: 'no gem: $v');
      }
      expect(kRoyalGemAccent.length, RoyalAppIcon.all.length);
    });

    test('gem colours are opaque', () {
      for (final c in kRoyalGemAccent.values) {
        expect(c.a, 1.0);
      }
    });
  });

  group('RoyalNotificationSkin.royalIdForSeed', () {
    test('a royal seed names its royal', () {
      for (final r in kRoyalAvatars) {
        expect(RoyalNotificationSkin.royalIdForSeed(r.spriteIndex), r.id);
      }
    });

    test('a basic avatar seed is not a royal', () {
      expect(RoyalNotificationSkin.royalIdForSeed(0), isNull);
      expect(RoyalNotificationSkin.royalIdForSeed(-1), isNull);
    });
  });
}
