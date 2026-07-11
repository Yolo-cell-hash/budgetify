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

  group('Slot map (append-only: free, elite, royal, extra free)', () {
    test('elite occupies the slots right after the original free block', () {
      for (var i = 0; i < kEliteAvatars.length; i++) {
        expect(kEliteAvatars[i].spriteIndex, kFreePixelAvatarCount + i,
            reason: kEliteAvatars[i].id);
      }
    });

    test('free seeds are the original block plus the post-royal block', () {
      final eliteEnd = kFreePixelAvatarCount + kEliteAvatars.length;
      final extraStart = eliteEnd + kRoyalAvatars.length;
      expect(kFreePixelSeeds.length + kEliteAvatars.length + kRoyalAvatars.length,
          kPixelAvatarCount);
      expect(
        kFreePixelSeeds,
        [
          for (var i = 0; i < kFreePixelAvatarCount; i++) i,
          for (var i = extraStart; i < kPixelAvatarCount; i++) i,
        ],
      );
      // Free seeds never resolve to an elite or royal character.
      for (final seed in kFreePixelSeeds) {
        expect(eliteAvatarAt(seed), isNull, reason: 'seed $seed');
        expect(royalAvatarAt(seed), isNull, reason: 'seed $seed');
      }
      for (final e in kEliteAvatars) {
        expect(eliteAvatarAt(e.spriteIndex)?.id, e.id);
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
    test('occupy the sprite slots right after the elite block', () {
      final eliteEnd = kFreePixelAvatarCount + kEliteAvatars.length;
      for (var i = 0; i < kRoyalAvatars.length; i++) {
        expect(kRoyalAvatars[i].spriteIndex, eliteEnd + i,
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

    test('a royal trims only its home primary theme, and never a reward one',
        () {
      // Non-royal (and legacy emoji) avatars produce no trim at all.
      expect(courtHeroTrimFor('pixel', '0'), isNull);
      expect(courtHeroTrimFor('emoji', '🦊'), isNull);

      final lightRoyal =
          kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      final darkRoyal = kRoyalAvatars.firstWhere((r) => r.id == 'darkprince');

      final lightHero =
          AppTheme.of(AppThemeVariant.light).extension<AppPalette>()!.hero;
      final darkHero =
          AppTheme.of(AppThemeVariant.dark).extension<AppPalette>()!.hero;

      final lightTrim =
          courtHeroTrimFor('pixel', '${lightRoyal.spriteIndex}')!;
      final darkTrim = courtHeroTrimFor('pixel', '${darkRoyal.spriteIndex}')!;

      // Sovereign dresses light: the canvas is PRESERVED (trim, not
      // takeover) and only the accent details take his deep crimson.
      final trimmedLight = lightTrim(AppThemeVariant.light, lightHero);
      expect(trimmedLight, isNotNull);
      expect(trimmedLight!.gradientColors, lightHero.gradientColors);
      expect(trimmedLight.foreground, lightHero.foreground);
      expect(trimmedLight.accent, lightRoyal.theme.accentDeep);
      // ...and he leaves the dark and reward themes alone.
      expect(lightTrim(AppThemeVariant.dark, darkHero), isNull);
      expect(lightTrim(AppThemeVariant.royalIndigo, lightHero), isNull);

      // The Dark Prince dresses dark with his bright ember accent...
      final trimmedDark = darkTrim(AppThemeVariant.dark, darkHero);
      expect(trimmedDark, isNotNull);
      expect(trimmedDark!.gradientColors, darkHero.gradientColors);
      expect(trimmedDark.accent, darkRoyal.theme.accent);
      // ...and leaves light and reward themes alone.
      expect(darkTrim(AppThemeVariant.light, lightHero), isNull);
      expect(darkTrim(AppThemeVariant.midnightIndigo, darkHero), isNull);
    });

    test('ThemeProvider applies and clears the trim on the active theme', () {
      final provider = ThemeProvider(); // defaults to the light variant
      final sovereign =
          kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      final baseHero = AppTheme.of(AppThemeVariant.light)
          .extension<AppPalette>()!
          .hero;

      provider.setHeroTrim(
          courtHeroTrimFor('pixel', '${sovereign.spriteIndex}'));
      final palette = provider.activeTheme.extension<AppPalette>()!;
      expect(palette.hero.accent, sovereign.theme.accentDeep);
      expect(palette.hero.gradientColors, baseHero.gradientColors);
      // AppColors stay the variant's own — only the hero surface changes.
      expect(palette.colors, AppColors.light);

      // A dark-court royal leaves the light theme entirely untouched.
      final medic = kRoyalAvatars.firstWhere((r) => r.id == 'royalmedic');
      provider.setHeroTrim(
          courtHeroTrimFor('pixel', '${medic.spriteIndex}'));
      expect(provider.activeTheme.extension<AppPalette>()!.hero.accent,
          baseHero.accent);

      provider.setHeroTrim(null);
      expect(provider.activeTheme.extension<AppPalette>()!.hero.accent,
          baseHero.accent);
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
