import 'dart:convert';
import 'dart:math' as math;

import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/services/app_events.dart';
import 'package:budget_tracker/services/financial_health_service.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/royal_character.dart';
import 'package:budget_tracker/widgets/royal_reactions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

FinancialHealth _health({
  required double income,
  required double expenses,
  double limit = 0,
  double spent = 0,
}) =>
    FinancialHealth(
      income: income,
      expenses: expenses,
      budgets: limit > 0 ? [BudgetUsage(limit: limit, spent: spent)] : const [],
    );

bool _hasCharacter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .any((c) => c.painter is RoyalCharacterPainter);

/// The shatter overlay is private to royal_reactions.dart; detect it by type
/// name so the test doesn't need the class exported.
bool _hasShatter(WidgetTester tester) =>
    tester.widgetList<CustomPaint>(find.byType(CustomPaint)).any(
        (c) => c.painter.runtimeType.toString() == '_ShatterPainter');

RoyalCharacterPainter? _characterPainter(WidgetTester tester) {
  for (final c in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final p = c.painter;
    if (p is RoyalCharacterPainter) return p;
  }
  return null;
}

Widget _host(AppPreferences prefs) => ChangeNotifierProvider<AppPreferences>.value(
      value: prefs,
      child: MaterialApp(
        home: RoyalReactionHost(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              // Stand in for the Home profile icon the boot routine anchors to.
              child: SizedBox(key: royalHomeAnchorKey, width: 38, height: 38),
            ),
          ),
        ),
      ),
    );

