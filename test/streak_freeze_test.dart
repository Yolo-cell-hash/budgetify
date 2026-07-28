import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/screens/streak_rewards_screen.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/streak_save_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Providers every streak surface reads (theme colours + l10n).
Widget _wrap(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp(home: child),
    );

/// [n] days before today, date-only. The save sheet and the rewards screen
/// both call into the service without a `now`, so anything they must see has
/// to be seeded against the real clock rather than a fixed calendar date.
DateTime _dayAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
}

/// An unbroken [days]-day streak ending today.
Future<GamificationService> _streakEndingToday(int days) async {
  final svc = GamificationService();
  for (var i = days - 1; i >= 0; i--) {
    await svc.recordActiveDay(now: _dayAgo(i));
  }
  return svc;
}

/// A [days]-day streak that broke on a single missed day, with the user back
/// today — i.e. a streak-save offer standing right now.
Future<GamificationService> _brokenStreakWithOfferToday(int days) async {
  final svc = GamificationService();
  for (var i = days + 1; i >= 2; i--) {
    await svc.recordActiveDay(now: _dayAgo(i));
  }
  await svc.recordActiveDay(now: _dayAgo(0)); // missed yesterday
  return svc;
}

void main() {
  group('Streak save sheet', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// Pumps a host that opens the save sheet; [popped] receives its result.
    Future<void> openSheet(
      WidgetTester tester, {
      required int previous,
      required int available,
      List<int?>? popped,
    }) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final r = await showStreakSaveSheet(
                  context,
                  previous: previous,
                  available: available,
                );
                popped?.add(r);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // scale-in
    }

    testWidgets('renders the offer, the stash count and both exits',
        (tester) async {
      await openSheet(tester, previous: 5, available: 2);

      expect(find.text('Save your 5-day streak?'), findsOneWidget);
      // The body promises where the streak lands: previous + the return day.
      expect(find.textContaining('carry on at 6 days'), findsOneWidget);
      expect(find.text('2 freezes in your stash'), findsOneWidget);
      expect(find.text('Use a Streak Freeze'), findsOneWidget);
      expect(find.text('Start fresh from Day 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single freeze is labelled in the singular', (tester) async {
      await openSheet(tester, previous: 3, available: 1);
      expect(find.text('1 freeze in your stash'), findsOneWidget);
    });

    testWidgets('spending a freeze restores the streak and pops the new count',
        (tester) async {
      final svc = await _brokenStreakWithOfferToday(5);
      final offer = await svc.streakSaveOffer();
      expect(offer, isNotNull);
      expect(offer!.previous, 5);

      final popped = <int?>[];
      await openSheet(tester,
          previous: offer.previous, available: offer.freezes, popped: popped);
      await tester.tap(find.text('Use a Streak Freeze'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The sheet closed reporting the restored length, and the service agrees.
      expect(find.text('Use a Streak Freeze'), findsNothing);
      expect(popped, [6]);
      expect((await svc.streakInfo()).current, 6);
      expect((await svc.streakInfo()).longest, 6);
      expect((await svc.freezeInfo()).available, 1);
      // The offer is spent — it cannot be taken twice.
      expect(await svc.streakSaveOffer(), isNull);
    });

    testWidgets('starting fresh spends nothing and leaves the streak broken',
        (tester) async {
      final svc = await _brokenStreakWithOfferToday(5);

      final popped = <int?>[];
      await openSheet(tester, previous: 5, available: 2, popped: popped);
      await tester.tap(find.text('Start fresh from Day 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Use a Streak Freeze'), findsNothing);
      expect(popped, [null]);
      expect((await svc.streakInfo()).current, 1);
      expect((await svc.freezeInfo()).available, 2);
    });

    testWidgets('an offer that lapsed closes without pretending it restored',
        (tester) async {
      // Streak intact, so there is no offer to take: the button must close the
      // sheet with null rather than report a restore that never happened.
      final svc = await _streakEndingToday(5);
      expect(await svc.streakSaveOffer(), isNull);

      final popped = <int?>[];
      await openSheet(tester, previous: 5, available: 2, popped: popped);
      await tester.tap(find.text('Use a Streak Freeze'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Use a Streak Freeze'), findsNothing);
      expect(popped, [null]);
      expect((await svc.freezeInfo()).available, 2); // nothing spent
    });
  });

  group('Freeze card on the Streak Rewards screen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// The road animates on unlocked medallions, so settle by fixed pumps.
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const StreakRewardsScreen()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    testWidgets('arming moves a freeze from the stash to the armed slot',
        (tester) async {
      final svc = await _streakEndingToday(5); // 2 freezes banked
      expect((await svc.freezeInfo()).available, 2);

      await pumpScreen(tester);
      expect(find.text('Arm a freeze'), findsOneWidget);
      expect(find.text('ARMED'), findsNothing);
      expect(find.textContaining('A freeze saves your streak'), findsOneWidget);

      await tester.tap(find.text('Arm a freeze'));
      await settle(tester);

      // Persisted, and the card now reads as armed.
      final info = await svc.freezeInfo();
      expect(info.armed, isTrue);
      expect(info.available, 1);
      expect(find.text('ARMED'), findsOneWidget);
      expect(find.textContaining('a freeze bridges it automatically'),
          findsOneWidget);
      // An armed card offers no second arm.
      expect(find.text('Arm a freeze'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty stash disables the arm control', (tester) async {
      await _streakEndingToday(3); // no freeze earned before day 5

      await pumpScreen(tester);
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Arm a freeze'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a standing save offer surfaces the restore banner and works',
        (tester) async {
      final svc = await _brokenStreakWithOfferToday(5);

      await pumpScreen(tester);
      expect(find.text('Restore your 5-day streak'), findsOneWidget);

      await tester.tap(find.text('Restore'));
      await settle(tester);
      await tester.tap(find.text('Use a Streak Freeze'));
      await settle(tester);

      expect((await svc.streakInfo()).current, 6);
      expect((await svc.freezeInfo()).available, 1);
      // Banner clears once the offer is taken.
      expect(find.text('Restore your 5-day streak'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ── Known defects ───────────────────────────────────────────────────────
  // These reproduce bugs that are still open; un-skip them with the fix.

  group('DST: a 23-hour local day breaks the gap arithmetic', () {
    // advanceStreak measures the gap as `today.difference(last).inDays` over
    // two local wall-clock midnights. On the spring-forward day that span is
    // 23 hours, which truncates to 0 — so a *consecutive* day is read as
    // "same day or earlier" and falls through to the reset branch. Run under
    // TZ=America/New_York to see it (2026-03-08 is the US transition).
    test('consecutive days across spring-forward keep the streak', () {
      final r = GamificationService.advanceStreak(
        last: DateTime(2026, 3, 8),
        current: 9,
        longest: 9,
        today: DateTime(2026, 3, 9),
      );
      expect(r.current, 10);
    });

    test('an armed freeze still protects the day after spring-forward', () {
      final r = GamificationService.advanceStreak(
        last: DateTime(2026, 3, 8),
        current: 9,
        longest: 9,
        today: DateTime(2026, 3, 9),
        freezeArmed: true,
      );
      // Whether it bridges or simply advances, the streak must not reset —
      // and the user must not silently lose the armed freeze's protection.
      expect(r.current, greaterThan(1));
    });
  },
      skip: 'Open bug: inDays() truncates the 23-hour DST day to 0, resetting '
          'the streak on a consecutive day with no freeze and no save offer.');

  group('Lost update: the blob is read-modify-written without a lock', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    // Every mutation is read → mutate → write over one JSON blob in
    // SharedPreferences. main.dart fires recordAppTime() unawaited when the
    // app is backgrounded, so it can interleave with any streak write and
    // clobber it wholesale.
    test('arming a freeze survives a concurrent appTime write', () async {
      final svc = await _streakEndingToday(5);
      await Future.wait<void>([
        svc.armFreeze(),
        svc.recordAppTime(600),
      ]);
      final f = await svc.freezeInfo();
      expect(f.armed, isTrue);
      expect(f.available, 1);
    });

    test('a streak restore survives a concurrent appTime write', () async {
      final svc = await _brokenStreakWithOfferToday(5);
      await Future.wait<void>([
        svc.restoreStreak(),
        svc.recordAppTime(600),
      ]);
      expect((await svc.streakInfo()).current, 6);
    });
  },
      skip: 'Open bug: concurrent read-modify-write on the gamification blob '
          'silently discards an arm or a restore.');
}
