import 'dart:convert';

import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/services/app_events.dart';
import 'package:budget_tracker/services/financial_health_service.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/royal_character.dart';
import 'package:budget_tracker/widgets/royal_reactions.dart';
import 'package:flutter/material.dart';
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
        'sovereign': RoyalWeapon.staff,
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
      expect(events, [RoyalReaction.scold]);
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
        RoyalMood.observe(_health(income: 100, expenses: 30, limit: 100, spent: 50));
        RoyalMood.observe(_health(income: 100, expenses: 30, limit: 40, spent: 90));
      });
      expect(events, [RoyalReaction.scold]);
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
    setUp(RoyalReactionHost.debugReset);

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

    testWidgets('a non-royal avatar stays silent', (tester) async {
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {'avatarKind': 'pixel', 'avatarValue': '0'},
        }),
      });
      final prefs = AppPreferences();
      await prefs.initialize();

      await tester.pumpWidget(_host(prefs));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      requestRoyalReaction(RoyalReaction.scold);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(royalCharacterOut.value, isFalse);
      expect(_hasCharacter(tester), isFalse);
    });
  });
}
