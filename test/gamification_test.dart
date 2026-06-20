import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/models/achievement.dart';
import 'package:budget_tracker/services/gamification_service.dart';

AchievementGroup _group(String id) =>
    kAchievementGroups.firstWhere((g) => g.id == id);

void main() {
  group('Achievement ladders', () {
    test('streak earns up to the longest reached, with next-tier progress', () {
      final p = evaluateGroup(_group('streak'), const GamiStats(longestStreak: 120));
      // 7/30/50/100 earned; 200 not.
      expect(p.earnedCount, 4);
      expect(p.nextTier!.threshold, 200);
      // 120 between 100 and 200 → 20%.
      expect(p.nextProgress, closeTo(0.2, 1e-9));
    });

    test('money-tracked ladder uses the updated thresholds', () {
      final p = evaluateGroup(_group('amount'), const GamiStats(totalTracked: 900000));
      expect(p.earned[2], isTrue); // ₹8L
      expect(p.earned[3], isFalse); // ₹12L
      expect(p.nextTier!.label, '₹12L');
    });

    test('a complete ladder reports no next tier', () {
      final p = evaluateGroup(_group('txn'), const GamiStats(txnCount: 9000));
      expect(p.isComplete, isTrue);
      expect(p.nextTier, isNull);
      expect(p.earnedCount, _group('txn').tiers.length);
    });

    test('debt-free is a single 120-day badge', () {
      expect(evaluateGroup(_group('debtfree'), const GamiStats(debtFreeDays: 119)).earnedCount, 0);
      expect(evaluateGroup(_group('debtfree'), const GamiStats(debtFreeDays: 120)).earnedCount, 1);
    });

    test('earnedBadgeIds / badgeById round-trip', () {
      final ids = earnedBadgeIds(const GamiStats(txnCount: 600));
      expect(ids, contains('txn.0')); // 500
      expect(ids, isNot(contains('txn.2'))); // 1000
      final b = badgeById('txn.0')!;
      expect(b.group.id, 'txn');
      expect(b.tierIndex, 0);
    });
  });

  group('Titles', () {
    MonthStat ms(Map<String, double> share, double sr) =>
        MonthStat(categoryShare: share, savingsRate: sr);
    TitleProgress prog(GamiStats s, String id) =>
        evaluateTitleProgress(s).firstWhere((p) => p.title.id == id);

    test('category title is earned after enough qualifying months', () {
      final six = GamiStats(
          monthStats: List.generate(6, (_) => ms({'Food & Dining': 0.40}, 0.1)));
      expect(prog(six, 'foodie').current, 6);
      expect(prog(six, 'foodie').earned, isTrue);
      expect(evaluateTitles(six).any((t) => t.id == 'foodie'), isTrue);

      // Five qualifying months → 5/6, not earned.
      final five = GamiStats(
          monthStats: List.generate(5, (_) => ms({'Food & Dining': 0.40}, 0.1)));
      expect(prog(five, 'foodie').current, 5);
      expect(prog(five, 'foodie').target, 6);
      expect(prog(five, 'foodie').earned, isFalse);

      // Below-threshold months never count.
      final low = GamiStats(
          monthStats: List.generate(6, (_) => ms({'Food & Dining': 0.30}, 0.1)));
      expect(prog(low, 'foodie').current, 0);
    });

    test('Travel needs only 3 qualifying months', () {
      final t = GamiStats(
          monthStats: List.generate(3, (_) => ms({'Travel': 0.30}, 0.1)));
      expect(prog(t, 'globetrotter').target, 3);
      expect(prog(t, 'globetrotter').earned, isTrue);
    });

    test('savings titles count qualifying months', () {
      final s = GamiStats(monthStats: List.generate(6, (_) => ms({}, 0.62)));
      expect(evaluateTitles(s).map((t) => t.id), containsAll(['moneymagnet', 'frugal']));
    });

    test('Broke Spender needs 90 no-spend days', () {
      expect(evaluateTitles(const GamiStats(noSpendDays: 90)).any((t) => t.id == 'broke'), isTrue);
      expect(evaluateTitles(const GamiStats(noSpendDays: 89)).any((t) => t.id == 'broke'), isFalse);
      final p = prog(const GamiStats(noSpendDays: 45), 'broke');
      expect(p.current, 45);
      expect(p.target, 90);
    });

    test('there is no default/fallback title', () {
      expect(evaluateTitles(const GamiStats()), isEmpty);
    });
  });

  group('Streak math (pure)', () {
    final today = DateTime(2026, 6, 20);
    test('consecutive day increments', () {
      final r = GamificationService.advanceStreak(
          last: DateTime(2026, 6, 19), current: 4, longest: 4, today: today);
      expect(r.current, 5);
      expect(r.longest, 5);
    });
    test('same day is a no-op', () {
      final r = GamificationService.advanceStreak(
          last: today, current: 4, longest: 9, today: today);
      expect(r.current, 4);
      expect(r.longest, 9);
    });
    test('a gap resets current but keeps longest', () {
      final r = GamificationService.advanceStreak(
          last: DateTime(2026, 6, 16), current: 10, longest: 10, today: today);
      expect(r.current, 1);
      expect(r.longest, 10);
    });
    test('first ever day starts at 1', () {
      final r = GamificationService.advanceStreak(
          last: null, current: 0, longest: 0, today: today);
      expect(r.current, 1);
      expect(r.longest, 1);
    });
  });

  group('Service persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('recordActiveDay rolls the streak and is idempotent per day', () async {
      final svc = GamificationService();
      await svc.recordActiveDay(now: DateTime(2026, 6, 18));
      await svc.recordActiveDay(now: DateTime(2026, 6, 18)); // same day
      await svc.recordActiveDay(now: DateTime(2026, 6, 19));
      final blob = await svc.exportSettings();
      expect((blob['streak'] as Map)['current'], 2);
      expect((blob['streak'] as Map)['longest'], 2);
    });

    test('profile saves and loads', () async {
      final svc = GamificationService();
      const p = GamiProfile(
        username: 'Riya',
        avatarKind: 'pixel',
        avatarValue: '3',
        avatarAccent: 2,
        showcasedBadgeIds: ['amount.0', 'streak.1'],
        primaryTitleId: 'foodie',
      );
      await svc.saveProfile(p);
      final back = await svc.loadProfile();
      expect(back.username, 'Riya');
      expect(back.avatarKind, 'pixel');
      expect(back.avatarValue, '3');
      expect(back.avatarAccent, 2);
      expect(back.showcasedBadgeIds, ['amount.0', 'streak.1']);
      expect(back.primaryTitleId, 'foodie');
    });

    test('export/import round-trips for backup', () async {
      final svc = GamificationService();
      await svc.saveProfile(const GamiProfile(username: 'Sam'));
      await svc.recordActiveDay(now: DateTime(2026, 6, 20));
      final exported = await svc.exportSettings();

      SharedPreferences.setMockInitialValues({}); // simulate fresh install
      final svc2 = GamificationService();
      expect((await svc2.loadProfile()).username, '');
      await svc2.importSettings(exported);
      expect((await svc2.loadProfile()).username, 'Sam');
      expect((await svc2.exportSettings())['streak'], isNotNull);
    });
  });
}
