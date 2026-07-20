import 'package:budget_tracker/models/streak_reward.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/streak_reward_road.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StreakReward catalog', () {
    test('unlock thresholds by longest streak', () {
      expect(unlockedStreakRewards(0), isEmpty);
      expect(unlockedStreakRewards(2), isEmpty);
      expect(unlockedStreakRewards(3).map((r) => r.id), ['theme_smoky_ivory']);
      // The first freeze pack sits at 5 days, between the first two themes.
      expect(
        unlockedStreakRewards(7).map((r) => r.id),
        ['theme_smoky_ivory', 'freeze_pack_1', 'theme_seashell_mauve'],
      );
      // A royal pick sits at 10 days, between the 7- and 14-day themes.
      expect(
        unlockedStreakRewards(10).map((r) => r.id),
        [
          'theme_smoky_ivory',
          'freeze_pack_1',
          'theme_seashell_mauve',
          'royal_pick_1',
        ],
      );
      expect(
        unlockedStreakRewards(14).map((r) => r.id),
        [
          'theme_smoky_ivory',
          'freeze_pack_1',
          'theme_seashell_mauve',
          'royal_pick_1',
          'theme_onyx_amber',
        ],
      );
      expect(unlockedStreakRewards(100).length, kStreakRewards.length);
    });

    test('freeze packs sit at 5, 18 and 36 days with positive grants', () {
      final packs = kStreakRewards
          .where((r) => r.kind == StreakRewardKind.freeze)
          .toList();
      expect(packs.map((r) => r.days), [5, 18, 36]);
      expect(packs.map((r) => r.freezeCount), [1, 2, 2]);
      // Only freeze packs grant freezes.
      for (final r in kStreakRewards) {
        expect(r.freezeCount > 0, r.kind == StreakRewardKind.freeze,
            reason: '${r.id} freezeCount/kind mismatch');
      }
    });

    test('royal picks are earned at the 10- and 24-day milestones', () {
      expect(royalPicksEarned(0), 0);
      expect(royalPicksEarned(9), 0);
      expect(royalPicksEarned(10), 1);
      expect(royalPicksEarned(23), 1);
      expect(royalPicksEarned(24), 2);
      expect(royalPicksEarned(100), 2);
      // The two royal-pick milestones live in the catalog at those days.
      final picks = kStreakRewards
          .where((r) => r.kind == StreakRewardKind.royalPick)
          .toList();
      expect(picks.map((r) => r.days), kRoyalPickStreaks);
      expect(picks.every((r) => r.themeVariant == null), isTrue);
    });

    test('theme rewards map to distinct theme variants', () {
      expect(streakRewardForVariant(AppThemeVariant.smokyIvory)?.id,
          'theme_smoky_ivory');
      expect(streakRewardForVariant(AppThemeVariant.seashellMauve)?.id,
          'theme_seashell_mauve');
      expect(streakRewardForVariant(AppThemeVariant.light), isNull);
      expect(streakRewardForVariant(AppThemeVariant.dark), isNull);

      final themeRewards =
          kStreakRewards.where((r) => r.kind == StreakRewardKind.theme);
      final variants = themeRewards.map((r) => r.themeVariant).toSet();
      // Every theme reward has a distinct, non-null variant.
      expect(variants.length, themeRewards.length);
    });

    test('catalog is ascending by days and well-formed', () {
      for (var i = 1; i < kStreakRewards.length; i++) {
        expect(kStreakRewards[i].days,
            greaterThan(kStreakRewards[i - 1].days));
      }
      for (final r in kStreakRewards) {
        expect(r.swatch.length, 2);
        expect(r.id, isNotEmpty);
        // Theme rewards carry a variant; royal picks carry none.
        if (r.kind == StreakRewardKind.theme) {
          expect(r.themeVariant, isNotNull);
        } else {
          expect(r.themeVariant, isNull);
        }
      }
    });

    test('unlockedStreakRewardIds matches unlockedStreakRewards', () {
      expect(
        unlockedStreakRewardIds(7),
        unlockedStreakRewards(7).map((r) => r.id).toSet(),
      );
    });
  });

  group('AppTheme variants', () {
    test('every variant carries a matching AppPalette extension', () {
      for (final v in AppThemeVariant.values) {
        final theme = AppTheme.of(v);
        final palette = theme.extension<AppPalette>();
        expect(palette, isNotNull, reason: '$v is missing its AppPalette');
        expect(palette!.colors, AppColors.forVariant(v));
      }
    });

    test('dark and onyxAmber are the dark-brightness variants', () {
      expect(AppTheme.of(AppThemeVariant.dark).brightness, Brightness.dark);
      expect(
          AppTheme.of(AppThemeVariant.onyxAmber).brightness, Brightness.dark);
      expect(AppTheme.of(AppThemeVariant.light).brightness, Brightness.light);
      expect(
          AppTheme.of(AppThemeVariant.smokyIvory).brightness, Brightness.light);
      expect(AppTheme.of(AppThemeVariant.seashellMauve).brightness,
          Brightness.light);
    });
  });

  group('GamificationService streak helpers', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('streakInfo reflects recorded days', () async {
      final svc = GamificationService();
      expect(await svc.streakInfo(), (current: 0, longest: 0));
      await svc.recordActiveDay(now: DateTime(2026, 6, 18));
      expect((await svc.streakInfo()).current, 1);
    });

    test('first run adopts history, then celebrates new unlocks once', () async {
      final svc = GamificationService();
      // No streak yet: first call adopts the (empty) earned set silently.
      expect(await svc.popNewlyUnlockedStreakRewards(), isEmpty);

      // Reach a 3-day streak.
      await svc.recordActiveDay(now: DateTime(2026, 6, 18));
      await svc.recordActiveDay(now: DateTime(2026, 6, 19));
      await svc.recordActiveDay(now: DateTime(2026, 6, 20));
      expect((await svc.streakInfo()).longest, 3);

      // The 3-day theme is now freshly unlocked, exactly once.
      expect(await svc.popNewlyUnlockedStreakRewards(), ['theme_smoky_ivory']);
      expect(await svc.popNewlyUnlockedStreakRewards(), isEmpty);
    });

    test('pre-existing streak on first run is adopted without celebration',
        () async {
      // Simulate an install that already has a long streak (e.g. restored).
      final seed = GamificationService();
      await seed.recordActiveDay(now: DateTime(2026, 6, 14));
      await seed.recordActiveDay(now: DateTime(2026, 6, 15));
      await seed.recordActiveDay(now: DateTime(2026, 6, 16));
      await seed.recordActiveDay(now: DateTime(2026, 6, 17));
      await seed.recordActiveDay(now: DateTime(2026, 6, 18));
      await seed.recordActiveDay(now: DateTime(2026, 6, 19));
      await seed.recordActiveDay(now: DateTime(2026, 6, 20));
      expect((await seed.streakInfo()).longest, 7);

      // First-ever pop adopts both already-earned themes — no celebration.
      expect(await seed.popNewlyUnlockedStreakRewards(), isEmpty);
    });

    test('royal picks track earned-minus-spent, and unlocks persist',
        () async {
      final svc = GamificationService();
      expect(await svc.unlockedRoyalIds(), isEmpty);
      expect(await svc.availableRoyalPicks(), 0);

      // Reach a 10-day streak → one pick becomes available.
      for (var d = 1; d <= 10; d++) {
        await svc.recordActiveDay(now: DateTime(2026, 6, d));
      }
      expect((await svc.streakInfo()).longest, 10);
      expect(await svc.availableRoyalPicks(), 1);

      // Spend it on a royal: the pick is consumed and the unlock persists.
      await svc.unlockRoyal('sovereign');
      expect(await svc.unlockedRoyalIds(), {'sovereign'});
      expect(await svc.availableRoyalPicks(), 0);

      // Unlocking the same royal again is a no-op (no second pick spent).
      await svc.unlockRoyal('sovereign');
      expect(await svc.unlockedRoyalIds(), {'sovereign'});
      expect(await svc.availableRoyalPicks(), 0);

      // Carry the same streak on to 24 days → a second pick is earned.
      for (var d = 11; d <= 24; d++) {
        await svc.recordActiveDay(now: DateTime(2026, 6, d));
      }
      expect((await svc.streakInfo()).longest, 24);
      expect(await svc.availableRoyalPicks(), 1);
    });

    test('a royal worn before gating is re-locked on load (not grandfathered)',
        () async {
      final sovereign =
          kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      final empress = kRoyalAvatars.firstWhere((r) => r.id == 'empress');
      final svc = GamificationService();

      // Simulate a pre-gating backup: a royal saved directly, no pick spent.
      await svc.saveProfile(GamiProfile(
          avatarKind: 'pixel', avatarValue: '${sovereign.spriteIndex}'));

      // loadProfile resets it to a basic avatar; it stays locked, no free pick.
      expect((await svc.loadProfile()).avatarValue, '0');
      expect(await svc.unlockedRoyalIds(), isEmpty);
      expect(await svc.availableRoyalPicks(), 0);
      // Self-heals — a second load is stable.
      expect((await svc.loadProfile()).avatarValue, '0');

      // A royal genuinely bought with a pick is kept across loads.
      await svc.unlockRoyal(empress.id);
      await svc.saveProfile(GamiProfile(
          avatarKind: 'pixel', avatarValue: '${empress.spriteIndex}'));
      expect((await svc.loadProfile()).avatarValue, '${empress.spriteIndex}');
    });
  });

  group('StreakRewardRoad widget', () {
    testWidgets('renders milestones with locked hints at zero streak',
        (tester) async {
      // longestStreak 0 → every medallion is locked, so there are no repeating
      // animations to settle; a single frame fully renders the road.
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StreakRewardRoad(currentStreak: 0, longestStreak: 0),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Smoky Blue & Warm Ivory'), findsOneWidget);
      expect(find.text('Soft Seashell & Dusty Mauve'), findsOneWidget);
      expect(find.textContaining('Reach a 3-day streak'), findsOneWidget);
      expect(find.text('More streak rewards on the way.'), findsOneWidget);
      // The freeze packs appear on the road (5-, 18- and 36-day milestones).
      expect(find.text('+1 Streak Freeze'), findsOneWidget);
      expect(find.text('+2 Streak Freezes'), findsNWidgets(2));
      // Nothing unlocked yet, so no apply control is shown.
      expect(find.text('Apply theme'), findsNothing);
      expect(find.text('Added to your freeze stash'), findsNothing);
      // The royal-pick milestones appear on the road, still locked.
      expect(find.text('Royal Unlock'), findsWidgets);
      expect(find.textContaining('Reach a 10-day streak'), findsOneWidget);
    });

    testWidgets('a reached freeze pack reads as added to the stash',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StreakRewardRoad(currentStreak: 5, longestStreak: 5),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // The 5-day pack is claimed automatically; later packs stay locked.
      expect(find.text('Added to your freeze stash'), findsOneWidget);
      expect(find.textContaining('Reach an 18-day streak'), findsNothing);
      expect(find.textContaining('Reach a 18-day streak'), findsOneWidget);
    });

    testWidgets('a reached royal-pick milestone points to the Royalty section',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StreakRewardRoad(currentStreak: 10, longestStreak: 10),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // The 10-day pick is unlocked and nudges the user to choose a royal;
      // the 24-day pick is still locked.
      expect(find.textContaining('Choose your royal in the Royalty section'),
          findsOneWidget);
      expect(find.textContaining('Reach a 24-day streak'), findsOneWidget);
    });

    testWidgets('an unlocked royal pick shows "Unlock Now" and fires it',
        (tester) async {
      var chooseCalls = 0;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StreakRewardRoad(
                  currentStreak: 10,
                  longestStreak: 10,
                  royalPicksSpent: 0,
                  onChooseRoyal: () => chooseCalls++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final btn = find.widgetWithText(OutlinedButton, 'Unlock Now');
      expect(btn, findsOneWidget);
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn);
      await tester.pump();
      expect(chooseCalls, 1);
    });

    testWidgets('a spent royal pick reads as claimed, not "Unlock Now"',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StreakRewardRoad(
                  currentStreak: 10,
                  longestStreak: 10,
                  royalPicksSpent: 1,
                  onChooseRoyal: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // The 10-day pick's royal was chosen → claimed, and no Unlock Now for it.
      expect(find.text('Royal unlocked'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Unlock Now'), findsNothing);
    });
  });
}
