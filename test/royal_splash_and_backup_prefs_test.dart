// Two things a restore, or a new royal, could quietly get wrong.
//
// The splash wears the active launcher icon's gem. That map was hand-written
// per variant, so a royal added later got the default gold splash while its
// icon said otherwise — which is exactly what shipped for the Sentinel and the
// Huntress. It is pinned to the icon roster now.
//
// The preference block is new to backups. Before it, a restore reset every
// on/off choice to its default — and "match app icon to my royal" defaults ON,
// so it came back on for anyone who had turned it off, pointed at whichever
// royal the backup carried.
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/screens/splash_screen.dart';
import 'package:budget_tracker/services/app_icon_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('splash gem skins', () {
    test('every launcher-icon variant has a splash skin and a logo', () {
      for (final v in RoyalAppIcon.all) {
        expect(debugSplashSkinFor(v), isNotNull,
            reason: '"$v" falls back to the default gold splash');
        expect(debugSplashLogoAsset(v), 'assets/branding/royal/$v.png');
      }
    });

    test('each skin wears its own gem, not gold', () {
      for (final v in RoyalAppIcon.all) {
        expect(debugSplashSkinFor(v)!.accent, kRoyalGemAccent[v],
            reason: '"$v" splash accent drifted from its icon gem');
      }
    });

    test('no launcher icon, no gem skin — the default splash stands', () {
      expect(debugSplashSkinFor(null), isNull);
      expect(debugSplashSkinFor('not-a-gem'), isNull);
    });
  });

  group('preferences in a backup', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a deliberate OFF survives a round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final source = AppPreferences();
      await source.initialize();
      await source.setRoyalAppIcon(false);
      final blob = source.exportSettings();

      // A fresh install: royalAppIcon has no stored value, so it defaults ON.
      SharedPreferences.setMockInitialValues({});
      final fresh = AppPreferences();
      await fresh.initialize();
      expect(fresh.royalAppIcon, isTrue, reason: 'the default is ON');

      await AppPreferences.importSettings(blob);
      await fresh.reload();
      expect(fresh.royalAppIcon, isFalse,
          reason: 'the restore must not resurrect a switch turned off');
    });

    test('an ON choice round-trips too', () async {
      final source = AppPreferences();
      await source.initialize();
      await source.setRoyalCustomAnimations(true);
      final blob = source.exportSettings();

      SharedPreferences.setMockInitialValues({});
      final fresh = AppPreferences();
      await fresh.initialize();
      expect(fresh.royalCustomAnimations, isFalse, reason: 'default is OFF');

      await AppPreferences.importSettings(blob);
      await fresh.reload();
      expect(fresh.royalCustomAnimations, isTrue);
    });

    // A backup made before this block existed must leave the install alone
    // rather than stamp defaults over the user's current settings.
    test('a pre-feature backup is a no-op, not a reset', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPreferences();
      await prefs.initialize();
      await prefs.setRoyalAppIcon(false);

      await AppPreferences.importSettings(null);
      await prefs.reload();
      expect(prefs.royalAppIcon, isFalse);

      // Same for a block that simply does not carry the key.
      await AppPreferences.importSettings({'somethingElse': true});
      await prefs.reload();
      expect(prefs.royalAppIcon, isFalse);
    });

    test('reload picks up a value written underneath a live provider',
        () async {
      final prefs = AppPreferences();
      await prefs.initialize();
      expect(prefs.royalAppIcon, isTrue);
      // initialize() is guarded against a second run, which is why reload
      // exists at all: a restore rewrites prefs under a provider already up.
      await AppPreferences.importSettings({'royalAppIcon': false});
      expect(prefs.royalAppIcon, isTrue, reason: 'not re-read yet');
      await prefs.reload();
      expect(prefs.royalAppIcon, isFalse);
    });
  });
}
