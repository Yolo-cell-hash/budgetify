import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/avatar_picker_sheet.dart';
import 'package:budget_tracker/widgets/avatars.dart';
import 'package:budget_tracker/widgets/profile_share_card.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';

void main() {
  group('Pixel avatar sprites', () {
    test('every sprite is a well-formed grid (equal-length rows)', () {
      for (var i = 0; i < kPixelAvatarCount; i++) {
        final rows = debugSpriteRows(i);
        expect(rows, isNotEmpty, reason: 'sprite $i');
        final cols = rows.first.length;
        for (var r = 0; r < rows.length; r++) {
          expect(rows[r].length, cols,
              reason: 'sprite $i row $r has ${rows[r].length} cols, want $cols');
        }
      }
    });

    test('every sprite has a halo gradient', () {
      for (var i = 0; i < kPixelAvatarCount; i++) {
        expect(pixelHaloOf(i).length, 2, reason: 'sprite $i');
      }
    });
  });

  group('Slot map (append-only: free 0-11, elite 12-17, royal 18-23, '
      'post-royal free 24-31, post-royal elite 32-35)', () {
    test('original six elite occupy the slots after the original free block',
        () {
      expect(kFreePixelAvatarCount, 12);
      for (var i = 0; i < 6; i++) {
        expect(kEliteAvatars[i].spriteIndex, kFreePixelAvatarCount + i,
            reason: kEliteAvatars[i].id);
      }
    });

    test('the four new elite occupy the tail of the post-royal block', () {
      final newElite = kEliteAvatars.sublist(6);
      expect(newElite.map((e) => e.id), [
        'frostvalkyrie',
        'astralsorceress',
        'solarpriestess',
        'obsidianwarlord',
      ]);
      // They sit at the very end of the sprite space (slots 32-35).
      for (var i = 0; i < newElite.length; i++) {
        expect(newElite[i].spriteIndex, kPixelAvatarCount - newElite.length + i,
            reason: newElite[i].id);
      }
    });

    test('free seeds are the original block plus the post-royal free slots',
        () {
      expect(kFreePixelSeeds.length + kEliteAvatars.length + kRoyalAvatars.length,
          kPixelAvatarCount);
      // Free grid: 0-11 then the post-royal slots that aren't elite (24-31).
      expect(kFreePixelSeeds, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 24, 25, 26, 27, 28, 29, 30, 31]);
      // Free seeds never resolve to an elite or royal character.
      for (final seed in kFreePixelSeeds) {
        expect(eliteAvatarAt(seed), isNull, reason: 'seed $seed');
        expect(royalAvatarAt(seed), isNull, reason: 'seed $seed');
      }
      for (final e in kEliteAvatars) {
        expect(eliteAvatarAt(e.spriteIndex)?.id, e.id);
      }
      // Every non-royal slot resolves to some art (no gaps/out-of-range).
      for (var i = 0; i < kPixelAvatarCount; i++) {
        expect(debugSpriteRows(i).length, 16, reason: 'slot $i');
      }
    });
  });

  group('Legacy emoji migration', () {
    test('every retired emoji maps deterministically into the free block',
        () {
      // The fox was the old default; it must map to a stable seed.
      expect(legacyEmojiSeed('🦊'), 0);
      expect(legacyEmojiSeed('🦊'), legacyEmojiSeed('🦊'));
      expect(legacyEmojiSeed('👑'), inInclusiveRange(0, 11));
      expect(legacyEmojiSeed('not-an-emoji'), 0);
    });

    test('GamiProfile.fromMap migrates stored emoji profiles to pixel', () {
      final migrated = GamiProfile.fromMap({
        'username': 'Riya',
        'avatarKind': 'emoji',
        'avatarValue': '🦊',
        'avatarAccent': 3,
      });
      expect(migrated.avatarKind, 'pixel');
      expect(migrated.avatarValue, '0');
      // Untouched pixel profiles pass through unchanged.
      final pixel = GamiProfile.fromMap({
        'avatarKind': 'pixel',
        'avatarValue': '${kRoyalAvatars.first.spriteIndex}',
      });
      expect(pixel.avatarValue, '${kRoyalAvatars.first.spriteIndex}');
      // The default for brand-new users is the first pixel character.
      expect(const GamiProfile().avatarKind, 'pixel');
    });
  });

  group('Royal avatars', () {
    test('occupy the sprite slots right after the original elite block', () {
      // Royals sit after the free block + the ORIGINAL six elites (slot 18);
      // the four newer elites live later, in the post-royal block.
      final royalStart = kFreePixelAvatarCount + 6;
      for (var i = 0; i < kRoyalAvatars.length; i++) {
        expect(kRoyalAvatars[i].spriteIndex, royalStart + i,
            reason: kRoyalAvatars[i].id);
      }
      // No overlap with the elite/free resolvers.
      for (final r in kRoyalAvatars) {
        expect(eliteAvatarAt(r.spriteIndex), isNull, reason: r.id);
        expect(royalAvatarAt(r.spriteIndex)?.id, r.id);
      }
      expect(royalAvatarAt(0), isNull);
    });

    test('the founding pair dresses light, the rest of the court dark', () {
      for (final r in kRoyalAvatars) {
        final expected = (r.id == 'sovereign' || r.id == 'empress')
            ? Brightness.light
            : Brightness.dark;
        expect(r.theme.homeBrightness, expected, reason: r.id);
      }
    });

    test('the court dress swaps only the gold slots, only at home', () {
      // Non-royal (and legacy emoji) avatars produce no dress at all.
      expect(courtDressFor('pixel', '0'), isNull);
      expect(courtDressFor('emoji', '🦊'), isNull);

      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      final darkPrince =
          kRoyalAvatars.firstWhere((r) => r.id == 'darkprince');

      final lightBase = AppTheme.of(AppThemeVariant.light);
      final darkBase = AppTheme.of(AppThemeVariant.dark);

      final lightDress = courtDressFor('pixel', '${sovereign.spriteIndex}')!;
      final darkDress = courtDressFor('pixel', '${darkPrince.spriteIndex}')!;

      // Sovereign dresses light: canvases and ink stay the theme's own,
      // the gold brand slots take his deep crimson (light keeps its ink
      // interactive accent), and the hero carries the trim.
      final dressedLightTheme = lightDress(AppThemeVariant.light, lightBase);
      final dressedLight = dressedLightTheme.extension<AppPalette>()!;
      expect(dressedLight.colors.background, AppColors.light.background);
      expect(dressedLight.colors.text, AppColors.light.text);
      expect(dressedLight.colors.accent, AppColors.light.accent);
      expect(dressedLight.colors.brandAccent, sovereign.theme.accentDeep);
      expect(dressedLight.hero.accent, sovereign.theme.accentDeep);
      expect(dressedLight.hero.gradientColors,
          lightBase.extension<AppPalette>()!.hero.gradientColors);
      // Light bakes gold into just the tab indicator + snackbar action —
      // those follow the court; ink buttons stay the theme's own.
      expect(dressedLightTheme.tabBarTheme.indicatorColor,
          sovereign.theme.accentDeep);
      expect(dressedLightTheme.snackBarTheme.actionTextColor,
          sovereign.theme.accentDeep);
      expect(dressedLightTheme.tabBarTheme.labelColor,
          lightBase.tabBarTheme.labelColor);
      expect(dressedLightTheme.elevatedButtonTheme.style,
          same(lightBase.elevatedButtonTheme.style));
      // ...and he leaves the dark and reward themes alone.
      expect(lightDress(AppThemeVariant.dark, darkBase), same(darkBase));
      final royalIndigoBase = AppTheme.of(AppThemeVariant.royalIndigo);
      expect(lightDress(AppThemeVariant.royalIndigo, royalIndigoBase),
          same(royalIndigoBase));

      // The Dark Prince dresses dark: gold abdicates everywhere — palette
      // accent, brand slots, ThemeData primaries — background untouched.
      final dressedDarkTheme = darkDress(AppThemeVariant.dark, darkBase);
      final dressedDark = dressedDarkTheme.extension<AppPalette>()!;
      expect(dressedDark.colors.background, AppColors.dark.background);
      expect(dressedDark.colors.accent, darkPrince.theme.accent);
      expect(dressedDark.colors.brandAccent, darkPrince.theme.accent);
      expect(dressedDark.colors.brandAccentDeep, darkPrince.theme.accentDeep);
      expect(dressedDarkTheme.primaryColor, darkPrince.theme.accent);
      expect(dressedDarkTheme.colorScheme.primary, darkPrince.theme.accent);
      expect(dressedDark.hero.accent, darkPrince.theme.accent);
      // ...including every component theme the base bakes gold into: the
      // bottom nav, tab bar, FABs, buttons, focused inputs, snackbar
      // actions and selected chips (the "See All" / "Mark paid" class).
      final ember = darkPrince.theme.accent;
      expect(dressedDarkTheme.bottomNavigationBarTheme.selectedItemColor,
          ember);
      expect(dressedDarkTheme.tabBarTheme.labelColor, ember);
      expect(dressedDarkTheme.tabBarTheme.indicatorColor, ember);
      expect(
          dressedDarkTheme.floatingActionButtonTheme.backgroundColor, ember);
      expect(
          dressedDarkTheme.textButtonTheme.style!.foregroundColor!
              .resolve(const {}),
          ember);
      expect(
          dressedDarkTheme.elevatedButtonTheme.style!.backgroundColor!
              .resolve(const {}),
          ember);
      expect(dressedDarkTheme.snackBarTheme.actionTextColor, ember);
      expect(dressedDarkTheme.chipTheme.selectedColor, ember);
      expect(
          (dressedDarkTheme.inputDecorationTheme.focusedBorder!
                  as OutlineInputBorder)
              .borderSide
              .color,
          ember);
      // ...and leaves light and reward themes alone.
      expect(darkDress(AppThemeVariant.light, lightBase), same(lightBase));
      final midnightBase = AppTheme.of(AppThemeVariant.midnightIndigo);
      expect(darkDress(AppThemeVariant.midnightIndigo, midnightBase),
          same(midnightBase));
    });

    test('ThemeProvider applies and clears the dress on the active theme',
        () {
      final provider = ThemeProvider(); // defaults to the light variant
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');

      provider.setThemeDress(
          courtDressFor('pixel', '${sovereign.spriteIndex}'));
      final palette = provider.activeTheme.extension<AppPalette>()!;
      expect(palette.colors.brandAccent, sovereign.theme.accentDeep);
      expect(palette.colors.background, AppColors.light.background);

      // A dark-court royal leaves the light theme entirely untouched.
      final medic = kRoyalAvatars.firstWhere((r) => r.id == 'royalmedic');
      provider
          .setThemeDress(courtDressFor('pixel', '${medic.spriteIndex}'));
      expect(provider.activeTheme.extension<AppPalette>()!.colors.brandAccent,
          AppColors.light.brandAccent);

      // Clearing the dress (avatar changed / toggle off) restores the base.
      provider.setThemeDress(null);
      expect(provider.activeTheme.extension<AppPalette>()!.colors.brandAccent,
          AppColors.light.brandAccent);
    });

    test('the app-wide toggle rides the profile', () {
      final on = GamiProfile.fromMap({'avatarKind': 'pixel'});
      expect(on.applyRoyalTheme, isTrue); // default: on
      final off = on.copyWith(applyRoyalTheme: false);
      expect(off.applyRoyalTheme, isFalse);
      expect(GamiProfile.fromMap(off.toMap()).applyRoyalTheme, isFalse);
    });

    test('every animation frame stays on the base grid', () {
      for (final r in kRoyalAvatars) {
        final cols = r.rows.first.length;
        expect(r.eyeRowWhites, inInclusiveRange(0, r.rows.length - 1));
        expect(r.eyeRowIris, inInclusiveRange(0, r.rows.length - 1));
        for (final variant in [r.eyesClosed, r.eyesLeft, r.eyesRight]) {
          expect(variant.length, 2, reason: r.id);
          for (final row in variant) {
            expect(row.length, cols, reason: '${r.id}: "$row"');
          }
        }
        // Every glyph used by the base art resolves to a colour.
        for (final row in r.rows) {
          for (final ch in row.split('')) {
            if (ch == '.') continue;
            expect(r.palette[ch], isNotNull,
                reason: '${r.id}: glyph "$ch" has no palette entry');
          }
        }
      }
    });

    test('royal halos come from the royal theme', () {
      for (final r in kRoyalAvatars) {
        expect(pixelHaloOf(r.spriteIndex), r.theme.halo, reason: r.id);
      }
    });

    testWidgets('AvatarView routes royal seeds to the living avatar',
        (tester) async {
      final seed = '${kRoyalAvatars.first.spriteIndex}';
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AvatarView(kind: 'pixel', value: seed, size: 84),
          ),
        ),
      );
      expect(find.byType(AnimatedRoyalAvatar), findsOneWidget);
      // Let the spawn finish and the idle loop tick through a blink, a
      // glance and the wave window — no layout/paint exceptions allowed.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('picker shows the whole royal court without layout errors',
        (tester) async {
      final royal = kRoyalAvatars.first;
      await tester.pumpWidget(
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showAvatarPicker(
                      ctx,
                      GamiProfile(
                        avatarKind: 'pixel',
                        avatarValue: '${royal.spriteIndex}',
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Every royal gets a named tile, plus the equipped one lives in the
      // preview — all without overflow/constraint exceptions.
      for (final r in kRoyalAvatars) {
        // Names resolve through l10n; assert via the widget tree instead of
        // hardcoding copy so wording changes don't break this test.
        expect(find.byWidgetPredicate((w) => w is AnimatedRoyalAvatar && w.royal.id == r.id),
            findsWidgets, reason: r.id);
      }
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('royal sheet describes, toggles, and equips', (tester) async {
      final royal = kRoyalAvatars.first;
      GamiProfile? result;
      await tester.pumpWidget(
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await showAvatarPicker(
                        ctx,
                        const GamiProfile(
                            avatarKind: 'pixel', avatarValue: '0'),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap the first royal tile → its court sheet opens with lore, the
      // home-court note, the app-wide toggle, and Equip. The ROYALTY
      // section sits below the fold, so bring the tile on-screen first.
      final tile = find.byWidgetPredicate(
          (w) => w is AnimatedRoyalAvatar && w.royal.id == royal.id);
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('Apply app-wide Crimson theme'), findsOneWidget);
      expect(find.text('The Sovereign'), findsWidgets);
      expect(find.text('Equip'), findsOneWidget);

      // Flip the toggle off, equip him, then save the picker.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.ensureVisible(find.text('Equip'));
      await tester.pump();
      await tester.tap(find.text('Equip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(result, isNotNull);
      expect(result!.avatarValue, '${royal.spriteIndex}');
      expect(result!.applyRoyalTheme, isFalse);
    });

    testWidgets('profile card adopts the equipped royal theme',
        (tester) async {
      final royal = kRoyalAvatars.first;
      await tester.pumpWidget(
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
          child: MaterialApp(
            home: SingleChildScrollView(
              child: ProfileShareCard(
                profile: GamiProfile(
                  username: 'Jay',
                  avatarKind: 'pixel',
                  avatarValue: '${royal.spriteIndex}',
                ),
                currentStreak: 12,
                titles: const [],
                showcased: const [],
                trophyCount: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      // The card paints the royal aura and hosts the living avatar.
      expect(find.byType(AnimatedRoyalAvatar), findsOneWidget);
      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ProfileShareCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final deco = card.decoration! as BoxDecoration;
      expect((deco.gradient! as LinearGradient).colors,
          royal.theme.cardGradient);
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    });
  });
}
