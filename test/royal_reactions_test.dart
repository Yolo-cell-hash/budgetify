import 'dart:convert';

import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/services/app_events.dart';
import 'package:budget_tracker/services/financial_health_service.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
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
      // Every weapon in the enum is claimed by exactly one royal.
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
        // Baseline: within budget.
        RoyalMood.observe(_health(income: 100, expenses: 50, limit: 100, spent: 50));
        // Cross over the cap → scold.
        RoyalMood.observe(_health(income: 100, expenses: 150, limit: 100, spent: 150));
        // Still over → no repeat.
        RoyalMood.observe(_health(income: 100, expenses: 160, limit: 100, spent: 160));
      });
      expect(events, [RoyalReaction.scold]);
    });

    test('cheer fires once when newly healthy', () {
      final events = capture(() {
        // Baseline: weak savings, no budgets → not healthy, not over budget.
        RoyalMood.observe(_health(income: 100, expenses: 95));
        // Strong savings → excellent band → cheer.
        RoyalMood.observe(_health(income: 100, expenses: 30));
        // Still healthy → no repeat.
        RoyalMood.observe(_health(income: 100, expenses: 20));
      });
      expect(events, [RoyalReaction.cheer]);
    });

    test('over budget suppresses cheer even with a healthy score', () {
      final events = capture(() {
        RoyalMood.observe(_health(income: 100, expenses: 30, limit: 100, spent: 50));
        // Great savings but a category blown → scold, never cheer.
        RoyalMood.observe(_health(income: 100, expenses: 30, limit: 40, spent: 90));
      });
      expect(events, [RoyalReaction.scold]);
    });
  });

  group('RoyalReactionView', () {
    testWidgets('renders every royal × reaction and completes without error',
        (tester) async {
      for (final royal in kRoyalAvatars) {
        for (final reaction in RoyalReaction.values) {
          var done = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: RoyalReactionView(
                    key: ValueKey('${royal.id}-$reaction'),
                    royal: royal,
                    reaction: reaction,
                    size: 116,
                    onDone: () => done = true,
                  ),
                ),
              ),
            ),
          );
          // Drive the full ~1.35s one-shot animation to completion.
          await tester.pump();
          for (var i = 0; i < 11; i++) {
            await tester.pump(const Duration(milliseconds: 160));
          }
          expect(tester.takeException(), isNull,
              reason: '${royal.id} · $reaction');
          expect(done, isTrue, reason: '${royal.id} · $reaction onDone');
        }
      }
    });
  });

  group('RoyalReactionHost', () {
    testWidgets('plays a reaction for an equipped royal when gamified is on',
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

      await tester.pumpWidget(
        ChangeNotifierProvider<AppPreferences>.value(
          value: prefs,
          child: const MaterialApp(
            home: RoyalReactionHost(child: Scaffold(body: SizedBox())),
          ),
        ),
      );
      // Let the host load the equipped royal.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byType(RoyalReactionView), findsNothing);
      requestRoyalReaction(RoyalReaction.strike);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(RoyalReactionView), findsOneWidget);
    });

    testWidgets('stays silent for a non-royal avatar', (tester) async {
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {'avatarKind': 'pixel', 'avatarValue': '0'},
        }),
      });
      final prefs = AppPreferences();
      await prefs.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppPreferences>.value(
          value: prefs,
          child: const MaterialApp(
            home: RoyalReactionHost(child: Scaffold(body: SizedBox())),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      requestRoyalReaction(RoyalReaction.strike);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(RoyalReactionView), findsNothing);
    });
  });
}
