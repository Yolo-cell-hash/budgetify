import 'package:budget_tracker/models/streak_reward.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/gamification_service.dart';
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
      expect(
        unlockedStreakRewards(7).map((r) => r.id),
        ['theme_smoky_ivory', 'theme_seashell_mauve'],
      );
      expect(
        unlockedStreakRewards(14).map((r) => r.id),
        ['theme_smoky_ivory', 'theme_seashell_mauve', 'theme_onyx_amber'],
      );
      expect(unlockedStreakRewards(100).length, kStreakRewards.length);
    });

    test('rewards map to distinct theme variants', () {
      expect(streakRewardForVariant(AppThemeVariant.smokyIvory)?.id,
          'theme_smoky_ivory');
      expect(streakRewardForVariant(AppThemeVariant.seashellMauve)?.id,
          'theme_seashell_mauve');
      expect(streakRewardForVariant(AppThemeVariant.light), isNull);
      expect(streakRewardForVariant(AppThemeVariant.dark), isNull);

      final variants = kStreakRewards.map((r) => r.themeVariant).toSet();
      expect(variants.length, kStreakRewards.length); // all distinct, non-null
    });

    test('catalog is ascending by days and well-formed', () {
      for (var i = 1; i < kStreakRewards.length; i++) {
        expect(kStreakRewards[i].days,
            greaterThan(kStreakRewards[i - 1].days));
      }
      for (final r in kStreakRewards) {
        expect(r.swatch.length, 2);
        expect(r.themeVariant, isNotNull);
        expect(r.id, isNotEmpty);
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
      // Nothing unlocked yet, so no apply control is shown.
      expect(find.text('Apply theme'), findsNothing);
    });
  });
}
