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

    test('Master Budgeter targets every medal plus every other title', () {
      final p = prog(const GamiStats(), 'masterbudgeter');
      final totalBadges =
          kAchievementGroups.fold<int>(0, (n, g) => n + g.tiers.length);
      expect(p.target, totalBadges + kTitles.length - 1);
      expect(p.current, 0);
      expect(p.earned, isFalse);
      expect(p.title.unit, 'unlocks');
    });

    // A stats snapshot that maxes out every ladder and every regular title.
    GamiStats maxed({int goalsCompleted = 10}) {
      final allMonth = MonthStat(categoryShare: const {
        'Food & Dining': 1,
        'Groceries': 1,
        'Shopping': 1,
        'Transportation': 1,
        'Bills & Utilities': 1,
        'Entertainment': 1,
        'Health & Medical': 1,
        'Travel': 1,
        'Education': 1,
        'Investments': 1,
      }, savingsRate: 0.9);
      return GamiStats(
        currentStreak: 730,
        longestStreak: 730,
        totalTracked: 5000000,
        txnCount: 8000,
        monthsOfData: 48,
        fullyTaggedMonths: 36,
        monthsWithinBudget: 12,
        monthsSavingsRate20: 12,
        noSpendDays: 90,
        distinctCategories: 9,
        netWorth: 10000000,
        debtFreeDays: 120,
        goalsCompleted: goalsCompleted,
        monthStats: List.generate(6, (_) => allMonth),
      );
    }

    test('Master Budgeter unlocks only with the complete catalog', () {
      final done = prog(maxed(), 'masterbudgeter');
      expect(done.current, done.target);
      expect(done.earned, isTrue);
      expect(
          evaluateTitles(maxed()).any((t) => t.id == kMasterTitleId), isTrue);

      // One medal missing (9/10 goals) keeps the crown locked.
      final nearly = prog(maxed(goalsCompleted: 9), 'masterbudgeter');
      expect(nearly.current, nearly.target - 1);
      expect(nearly.earned, isFalse);
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
    test('an armed freeze bridges a single missed day', () {
      // Missed 6/19; opened 6/20 with a freeze armed → streak continues.
      final r = GamificationService.advanceStreak(
          last: DateTime(2026, 6, 18),
          current: 5,
          longest: 5,
          today: today,
          freezeArmed: true);
      expect(r.current, 6);
      expect(r.freezeUsed, isTrue);
    });
    test('a freeze does not cover a two-day gap', () {
      final r = GamificationService.advanceStreak(
          last: DateTime(2026, 6, 17),
          current: 9,
          longest: 9,
          today: today,
          freezeArmed: true);
      expect(r.current, 1);
      expect(r.freezeUsed, isFalse);
    });
    test('without a freeze, a missed day still resets', () {
      final r = GamificationService.advanceStreak(
          last: DateTime(2026, 6, 18), current: 5, longest: 5, today: today);
      expect(r.current, 1);
      expect(r.freezeUsed, isFalse);
    });
    test('a one-day break with nothing armed is flagged restorable', () {
      final r = GamificationService.advanceStreak(
          last: DateTime(2026, 6, 18), current: 5, longest: 5, today: today);
      expect(r.restorable, isTrue);
    });
    test('longer gaps, bridged days and normal advances are not restorable',
        () {
      // Two days missed — too late for a single freeze.
      expect(
          GamificationService.advanceStreak(
                  last: DateTime(2026, 6, 17),
                  current: 5,
                  longest: 5,
                  today: today)
              .restorable,
          isFalse);
      // Armed freeze already bridged it — nothing left to save.
      expect(
          GamificationService.advanceStreak(
                  last: DateTime(2026, 6, 18),
                  current: 5,
                  longest: 5,
                  today: today,
                  freezeArmed: true)
              .restorable,
          isFalse);
      // Plain next-day advance.
      expect(
          GamificationService.advanceStreak(
                  last: DateTime(2026, 6, 19),
                  current: 5,
                  longest: 5,
                  today: today)
              .restorable,
          isFalse);
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

    test('reaching day 5 earns the interval freeze plus the road pack',
        () async {
      final svc = GamificationService();
      for (var d = 1; d <= 5; d++) {
        await svc.recordActiveDay(now: DateTime(2026, 6, d));
      }
      final s = (await svc.exportSettings())['streak'] as Map;
      // One from the every-5-days earn, one from the 5-day road pack.
      expect(s['freezes'], 2);
      // The pack granted once — later days don't re-grant it.
      await svc.recordActiveDay(now: DateTime(2026, 6, 6));
      expect(((await svc.exportSettings())['streak'] as Map)['freezes'], 2);
    });

    test('a saveable break offers a streak save on the return day only',
        () async {
      final svc = GamificationService();
      for (var d = 1; d <= 5; d++) {
        await svc.recordActiveDay(now: DateTime(2026, 6, d));
      }
      // Miss 6/6, come back 6/7: streak resets but the save offer stands.
      await svc.recordActiveDay(now: DateTime(2026, 6, 7));
      expect((await svc.streakInfo()).current, 1);
      final offer = await svc.streakSaveOffer(now: DateTime(2026, 6, 7));
      expect(offer, isNotNull);
      expect(offer!.previous, 5);
      expect(offer.freezes, 2);
      // The auto-prompt pops exactly once; the offer itself keeps standing.
      expect(await svc.popStreakSavePrompt(now: DateTime(2026, 6, 7)),
          isNotNull);
      expect(
          await svc.popStreakSavePrompt(now: DateTime(2026, 6, 7)), isNull);
      expect(
          await svc.streakSaveOffer(now: DateTime(2026, 6, 7)), isNotNull);
      // Next day the offer has melted.
      expect(await svc.streakSaveOffer(now: DateTime(2026, 6, 8)), isNull);
    });

    test('restoreStreak revives the streak for one freeze', () async {
      final svc = GamificationService();
      for (var d = 1; d <= 5; d++) {
        await svc.recordActiveDay(now: DateTime(2026, 6, d));
      }
      await svc.recordActiveDay(now: DateTime(2026, 6, 7)); // missed 6/6
      final restored = await svc.restoreStreak(now: DateTime(2026, 6, 7));
      // 5-day streak + the return day = 6, one of the two freezes spent.
      expect(restored, 6);
      expect((await svc.streakInfo()).current, 6);
      expect((await svc.streakInfo()).longest, 6);
      expect((await svc.freezeInfo()).available, 1);
      // The offer is consumed — a second restore does nothing.
      expect(await svc.restoreStreak(now: DateTime(2026, 6, 7)), isNull);
      // And the streak keeps rolling normally afterwards.
      await svc.recordActiveDay(now: DateTime(2026, 6, 8));
      expect((await svc.streakInfo()).current, 7);
    });

    test('a break with an empty stash offers no save', () async {
      final svc = GamificationService();
      // Only a 3-day streak: no interval freeze, no pack yet.
      for (var d = 1; d <= 3; d++) {
        await svc.recordActiveDay(now: DateTime(2026, 6, d));
      }
      expect((await svc.freezeInfo()).available, 0);
      await svc.recordActiveDay(now: DateTime(2026, 6, 5)); // missed 6/4
      expect(await svc.streakSaveOffer(now: DateTime(2026, 6, 5)), isNull);
      expect(await svc.restoreStreak(now: DateTime(2026, 6, 5)), isNull);
    });

    test('an armed freeze still bridges automatically with no offer',
        () async {
      final svc = GamificationService();
      for (var d = 1; d <= 5; d++) {
        await svc.recordActiveDay(now: DateTime(2026, 6, d));
      }
      expect(await svc.armFreeze(), isTrue);
      await svc.recordActiveDay(now: DateTime(2026, 6, 7)); // missed 6/6
      // Bridged: streak continues, armed slot spent, no save offer.
      expect((await svc.streakInfo()).current, 6);
      expect((await svc.freezeInfo()).armed, isFalse);
      expect(await svc.streakSaveOffer(now: DateTime(2026, 6, 7)), isNull);
    });

    test('syncFreezePacks retrofits packs for an already-long streak',
        () async {
      final svc = GamificationService();
      // Simulate a pre-update profile: long streak recorded, no pack grants.
      await svc.importSettings({
        'streak': {
          'last': DateTime(2026, 6, 20).toIso8601String(),
          'current': 20,
          'longest': 20,
          'freezes': 0,
          'freezeArmed': false,
        },
      });
      await svc.syncFreezePacks();
      // 5-day (+1) and 18-day (+2) packs land; the 36-day pack stays locked.
      expect((await svc.freezeInfo()).available, 3);
      // Idempotent.
      await svc.syncFreezePacks();
      expect((await svc.freezeInfo()).available, 3);
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
