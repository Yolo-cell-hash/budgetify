import 'dart:convert';

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

void main() {
  group('Royal weapons', () {
    test('each royal wields its signature weapon', () {
      const expected = {
        'sovereign': RoyalWeapon.sword,
        'empress': RoyalWeapon.orbs,
        'prince': RoyalWeapon.lance,
        'darkprince': RoyalWeapon.warClub,
        'princess': RoyalWeapon.bow,
        'royalmedic': RoyalWeapon.medKit,
      };
      for (final r in kRoyalAvatars) {
        expect(r.weapon, expected[r.id], reason: r.id);
      }
      expect(kRoyalAvatars.map((r) => r.weapon).toSet().length,
          RoyalWeapon.values.length);
    });

    test('each weapon speaks its own attack verb', () {
      expect(royalAttackActionFor(RoyalWeapon.sword), RoyalAction.slash);
      expect(royalAttackActionFor(RoyalWeapon.lance), RoyalAction.slice);
      expect(royalAttackActionFor(RoyalWeapon.bow), RoyalAction.shoot);
      expect(royalAttackActionFor(RoyalWeapon.orbs), RoyalAction.hurl);
      expect(royalAttackActionFor(RoyalWeapon.warClub), RoyalAction.smash);
      expect(royalAttackActionFor(RoyalWeapon.medKit), RoyalAction.smash);
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

    test('first snapshot sets a silent baseline', () {
      final events = capture(() {
        RoyalMood.observe(_health(income: 100, expenses: 150, limit: 100, spent: 150));
      });
      expect(events, isEmpty);
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

    test('a session that opens over budget does NOT launch-cheer', () {
      final events = capture(() {
        RoyalMood.observe(_health(income: 100, expenses: 20, limit: 40, spent: 90));
      });
      expect(events, isEmpty);
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
  });

  group('RoyalReactionHost', () {
    setUp(() {
      RoyalReactionHost.debugReset();
      RoyalOverlayRouteObserver.instance.debugReset();
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

      // Neither a reaction nor a cameo may summon the full-body character.
      requestRoyalReaction(RoyalReaction.scold);
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

      await tester.pumpWidget(_host(prefs));
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

        await tester.pumpWidget(_host(prefs));
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
  });
}