/// A host standing on the Budgets tab with the monthly-budget gauge laid out.
/// The over-budget attack only ever plays here now — it is never fired into
/// whatever screen the user happens to be on — so every test of the attack
/// itself needs this stage. Callers must restore [mainShellTabIndex].
Widget _budgetHost(AppPreferences prefs) {
  mainShellTabIndex.value = 1;
  return ChangeNotifierProvider<AppPreferences>.value(
    value: prefs,
    child: MaterialApp(
      home: RoyalReactionHost(
        child: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child:
                    SizedBox(key: royalHomeAnchorKey, width: 38, height: 38),
              ),
              Center(
                child: SizedBox(
                    key: royalBudgetChartAnchorKey, width: 160, height: 160),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Royal weapons', () {
    test('each royal wields its signature weapon', () {
      const expected = {
        'sovereign': RoyalWeapon.sword,
        'empress': RoyalWeapon.orbs,
        'prince': RoyalWeapon.knightSword,
        'darkprince': RoyalWeapon.warClub,
        'princess': RoyalWeapon.bow,
        'royalmedic': RoyalWeapon.medKit,
        'sentinel': RoyalWeapon.spear,
        'huntress': RoyalWeapon.daggers,
      };
      for (final r in kRoyalAvatars) {
        expect(r.weapon, expected[r.id], reason: r.id);
      }
      expect(kRoyalAvatars.map((r) => r.weapon).toSet().length,
          RoyalWeapon.values.length);
    });

    test('each weapon speaks its own attack verb', () {
      expect(royalAttackActionFor(RoyalWeapon.sword), RoyalAction.slash);
      expect(royalAttackActionFor(RoyalWeapon.knightSword), RoyalAction.slice);
      expect(royalAttackActionFor(RoyalWeapon.bow), RoyalAction.shoot);
      expect(royalAttackActionFor(RoyalWeapon.orbs), RoyalAction.hurl);
      expect(royalAttackActionFor(RoyalWeapon.warClub), RoyalAction.smash);
      expect(royalAttackActionFor(RoyalWeapon.medKit), RoyalAction.smash);
      // The Sentinel is the only royal who strikes from behind cover, and the
      // Huntress the only one who closes with her feet.
      expect(royalAttackActionFor(RoyalWeapon.spear), RoyalAction.thrust);
      expect(royalAttackActionFor(RoyalWeapon.daggers), RoyalAction.flyKick);
    });
  });

  group('RoyalMood transitions', () {
    List<RoyalReaction> capture(void Function() body) {
      final events = <RoyalReaction>[];
      void listener() {
        final e = royalReactionRequest.value;
        if (e != null) events.add(e.reaction);
      }

      royalReactionRequest.addListener(listener);
      body();
      royalReactionRequest.removeListener(listener);
      return events;
    }

    setUp(RoyalMood.reset);

    test('a session that OPENS over budget still scolds', () {
      // The bug this covers: the first snapshot used to be adopted as a silent
      // baseline, so someone who blew their budget yesterday and reopened the
      // app today never saw the attack — the false→true transition it waited
      // for had happened while the app was closed.
      final events = capture(() {
        RoyalMood.observe(
            _health(income: 100, expenses: 150, limit: 100, spent: 150));
      });
      expect(events, [RoyalReaction.scold]);
    });

    test('reopening on a breach already reacted to stays quiet', () {
      final health =
          _health(income: 100, expenses: 150, limit: 100, spent: 150);
      final signature = RoyalMood.breachSignature(health, DateTime(2026, 8, 4));
      expect(signature, isNotNull);

      // Next launch: the remembered signature is restored from storage.
      RoyalMood.reset(lastBreach: signature);
      final events = capture(() {
        RoyalMood.observe(health, now: DateTime(2026, 8, 4));
      });
      expect(events, isEmpty, reason: 'once per breach, not once per launch');
    });

    test('a new month is a new breach', () {
      final health =
          _health(income: 100, expenses: 150, limit: 100, spent: 150);
      final july = RoyalMood.breachSignature(health, DateTime(2026, 7, 20));
      RoyalMood.reset(lastBreach: july);
      final events = capture(() {
        RoyalMood.observe(health, now: DateTime(2026, 8, 4));
      });
      expect(events, [RoyalReaction.scold]);
    });

    test('going over a SECOND budget earns a fresh scold', () {
      final events = capture(() {
        // Opens with the food budget blown.
        RoyalMood.observe(
          FinancialHealth(
            income: 100,
            expenses: 150,
            budgets: const [
              BudgetUsage(limit: 100, spent: 150, label: 'Food & Dining'),
              BudgetUsage(limit: 100, spent: 40, label: 'Shopping'),
            ],
          ),
          now: DateTime(2026, 8, 4),
        );
        // Shopping goes over too — a different situation, worth saying so.
        RoyalMood.observe(
          FinancialHealth(
            income: 100,
            expenses: 260,
            budgets: const [
              BudgetUsage(limit: 100, spent: 150, label: 'Food & Dining'),
              BudgetUsage(limit: 100, spent: 110, label: 'Shopping'),
            ],
          ),
          now: DateTime(2026, 8, 4),
        );
      });
      expect(events, [RoyalReaction.scold, RoyalReaction.scold]);
    });

    test('breach signature ignores the order budgets come in', () {
      const a = BudgetUsage(limit: 10, spent: 20, label: 'Food & Dining');
      const b = BudgetUsage(limit: 10, spent: 30, label: 'Shopping');
      final when = DateTime(2026, 8, 4);
      expect(
        RoyalMood.breachSignature(
            FinancialHealth(income: 1, expenses: 1, budgets: const [a, b]),
            when),
        RoyalMood.breachSignature(
            FinancialHealth(income: 1, expenses: 1, budgets: const [b, a]),
            when),
      );
    });

    test('nothing over budget has no signature', () {
      expect(
        RoyalMood.breachSignature(
          _health(income: 100, expenses: 20, limit: 100, spent: 50),
          DateTime(2026, 8, 4),
        ),
        isNull,
      );
    });

    test('dipping back under budget re-arms the reaction', () {
      // The reported bug in full: over earlier in the month (reacted to),
      // back under, then a ₹20 charge tips it over again. The once-per-
      // signature design saw the same month + same envelope and stayed
      // silent for the rest of the month; a crossing is a crossing.
      final when = DateTime(2026, 8, 4);
      final events = capture(() {
        RoyalMood.observe(
            _health(income: 2000, expenses: 810, limit: 800, spent: 810),
            now: when);
        RoyalMood.observe(
            _health(income: 2000, expenses: 700, limit: 800, spent: 700),
            now: when);
        RoyalMood.observe(
            _health(income: 2000, expenses: 810, limit: 800, spent: 810),
            now: when);
      });
      expect(events, [RoyalReaction.scold, RoyalReaction.scold],
          reason: 'each crossing fires; the under-budget dip re-arms it');
    });

    test('a shrunken breach is tracked; re-blowing that envelope fires', () {
      final when = DateTime(2026, 8, 4);
      FinancialHealth two({required bool shoppingOver}) => FinancialHealth(
            income: 100,
            expenses: 90,
            budgets: [
              const BudgetUsage(
                  limit: 100, spent: 150, label: 'Food & Dining'),
              BudgetUsage(
                  limit: 100,
                  spent: shoppingOver ? 120 : 40,
                  label: 'Shopping'),
            ],
          );
      final events = capture(() {
        RoyalMood.observe(two(shoppingOver: true), now: when); // both over
        RoyalMood.observe(two(shoppingOver: false), now: when); // recovers
        RoyalMood.observe(two(shoppingOver: true), now: when); // blown again
      });
      // One budget recovering while the other stays blown is old news (no
      // event), but blowing it again is a fresh crossing.
      expect(events, [RoyalReaction.scold, RoyalReaction.scold]);
    });

    test('cutting the budget below what is spent counts as going over', () {
      // ₹1000 budget, ₹900 spent — fine. Drop the budget to ₹800 and the user
      // is over without spending another rupee, which is just as much a
      // breach as a charge pushing them past it.
      final events = capture(() {
        RoyalMood.observe(
          _health(income: 2000, expenses: 900, limit: 1000, spent: 900),
          now: DateTime(2026, 8, 4),
        );
        RoyalMood.observe(
          _health(income: 2000, expenses: 900, limit: 800, spent: 900),
          now: DateTime(2026, 8, 4),
        );
      });
      expect(events, contains(RoyalReaction.scold));
    });

    test('a breach never drags the user to another tab', () {
      // Being thrown onto a screen you didn't ask for reads as the app
      // malfunctioning. The reaction waits for the user to open Budgets.
      addTearDown(() => mainShellTabRequest.value = null);
      mainShellTabRequest.value = null;
      RoyalMood.observe(
        _health(income: 100, expenses: 150, limit: 100, spent: 150),
        now: DateTime(2026, 8, 4),
      );
      expect(mainShellTabRequest.value, isNull);
    });

    test('a breach is owed until it has actually been shown', () {
      RoyalMood.observe(
        _health(income: 100, expenses: 150, limit: 100, spent: 150),
        now: DateTime(2026, 8, 4),
      );
      expect(RoyalMood.breachOwed, isTrue,
          reason: 'requested is not the same as delivered');
      RoyalMood.markBreachShown();
      expect(RoyalMood.breachOwed, isFalse);
    });

    test('staying within budget owes nothing', () {
      RoyalMood.observe(
        _health(income: 100, expenses: 20, limit: 100, spent: 50),
        now: DateTime(2026, 8, 4),
      );
      expect(RoyalMood.breachOwed, isFalse);
    });

    test('a breach already reacted to is not owed again', () {
      final health =
          _health(income: 100, expenses: 150, limit: 100, spent: 150);
      final sig = RoyalMood.breachSignature(health, DateTime(2026, 8, 4));
      RoyalMood.reset(lastBreach: sig);
      RoyalMood.observe(health, now: DateTime(2026, 8, 4));
      expect(RoyalMood.breachOwed, isFalse);
    });

    test('scold fires once when newly over budget', () {
      final events = capture(() {
        RoyalMood.observe(_health(income: 100, expenses: 50, limit: 100, spent: 50));
        RoyalMood.observe(_health(income: 100, expenses: 150, limit: 100, spent: 150));
        RoyalMood.observe(_health(income: 100, expenses: 160, limit: 100, spent: 160));
      });
      // The healthy, adherent baseline legitimately opens with the launch
      // cheer; the point under test is exactly ONE scold for the transition.
      expect(events, [RoyalReaction.cheer, RoyalReaction.scold]);
    });

    test('cheer fires once when newly healthy', () {
      final events = capture(() {
        RoyalMood.observe(_health(income: 100, expenses: 95));
        RoyalMood.observe(_health(income: 100, expenses: 30));
        RoyalMood.observe(_health(income: 100, expenses: 20));
      });
      expect(events, [RoyalReaction.cheer]);
    });

    test('over budget suppresses cheer even with a healthy score', () {
      final events = capture(() {
        // Baseline is deliberately NOT healthy (95% of income spent, no
        // budgets set) so the launch cheer stays out of this scenario.
        RoyalMood.observe(_health(income: 100, expenses: 95));
        RoyalMood.observe(_health(income: 100, expenses: 30, limit: 40, spent: 90));
      });
      expect(events, [RoyalReaction.scold]);
    });

    test('a session that OPENS healthy and adherent cheers once', () {
      final events = capture(() {
        RoyalMood.observe(_health(income: 100, expenses: 20, limit: 100, spent: 50));
        RoyalMood.observe(_health(income: 100, expenses: 22, limit: 100, spent: 55));
        RoyalMood.observe(_health(income: 100, expenses: 18, limit: 100, spent: 40));
      });
      expect(events, [RoyalReaction.cheer],
          reason: 'the launch celebration fires exactly once');
    });

    test('a session that opens over budget scolds instead of cheering', () {
      final events = capture(() {
        RoyalMood.observe(
            _health(income: 100, expenses: 20, limit: 40, spent: 90));
      });
      expect(events, [RoyalReaction.scold],
          reason: 'a blown budget is never a celebration');
    });
  });

  group('RoyalCharacterView', () {
    testWidgets('renders every royal × action without error', (tester) async {
      for (final royal in kRoyalAvatars) {
        for (final action in RoyalAction.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: RoyalCharacterView(
                    key: ValueKey('${royal.id}-$action'),
                    royal: royal,
                    action: action,
                    facing: action == RoyalAction.walk ? -1 : 1,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 120));
          }
          expect(tester.takeException(), isNull, reason: '${royal.id} · $action');
        }
      }
    });

    test('every royal has a signature move, and no two share one', () {
      const expected = {
        'empress': RoyalAction.spell,
        'princess': RoyalAction.kiss,
        'darkprince': RoyalAction.menace,
        'sovereign': RoyalAction.roar,
        'royalmedic': RoyalAction.mend,
        'prince': RoyalAction.salute,
        'sentinel': RoyalAction.brace,
        'huntress': RoyalAction.daggerToss,
      };
      for (final r in kRoyalAvatars) {
        expect(expected.containsKey(r.id), isTrue,
            reason: '${r.id} has no signature declared');
      }
      final signatures = expected.values.toList();
      expect(signatures.toSet().length, signatures.length,
          reason: 'a signature is only a signature if it is unique');
      // The generic wave is the fallback for royals added later, so no
      // shipped royal should be resolving to it.
      expect(signatures, isNot(contains(RoyalAction.wave)));
    });

    test('the full-body head drops the sprite weapon lane, and only that', () {
      for (final r in kRoyalAvatars) {
        expect(r.headRows.length, r.rows.length, reason: r.id);
        for (var i = 0; i < r.rows.length; i++) {
          final base = r.rows[i], head = r.headRows[i];
          expect(head.length, base.length, reason: r.id);
          // Everything past the lane is untouched…
          expect(head.substring(r.weaponCols), base.substring(r.weaponCols),
              reason: '${r.id} row $i');
          // …and the lane itself is empty.
          expect(head.substring(0, r.weaponCols),
              '.' * r.weaponCols, reason: '${r.id} row $i');
        }
      }
      // The two brothers carry theirs in the art; nobody else has a lane, so
      // blanking one would eat their head outline (which starts at column 2).
      final laned = {
        for (final r in kRoyalAvatars)
          if (r.weaponCols > 0) r.id: r.weaponCols
      };
      expect(laned, {'prince': 4, 'darkprince': 4});
    });
  });

  group('RoyalReactionHost', () {
    setUp(() {
      RoyalReactionHost.debugReset();
      RoyalOverlayRouteObserver.instance.debugReset();
      // RoyalMood's breach state is static and persisted; without this, an
      // owed attack left behind by the transition tests above would be
      // delivered the moment a host mounts on the Budgets tab.
      RoyalMood.reset();
      mainShellTabIndex.value = 0;
    });

    testWidgets(
        'the launch parade crosses the screen whichever way it sets off',
        (tester) async {
      // The regression this pins: the parade's far point used to be an
      // absolute screen fraction rather than a distance from the start. The
      // Home profile anchor sits in the TOP-RIGHT corner, so a rightward
      // launch put the "far" point inboard of the start and the royal
      // shuffled ~28px and came back — which is what "stuck in the corner"
      // looked like, on roughly half of all launches.
      //
      // Direction is sampled per launch, so this runs the entrance enough
      // times to hit both.
      final princess = kRoyalAvatars.firstWhere((r) => r.id == 'princess');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${princess.spriteIndex}',
          },
          'unlockedRoyals': ['princess'],
        }),
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize();

      double? characterX() {
        final finder = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is RoyalCharacterPainter);
        if (finder.evaluate().isEmpty) return null;
        // The real body is painted last, after any speed afterimages.
        return tester.getCenter(finder.last).dx;
      }

      final screenW = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      for (var run = 0; run < 8; run++) {
        // Tear the host down between runs: pumping the same widget type keeps
        // the existing State alive, so initState never re-runs and the second
        // parade would simply never start.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        RoyalReactionHost.debugReset();
        await tester.pumpWidget(_host(prefs));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        var lo = double.infinity, hi = double.negativeInfinity;
        for (var i = 0; i < 44; i++) {
          await tester.pump(const Duration(milliseconds: 130));
          final x = characterX();
          if (x == null) continue;
          lo = math.min(lo, x);
          hi = math.max(hi, x);
        }
        expect(hi - lo, greaterThan(screenW * 0.30),
            reason: 'run $run: the parade barely moved (${hi - lo}px of '
                '${screenW}px) — it is stuck near its anchor again');

        // Leave nothing running for the next iteration.
        await tester.pump(const Duration(seconds: 7));
        await tester.pump();
      }
    });

    // A host that registers the popup observer (as the real MaterialApp does)
    // and hands back its navigator, so a test can push a modal over the app.
    Widget observedHost(AppPreferences prefs, GlobalKey<NavigatorState> navKey) =>
        ChangeNotifierProvider<AppPreferences>.value(
          value: prefs,
          child: MaterialApp(
            navigatorKey: navKey,
            navigatorObservers: [RoyalOverlayRouteObserver.instance],
            home: RoyalReactionHost(
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topRight,
                  child:
                      SizedBox(key: royalHomeAnchorKey, width: 38, height: 38),
                ),
              ),
            ),
          ),
        );

    testWidgets('a modal popup bows the court out and blocks new flourishes',
        (tester) async {
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize();

      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(observedHost(prefs, navKey));
      // Let the welcome parade play out fully so we start from a clean slate.
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(_hasCharacter(tester), isFalse, reason: 'boot finished');

      // A flourish is on screen…
      requestRoyalCameo(RoyalCameo.stroll);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hasCharacter(tester), isTrue);

      // …then the user opens a dialog (a PopupRoute). The court must vanish.
      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const SizedBox.shrink(),
      );
      await tester.pump(); // route pushed → observer fires
      await tester.pump(); // host rebuilds after cancel
      expect(RoyalOverlayRouteObserver.instance.popupOpen.value, isTrue);
      expect(_hasCharacter(tester), isFalse,
          reason: 'the overlay must not paint over a modal popup');
      expect(royalCharacterOut.value, isFalse);

      // A reaction requested while the popup is up must NOT start over it.
      requestRoyalReaction(RoyalReaction.scold);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hasCharacter(tester), isFalse,
          reason: 'nothing starts on top of a popup');

      // Closing the popup leaves everything clean.
      navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(RoyalOverlayRouteObserver.instance.popupOpen.value, isFalse);
      expect(_hasCharacter(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an equipped royal emerges with the welcome routine',
        (tester) async {
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        // The full-body theatrics are opt-in — enable them for these tests.
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize(); // Gamified Budgets defaults on.

      await tester.pumpWidget(_host(prefs));
      // Let the host load the royal and fire the one-time welcome routine
      // (which waits for the profile-icon anchor to be on screen).
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      expect(royalCharacterOut.value, isTrue);
      expect(_hasCharacter(tester), isTrue);
    });

    testWidgets('a reaction during the boot parade queues and plays after it',
        (tester) async {
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        // The full-body theatrics are opt-in — enable them for these tests.
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize();

      await tester.pumpWidget(_host(prefs));
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(royalCharacterOut.value, isTrue, reason: 'boot is playing');

      // The launch cheer lands mid-parade — it must wait, not vanish.
      requestRoyalReaction(RoyalReaction.cheer);
      await tester.pump(const Duration(seconds: 6)); // boot (5.6s) finishes
      await tester.pump(const Duration(milliseconds: 400)); // inter-beat
      await tester.pump(const Duration(milliseconds: 600)); // praise underway

      expect(_hasCharacter(tester), isTrue,
          reason: 'the queued praise routine should be playing');
      expect(_characterPainter(tester)!.action, RoyalAction.cheer);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(_hasCharacter(tester), isFalse);
    });

    testWidgets('every cameo plays after boot without vacating the icon',
        (tester) async {
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        // The full-body theatrics are opt-in — enable them for these tests.
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize();

      await tester.pumpWidget(_host(prefs));
      // Let the welcome routine start and play out fully (5.6s).
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(royalCharacterOut.value, isFalse);
      expect(_hasCharacter(tester), isFalse);

      for (final cameo in RoyalCameo.values) {
        requestRoyalCameo(cameo);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(_hasCharacter(tester), isTrue, reason: '$cameo should be on');
        // Cameos wander in from off-screen; the Home icon keeps its avatar.
        expect(royalCharacterOut.value, isFalse, reason: '$cameo');
        if (cameo == RoyalCameo.dash) {
          expect(_characterPainter(tester)!.action, RoyalAction.ride,
              reason: 'the dash cameo arrives on the royal ride');
        }
        // Play it out; the overlay must clean up after itself.
        await tester.pump(const Duration(seconds: 7));
        await tester.pump();
        expect(_hasCharacter(tester), isFalse, reason: '$cameo should end');
        expect(tester.takeException(), isNull, reason: '$cameo');
      }
    });

    testWidgets('every royal plays every cameo in its own manner',
        (tester) async {
      // The cameo routines branch per _Manner now: the Empress never stops or
      // waves and has no walk cycle, the Sovereign travels in stepped bursts,
      // the Dark Prince stalks and does not greet. Those branches are only
      // reachable with that royal equipped, so the existing single-royal sweep
      // above would not touch most of them.
      for (final royal in kRoyalAvatars) {
        SharedPreferences.setMockInitialValues({
          'gamification_v1': jsonEncode({
            'profile': {
              'avatarKind': 'pixel',
              'avatarValue': '${royal.spriteIndex}',
            },
            'unlockedRoyals': [royal.id],
          }),
          'royal_custom_animations': true,
        });
        final prefs = AppPreferences();
        await prefs.initialize();

        await tester.pumpWidget(_host(prefs));
        // Let the welcome parade finish so cameos are allowed to start.
        for (var i = 0; i < 14; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();

        for (final cameo in RoyalCameo.values) {
          requestRoyalCameo(cameo);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(_hasCharacter(tester), isTrue,
              reason: '${royal.id} / $cameo never started');

          // Sample across the routine rather than at one instant: the manner
          // branches live at different points in the timeline (entry easing,
          // the mid-beat, the exit), so a single frame would miss most of them.
          // Deliberately no "cleaned up" assertion at the end — the host's own
          // ambient scheduler is free to start another cameo inside a window
          // this long, so a character being on screen afterwards proves
          // nothing. Teardown is covered by the single-royal sweep above.
          for (var i = 0; i < 13; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull,
                reason: '${royal.id} / $cameo threw mid-routine');
          }
        }
      }
    });

    testWidgets('a non-royal avatar stays silent', (tester) async {
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {'avatarKind': 'pixel', 'avatarValue': '0'},
        }),
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize();

      await tester.pumpWidget(_host(prefs));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      requestRoyalReaction(RoyalReaction.scold);
      requestRoyalCameo(RoyalCameo.stroll);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(royalCharacterOut.value, isFalse);
      expect(_hasCharacter(tester), isFalse);
    });

    testWidgets(
        'custom animations OFF: no parade, reaction or cameo — court dormant',
        (tester) async {
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        // Custom animations left OFF (also the real default).
      });
      final prefs = AppPreferences();
      await prefs.initialize();
      expect(prefs.royalCustomAnimations, isFalse);

      await tester.pumpWidget(_host(prefs));
      // Give the welcome parade every chance to (not) fire.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(royalCharacterOut.value, isFalse, reason: 'no welcome parade');
      expect(_hasCharacter(tester), isFalse);

      // Neither a decorative reaction nor a cameo may summon the character.
      // (The over-budget smash is exempt — it's feedback, covered below.)
      requestRoyalReaction(RoyalReaction.cheer);
      requestRoyalCameo(RoyalCameo.stroll);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hasCharacter(tester), isFalse, reason: 'court stays dormant');
      expect(royalCharacterOut.value, isFalse);

      // Turning it on mid-session wakes the court: the parade now plays.
      await prefs.setRoyalCustomAnimations(true);
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(_hasCharacter(tester), isTrue,
          reason: 'enabling custom animations starts the entrance');
    });

    testWidgets('the over-budget smash plays even with custom animations OFF',
        (tester) async {
      // The toggle governs decoration (parade, cameos, cheers). The smash is
      // feedback about the user's money and defaulted to invisible behind an
      // opt-in nobody finds — the root of "the animation never shows".
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        // Custom animations left OFF (the real default).
      });
      final prefs = AppPreferences();
      await prefs.initialize();
      expect(prefs.royalCustomAnimations, isFalse);
      addTearDown(() => mainShellTabIndex.value = 0);

      await tester.pumpWidget(_budgetHost(prefs));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(_hasCharacter(tester), isFalse, reason: 'no parade either way');

      requestRoyalReaction(RoyalReaction.scold);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700)); // mid-slash
      expect(_characterPainter(tester)?.action, RoyalAction.slash,
          reason: 'feedback plays without the opt-in');
      expect(_hasShatter(tester), isTrue);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_hasCharacter(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the budget smash vibrates at impact', (tester) async {
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize();

      // Capture platform haptic calls.
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add((call.arguments as String?) ?? 'default');
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      addTearDown(() => mainShellTabIndex.value = 0);

      await tester.pumpWidget(_budgetHost(prefs));
      // Let the welcome parade run and fully finish first.
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(_hasCharacter(tester), isFalse, reason: 'boot finished');
      haptics.clear();

      // Blow a budget → the Sovereign storms out and slashes the screen.
      // His first cut lands at 0.272 of the 5.2s routine (~1414ms).
      requestRoyalReaction(RoyalReaction.scold);
      await tester.pump(); // routine starts
      await tester.pump(const Duration(milliseconds: 1700));
      expect(_characterPainter(tester)?.action, RoyalAction.slash);
      expect(_hasShatter(tester), isTrue,
          reason: 'the first cut has landed — damage should be on screen');
      await tester.pump(const Duration(milliseconds: 300));

      expect(haptics, isNotEmpty, reason: 'the slash should vibrate');
      expect(haptics.any((h) => h.contains('heavyImpact')), isTrue);

      // Let the routine end so the overlay tears down cleanly. The tail pump
      // services the trailing haptic-sequence timers (60-80ms) so none are
      // pending at test teardown.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_hasShatter(tester), isFalse, reason: 'damage healed off screen');
      expect(tester.takeException(), isNull);
    });

    testWidgets('every royal fights with its own verb and leaves damage',
        (tester) async {
      addTearDown(() => mainShellTabIndex.value = 0);
      // (royal id, expected mid-attack action, when to look, routine length).
      const cases = [
        ('princess', RoyalAction.shoot, 1700, 5400), // volley in progress
        ('empress', RoyalAction.hurl, 1950, 5400), // first orb burst
        ('prince', RoyalAction.slice, 1850, 4800), // driving the lance
        ('darkprince', RoyalAction.smash, 2050, 5000), // club crater
      ];
      for (final (id, action, checkMs, totalMs) in cases) {
        // Unmount the previous host first — pumping an identical tree would
        // REUSE the State (no initState), leaving the old royal loaded and
        // the boot flag stranded.
        await tester.pumpWidget(const SizedBox());
        RoyalReactionHost.debugReset();
        final royal = kRoyalAvatars.firstWhere((r) => r.id == id);
        SharedPreferences.setMockInitialValues({
          'gamification_v1': jsonEncode({
            'profile': {
              'avatarKind': 'pixel',
              'avatarValue': '${royal.spriteIndex}',
            },
            'unlockedRoyals': [id],
          }),
          'royal_custom_animations': true,
        });
        final prefs = AppPreferences();
        await prefs.initialize();

        await tester.pumpWidget(_budgetHost(prefs));
        for (var i = 0; i < 14; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.pump(const Duration(seconds: 6)); // boot finishes
        await tester.pump();

        requestRoyalReaction(RoyalReaction.scold);
        await tester.pump();
        await tester.pump(Duration(milliseconds: checkMs));
        expect(_characterPainter(tester)?.action, action, reason: id);
        expect(_hasShatter(tester), isTrue,
            reason: '$id: first blow has landed');

        // Play out, then a tail pump so trailing haptic timers resolve.
        await tester.pump(Duration(milliseconds: totalMs));
        await tester.pump(const Duration(milliseconds: 250));
        expect(_hasCharacter(tester), isFalse, reason: '$id: routine over');
        expect(tester.takeException(), isNull, reason: id);
      }
    });

    testWidgets('on the Budgets tab the scold lands on the budget gauge',
        (tester) async {
      // mainShellTabIndex is app-global — always restore it for later tests.
      addTearDown(() => mainShellTabIndex.value = 0);
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppPreferences>.value(
          value: prefs,
          child: MaterialApp(
            home: RoyalReactionHost(
              child: Scaffold(
                body: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: SizedBox(
                          key: royalHomeAnchorKey, width: 38, height: 38),
                    ),
                    // Stand-in for the monthly budget gauge, mid-screen.
                    Center(
                      child: SizedBox(
                          key: royalBudgetChartAnchorKey,
                          width: 160,
                          height: 160),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      // Boot on Home, play the parade out fully.
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      // The user is now on the Budgets tab with the gauge on screen —
      // blowing the budget must send the Sovereign onto the ring itself.
      mainShellTabIndex.value = 1;
      requestRoyalReaction(RoyalReaction.scold);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700)); // mid-slash

      final gauge = tester.getCenter(find.byKey(royalBudgetChartAnchorKey));
      final charFinder = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RoyalCharacterPainter);
      expect(charFinder, findsOneWidget);
      final royalC = tester.getCenter(charFinder);
      expect((royalC - gauge).distance, lessThan(120),
          reason: 'the royal fights ON the gauge, not down at the lane');
      expect(_hasShatter(tester), isTrue,
          reason: 'the cut landed on the chart');

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_hasCharacter(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a scold raised off the Budgets tab waits for the gauge',
        (tester) async {
      // The reported bug in full: the user reopens the app already over
      // budget, lands on Home, and walks to Budgets. The scold is raised on
      // Home — where there is no gauge — and must still end up attacking the
      // ring rather than firing into a corner of the home screen.
      addTearDown(() => mainShellTabIndex.value = 0);
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize();

      // The gauge only exists once the user is on Budgets, exactly as the
      // real shell behaves (the progress card renders for that tab).
      late StateSetter setTab;
      var onBudgets = false;
      await tester.pumpWidget(
        ChangeNotifierProvider<AppPreferences>.value(
          value: prefs,
          child: MaterialApp(
            home: RoyalReactionHost(
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (ctx, setState) {
                    setTab = setState;
                    return Stack(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: SizedBox(
                              key: royalHomeAnchorKey, width: 38, height: 38),
                        ),
                        if (onBudgets)
                          Center(
                            child: SizedBox(
                                key: royalBudgetChartAnchorKey,
                                width: 160,
                                height: 160),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(_hasCharacter(tester), isFalse, reason: 'boot finished');

      // Over budget, discovered on Home — through the real path, so the debt
      // is recorded exactly as it is in the app. Nothing should fire yet.
      RoyalMood.observe(
        _health(income: 2000, expenses: 900, limit: 800, spent: 900),
        now: DateTime(2026, 8, 4),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(_hasCharacter(tester), isFalse,
          reason: 'the attack is holding out for the gauge');

      // The user walks over to Budgets.
      setTab(() => onBudgets = true);
      mainShellTabIndex.value = 1;
      await tester.pump(); // gauge lays out
      // The watch ticks, and the routine's ticker only starts on the frame
      // after that — so give it one before measuring where the royal is.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 1700)); // mid-slash

      final gauge = tester.getCenter(find.byKey(royalBudgetChartAnchorKey));
      final charFinder = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RoyalCharacterPainter);
      expect(charFinder, findsOneWidget,
          reason: 'landing on Budgets releases the parked scold');
      expect((tester.getCenter(charFinder) - gauge).distance, lessThan(120),
          reason: 'and it lands on the ring it was waiting for');

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a scold never fires into a screen that is not Budgets',
        (tester) async {
      // The user stays on Home. The attack must NOT go off there — it is
      // about the budget gauge, and firing it into an unrelated screen (or
      // dragging the user to Budgets to show it) reads as a malfunction.
      // It waits; the debt is persisted.
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize();
      addTearDown(() => mainShellTabRequest.value = null);
      mainShellTabIndex.value = 0;
      mainShellTabRequest.value = null;

      await tester.pumpWidget(_host(prefs));
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      requestRoyalReaction(RoyalReaction.scold);
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(milliseconds: 1700));
      expect(_hasCharacter(tester), isFalse,
          reason: 'it waits for Budgets rather than firing into Home');
      expect(mainShellTabRequest.value, isNull,
          reason: 'and it does not drag the user there either');
      expect(tester.takeException(), isNull);
    });

    testWidgets('an attack owed from a previous launch plays on arrival',
        (tester) async {
      // Cold start with a breach already owed: nothing happens until the
      // user opens Budgets of their own accord, and then it plays.
      addTearDown(() => mainShellTabIndex.value = 0);
      final sovereign = kRoyalAvatars.firstWhere((r) => r.id == 'sovereign');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {
            'avatarKind': 'pixel',
            'avatarValue': '${sovereign.spriteIndex}',
          },
          'unlockedRoyals': ['sovereign'],
        }),
        'royal_custom_animations': true,
      });
      final prefs = AppPreferences();
      await prefs.initialize();
      // The debt survived the app being closed.
      RoyalMood.reset(breachOwed: true);
      expect(RoyalMood.breachOwed, isTrue);

      late StateSetter setTab;
      var onBudgets = false;
      mainShellTabIndex.value = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider<AppPreferences>.value(
          value: prefs,
          child: MaterialApp(
            home: RoyalReactionHost(
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (ctx, setState) {
                    setTab = setState;
                    return Stack(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: SizedBox(
                              key: royalHomeAnchorKey, width: 38, height: 38),
                        ),
                        if (onBudgets)
                          Center(
                            child: SizedBox(
                                key: royalBudgetChartAnchorKey,
                                width: 160,
                                height: 160),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(seconds: 6)); // parade plays out
      await tester.pump();
      expect(_hasCharacter(tester), isFalse,
          reason: 'no reaction was requested this launch');

      // The user opens Budgets themselves.
      setTab(() => onBudgets = true);
      mainShellTabIndex.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // watch ticks
      await tester.pump(const Duration(milliseconds: 1700)); // mid-slash

      final charFinder = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RoyalCharacterPainter);
      expect(charFinder, findsOneWidget,
          reason: 'the owed attack is delivered on arrival');
      final gauge = tester.getCenter(find.byKey(royalBudgetChartAnchorKey));
      expect((tester.getCenter(charFinder) - gauge).distance, lessThan(120),
          reason: 'and lands on the ring');
      expect(RoyalMood.breachOwed, isFalse, reason: 'debt settled on play');

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    });
  });
}
