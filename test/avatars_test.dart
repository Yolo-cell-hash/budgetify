import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/avatar_picker_sheet.dart';
import 'package:budget_tracker/widgets/avatars.dart';
import 'package:budget_tracker/widgets/profile_share_card.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // ThemeProvider.setVariant persists the choice, so the court-dress tests
  // that switch modes need a prefs stub behind them.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

    test('every court carries a legible shade for each mode', () {
      // The dress reaches both primaries, so each royal needs two working
      // shades: the bright accent on the dark canvas, the deep one on ivory.
      // 4.5:1 is the bar because both land under text — the royal's name on
      // its tile, the snackbar action, the "See All" links the dress tints.
      // Two courts had to be deepened to clear it (the Prince's bronze and
      // the Medic's emerald both sat at 4.0:1); this keeps them there.
      for (final r in kRoyalAvatars) {
        final onIvory = _contrast(r.theme.accentDeep, Colors.white);
        expect(onIvory, greaterThanOrEqualTo(4.5),
            reason: '${r.id}: accentDeep is ${onIvory.toStringAsFixed(2)}:1 '
                'on the light canvas — it will wash out');
        final onInk = _contrast(r.theme.accent, AppColors.dark.card);
        expect(onInk, greaterThanOrEqualTo(4.5),
            reason: '${r.id}: accent is ${onInk.toStringAsFixed(2)}:1 on a '
                'dark card');
        // ...and the two are genuinely different shades, not one colour
        // listed twice — a court that skipped the deep tone would read as
        // "dressed for both" while washing out in light.
        expect(r.theme.accentDeep, isNot(r.theme.accent), reason: r.id);
      }
    });

    test('the court dress swaps only the gold slots, in both primaries', () {
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

      // On LIGHT: the scaffold canvas and ink stay the theme's own, the gold
      // brand slots take the court's deep shade (light keeps its ink
      // interactive accent), and the hero carries the trim.
      final dressedLightTheme = lightDress(AppThemeVariant.light, lightBase);
      final dressedLight = dressedLightTheme.extension<AppPalette>()!;
      expect(dressedLight.colors.background, AppColors.light.background);
      expect(dressedLight.colors.text, AppColors.light.text);
      expect(dressedLight.colors.accent, AppColors.light.accent);
      expect(dressedLight.colors.brandAccent, sovereign.theme.accentDeep);
      expect(dressedLight.hero.accent, sovereign.theme.accentDeep);
      // The light HERO canvas is re-tinted off champagne to a pale court
      // ivory (the old gold gradient would clash with the crimson accent).
      final baseLightHero = lightBase.extension<AppPalette>()!.hero;
      expect(dressedLight.hero.gradientColors,
          isNot(baseLightHero.gradientColors));
      // Top stop is near-white; both stops lean toward the court, never gold.
      expect(dressedLight.hero.gradientColors.first.g, greaterThan(0.9));
      expect(dressedLight.hero.gradientColors.last,
          Color.lerp(const Color(0xFFFFFFFF), sovereign.theme.accentDeep, 0.17));
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
      // The Sovereign follows the user into DARK too — this is the whole
      // point of the dual-mode court, and used to return the base untouched.
      // There he wears the bright accent, not the ivory-legible deep one.
      final sovereignOnDark = lightDress(AppThemeVariant.dark, darkBase);
      expect(sovereignOnDark, isNot(same(darkBase)));
      expect(sovereignOnDark.extension<AppPalette>()!.colors.brandAccent,
          sovereign.theme.accent);
      // ...but reward themes stay hand-tuned, in either direction.
      final royalIndigoBase = AppTheme.of(AppThemeVariant.royalIndigo);
      expect(lightDress(AppThemeVariant.royalIndigo, royalIndigoBase),
          same(royalIndigoBase));

      // On DARK: gold abdicates everywhere — palette accent, brand slots,
      // ThemeData primaries — background untouched.
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
      // ...and the Dark Prince reaches LIGHT the same way the Sovereign
      // reaches dark, in his ivory-legible blood red.
      final darkPrinceOnLight = darkDress(AppThemeVariant.light, lightBase);
      expect(darkPrinceOnLight, isNot(same(lightBase)));
      expect(darkPrinceOnLight.extension<AppPalette>()!.colors.brandAccent,
          darkPrince.theme.accentDeep);
      // Reward themes stay untouched from this side too.
      final midnightBase = AppTheme.of(AppThemeVariant.midnightIndigo);
      expect(darkDress(AppThemeVariant.midnightIndigo, midnightBase),
          same(midnightBase));
    });

    test('every royal reaches both primaries, and no reward theme', () {
      // The whole roster, not just the two spot-checked above: equipping any
      // royal must change something in Light AND in Dark, and nothing in a
      // reward theme.
      const rewards = [
        AppThemeVariant.smokyIvory,
        AppThemeVariant.seashellMauve,
        AppThemeVariant.onyxAmber,
        AppThemeVariant.royalIndigo,
        AppThemeVariant.midnightIndigo,
        AppThemeVariant.vellum,
      ];
      for (final r in kRoyalAvatars) {
        final dress = courtDressFor('pixel', '${r.spriteIndex}')!;
        for (final (variant, expected) in [
          (AppThemeVariant.light, r.theme.accentDeep),
          (AppThemeVariant.dark, r.theme.accent),
        ]) {
          final base = AppTheme.of(variant);
          final dressed = dress(variant, base);
          expect(dressed.extension<AppPalette>()!.colors.brandAccent, expected,
              reason: '${r.id} on $variant');
          expect(dressed.extension<AppPalette>()!.hero.accent, expected,
              reason: '${r.id} hero on $variant');
          // The canvas is never the court's to touch — only the gold slots.
          expect(dressed.extension<AppPalette>()!.colors.background,
              base.extension<AppPalette>()!.colors.background,
              reason: '${r.id} repainted the $variant canvas');
        }
        for (final variant in rewards) {
          final base = AppTheme.of(variant);
          expect(dress(variant, base), same(base),
              reason: '${r.id} should leave $variant hand-tuned');
        }
      }
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

      // Swapping to another royal swaps the court with it — the Medic used
      // to be a no-op here, because an emerald court could not dress light.
      final medic = kRoyalAvatars.firstWhere((r) => r.id == 'royalmedic');
      provider
          .setThemeDress(courtDressFor('pixel', '${medic.spriteIndex}'));
      expect(provider.activeTheme.extension<AppPalette>()!.colors.brandAccent,
          medic.theme.accentDeep);

      // ...and he follows the user into dark, in his bright shade.
      provider.setVariant(AppThemeVariant.dark);
      expect(provider.activeTheme.extension<AppPalette>()!.colors.brandAccent,
          medic.theme.accent);
      provider.setVariant(AppThemeVariant.light);

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
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
            // The picker's "Enable Custom Animations" toggle reads this.
            ChangeNotifierProvider<AppPreferences>(
                create: (_) => AppPreferences()),
          ],
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
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
            // The royal sheet's "switch theme" row reads ThemeProvider.
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
            // The picker's "Enable Custom Animations" toggle reads this.
            ChangeNotifierProvider<AppPreferences>(
                create: (_) => AppPreferences()),
          ],
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
                        // Sovereign already unlocked, so his court sheet
                        // offers Equip (not the locked/Unlock states).
                        unlockedRoyals: {royal.id},
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
      // both-modes note, the app-wide toggle, and Equip. The ROYALTY
      // section sits below the fold, so bring the tile on-screen first.
      final tile = find.byWidgetPredicate(
          (w) => w is AnimatedRoyalAvatar && w.royal.id == royal.id);
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Two switches now: the app-wide court theme AND the global
      // custom-animations toggle (which lives in this court sheet).
      expect(find.byType(SwitchListTile), findsNWidgets(2));
      expect(find.text('Apply app-wide Crimson theme'), findsOneWidget);
      expect(find.text('Enable Custom Animations'), findsOneWidget);
      expect(find.text('The Sovereign'), findsWidgets);
      expect(find.text('Equip'), findsOneWidget);

      // Flip the theme toggle off, equip him, then save the picker.
      await tester.tap(
          find.widgetWithText(SwitchListTile, 'Apply app-wide Crimson theme'));
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

    testWidgets('the court sheet promises both modes, and offers the other',
        (tester) async {
      // The sheet used to name a single home theme ("Rules the Dark theme")
      // and, off it, nag the user to switch. Now it promises both and offers
      // the other mode as a look — from either side. Run it on a DARK-court
      // royal so the old copy would have failed the light half outright.
      final royal = kRoyalAvatars.firstWhere((r) => r.id == 'princess');
      for (final variant in [AppThemeVariant.light, AppThemeVariant.dark]) {
        final onLight = variant == AppThemeVariant.light;
        final theme = ThemeProvider();
        await theme.setVariant(variant);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>(
                  create: (_) => LocaleProvider()),
              ChangeNotifierProvider<ThemeProvider>.value(value: theme),
              ChangeNotifierProvider<AppPreferences>(
                  create: (_) => AppPreferences()),
            ],
            // Wire the app theme to the provider, as main.dart does, so the
            // hop below really does re-theme the app under the open sheet.
            child: Consumer<ThemeProvider>(
              builder: (_, tp, _) => MaterialApp(
                key: ValueKey(variant),
                theme: tp.activeTheme,
                home: Builder(
                  builder: (ctx) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () => showAvatarPicker(
                          ctx,
                          const GamiProfile(
                              avatarKind: 'pixel', avatarValue: '0'),
                          unlockedRoyals: {royal.id},
                        ),
                        child: const Text('open'),
                      ),
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

        final tile = find.byWidgetPredicate(
            (w) => w is AnimatedRoyalAvatar && w.royal.id == royal.id);
        await tester.ensureVisible(tile);
        await tester.pump();
        await tester.tap(tile, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final where = '$variant';
        expect(
          find.textContaining('Reigns in Light and Dark'),
          findsOneWidget,
          reason: '$where: the both-modes pill should be on the sheet',
        );
        // The court is live right here...
        expect(
          find.text(onLight
              ? 'Its court is live on your Light theme'
              : 'Its court is live on your Dark theme'),
          findsOneWidget,
          reason: '$where: the sheet should confirm the dress is on',
        );
        // ...and one tap away in the other mode.
        final hop = find.text(
            onLight ? 'See it in the Dark theme' : 'See it in the Light theme');
        expect(hop, findsOneWidget, reason: '$where: no hop to the other mode');

        // The sheet's own fill, read off the widget tree. This is the value
        // that goes stale if the palette is captured before the sheet opens
        // instead of inside its builder — the row's text can't catch that,
        // because it watches ThemeProvider directly and flips either way.
        Color sheetSurface() => (tester
                .widget<Container>(find
                    .descendant(
                      of: find.byType(StatefulBuilder),
                      matching: find.byType(Container),
                    )
                    .first)
                .decoration! as BoxDecoration)
            .color!;
        expect(sheetSurface(), AppColors.forVariant(variant).surface,
            reason: '$where: the sheet should open in the active mode');
        await tester.ensureVisible(hop);
        await tester.pump();
        await tester.tap(hop);
        await tester.pump();
        expect(
          theme.variant,
          onLight ? AppThemeVariant.dark : AppThemeVariant.light,
          reason: '$where: tapping the hop should switch the app theme',
        );
        // ...and the open sheet follows it over, rather than sitting in the
        // mode the user just left.
        await tester.pump();
        expect(
          sheetSurface(),
          AppColors.forVariant(
              onLight ? AppThemeVariant.dark : AppThemeVariant.light).surface,
          reason: '$where: the open sheet should repaint into the new mode',
        );
        expect(
          find.text(onLight
              ? 'Its court is live on your Dark theme'
              : 'Its court is live on your Light theme'),
          findsOneWidget,
          reason: '$where: the live line should follow the switch',
        );
        expect(tester.takeException(), isNull, reason: where);
      }
    });

    testWidgets('locked royals read "Coming soon" and cannot be equipped',
        (tester) async {
      final royal = kRoyalAvatars.first;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
            // The court sheet re-installs the live app theme over itself, so
            // it needs the provider even on the locked path.
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
            ChangeNotifierProvider<AppPreferences>(
                create: (_) => AppPreferences()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    // No unlocks, no picks → the whole court is locked.
                    onPressed: () => showAvatarPicker(
                      ctx,
                      const GamiProfile(avatarKind: 'pixel', avatarValue: '0'),
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

      // Locked tiles carry a "Coming soon" pill and the section hint.
      final tile = find.byWidgetPredicate(
          (w) => w is AnimatedRoyalAvatar && w.royal.id == royal.id);
      await tester.ensureVisible(tile);
      await tester.pump();
      expect(find.text('Coming soon'), findsWidgets);

      // The court sheet offers neither Equip nor Unlock — just the note.
      await tester.tap(tile, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Equip'), findsNothing);
      expect(find.text('Unlock & equip'), findsNothing);
      expect(find.textContaining('Reach a 10- or 24-day streak'),
          findsOneWidget);
    });

    testWidgets('a royal pick unlocks and equips a chosen royal',
        (tester) async {
      final royal = kRoyalAvatars.first;
      GamiProfile? result;
      final unlockedCalls = <String>[];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
            ChangeNotifierProvider<AppPreferences>(
                create: (_) => AppPreferences()),
          ],
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
                        royalPicksAvailable: 1,
                        onUnlockRoyal: (id) async => unlockedCalls.add(id),
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

      // A pick is waiting, so the locked royal offers "Unlock".
      final tile = find.byWidgetPredicate(
          (w) => w is AnimatedRoyalAvatar && w.royal.id == royal.id);
      await tester.ensureVisible(tile);
      await tester.pump();
      expect(find.text('Unlock'), findsWidgets);

      await tester.tap(tile, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final unlockBtn = find.text('Unlock & equip');
      expect(unlockBtn, findsOneWidget);
      await tester.ensureVisible(unlockBtn);
      await tester.pump();
      await tester.tap(unlockBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The host was told to persist the unlock, and the royal is now equipped.
      expect(unlockedCalls, [royal.id]);
      await tester.ensureVisible(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(result?.avatarValue, '${royal.spriteIndex}');
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
