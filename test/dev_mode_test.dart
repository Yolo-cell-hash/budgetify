import 'dart:convert';

import 'package:budget_tracker/models/plus_products.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/dev_mode.dart';
import 'package:budget_tracker/services/entitlement_service.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    DevMode.debugReset();
    SharedPreferences.setMockInitialValues({});
  });

  group('DevMode service', () {
    test('unlocks only with the exact password', () {
      expect(DevMode.tryUnlock('budgetify'), isFalse);
      expect(DevMode.isActive, isFalse);
      expect(DevMode.tryUnlock('budgetify.dev '), isTrue); // trimmed
      expect(DevMode.isActive, isTrue);
    });

    test('the on/off flag persists and is restored by initialize', () async {
      // A fresh install starts off.
      await DevMode.initialize();
      expect(DevMode.isActive, isFalse);

      // Unlocking writes the flag through to storage.
      DevMode.tryUnlock('budgetify.dev');
      // Let the fire-and-forget persist settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dev_mode_active'), isTrue);

      // Simulate a relaunch: in-memory flag cleared, restored from storage.
      DevMode.active.value = false;
      await DevMode.initialize();
      expect(DevMode.isActive, isTrue,
          reason: 'dev mode stays on across restarts');
    });

    test('disable clears the flag so the next launch starts off', () async {
      SharedPreferences.setMockInitialValues({'dev_mode_active': true});
      await DevMode.initialize();
      expect(DevMode.isActive, isTrue);

      final tp = ThemeProvider();
      await tp.initialize();
      await DevMode.disable(tp);
      expect(DevMode.isActive, isFalse);

      DevMode.active.value = true; // pretend something set it
      await DevMode.initialize(); // relaunch reads storage
      expect(DevMode.isActive, isFalse,
          reason: 'disable persisted the off state');
    });

    test('session avatar override rides on top of the persisted profile',
        () async {
      final empress = kRoyalAvatars.firstWhere((r) => r.id == 'empress');
      SharedPreferences.setMockInitialValues({
        'gamification_v1': jsonEncode({
          'profile': {'avatarKind': 'pixel', 'avatarValue': '3'},
        }),
      });
      final svc = GamificationService();

      GamificationService.sessionAvatarOverride = '${empress.spriteIndex}';
      final overridden = await svc.loadProfile();
      expect(overridden.avatarValue, '${empress.spriteIndex}');

      // Clearing the override lands back on the persisted (prod) avatar —
      // nothing royal was ever written to storage.
      GamificationService.sessionAvatarOverride = null;
      final restored = await svc.loadProfile();
      expect(restored.avatarValue, '3');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('gamification_v1'),
          isNot(contains('${empress.spriteIndex}')));
    });

    test('applyDevRoyalPreview: preview only for unearned royals in dev mode',
        () async {
      final prince = kRoyalAvatars.firstWhere((r) => r.id == 'prince');
      final profile =
          const GamiProfile().copyWith(avatarKind: 'pixel', avatarValue: '20');

      // Dev mode off → never a preview.
      expect(await applyDevRoyalPreview(profile, const {}), isFalse);
      expect(GamificationService.sessionAvatarOverride, isNull);

      DevMode.tryUnlock('budgetify.dev');
      // Unearned royal → session preview, persisted as the dev overlay.
      expect(await applyDevRoyalPreview(profile, const {}), isTrue);
      expect(GamificationService.sessionAvatarOverride, '20');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dev_mode_avatar'), '20');

      // Actually-earned royal → real save path, overlay dropped.
      expect(await applyDevRoyalPreview(profile, {prince.id}), isFalse);
      expect(GamificationService.sessionAvatarOverride, isNull);
      expect(prefs.getString('dev_mode_avatar'), isNull);
    });

    test('the preview overlay (avatar + theme) is restored on the next launch',
        () async {
      final empress = kRoyalAvatars.firstWhere((r) => r.id == 'empress');
      SharedPreferences.setMockInitialValues({
        'theme_variant': AppThemeVariant.light.name, // the real, earned theme
      });
      DevMode.tryUnlock('budgetify.dev');

      final tp = ThemeProvider();
      await tp.initialize();

      // Preview an unearned theme + royal; both persist to the dev overlay.
      await DevMode.previewTheme(tp, AppThemeVariant.royalIndigo);
      await applyDevRoyalPreview(
        const GamiProfile()
            .copyWith(avatarKind: 'pixel', avatarValue: '${empress.spriteIndex}'),
        const {},
      );

      // Simulate a relaunch: fresh in-memory state, read back from storage.
      DevMode.active.value = false;
      GamificationService.sessionAvatarOverride = null;
      final tp2 = ThemeProvider();
      await tp2.initialize();
      expect(tp2.variant, AppThemeVariant.light, reason: 'real theme first');

      await DevMode.initialize(tp2);
      expect(DevMode.isActive, isTrue);
      expect(tp2.variant, AppThemeVariant.royalIndigo,
          reason: 'previewed theme overlay restored');
      expect(GamificationService.sessionAvatarOverride,
          '${empress.spriteIndex}',
          reason: 'previewed royal overlay restored');

      // The real, earned theme was never overwritten.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_variant'), AppThemeVariant.light.name);
    });

    test('disable drops the persisted overlay and restores the earned state',
        () async {
      final empress = kRoyalAvatars.firstWhere((r) => r.id == 'empress');
      SharedPreferences.setMockInitialValues({
        'theme_variant': AppThemeVariant.dark.name,
      });
      DevMode.tryUnlock('budgetify.dev');

      final tp = ThemeProvider();
      await tp.initialize();
      await DevMode.previewTheme(tp, AppThemeVariant.royalIndigo);
      await applyDevRoyalPreview(
        const GamiProfile()
            .copyWith(avatarKind: 'pixel', avatarValue: '${empress.spriteIndex}'),
        const {},
      );

      await DevMode.disable(tp);
      expect(DevMode.isActive, isFalse);
      expect(tp.variant, AppThemeVariant.dark, reason: 'earned theme restored');
      expect(GamificationService.sessionAvatarOverride, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dev_mode_theme'), isNull);
      expect(prefs.getString('dev_mode_avatar'), isNull);

      // A relaunch after disabling starts clean: no dev overlay reapplied.
      final tp2 = ThemeProvider();
      await tp2.initialize();
      await DevMode.initialize(tp2);
      expect(tp2.variant, AppThemeVariant.dark);
      expect(GamificationService.sessionAvatarOverride, isNull);
    });
  });

  group('simulated trial expiry', () {
    test('toggling flips every Plus gate, without touching the real anchor',
        () async {
      final ent = EntitlementService();
      ent.resetForTest();
      await ent.initialize(); // fresh install: trial just started
      final anchor = ent.firstLaunchAt;
      expect(ent.hasFullAccess, isTrue);

      DevMode.tryUnlock('budgetify.dev');
      await DevMode.setSimulateTrialExpired(true);
      expect(ent.trialActive, isFalse);
      expect(ent.trialDaysLeft, 0);
      expect(ent.hasFullAccess, isFalse);
      for (final f in PlusFeature.values) {
        expect(ent.allows(f), isFalse, reason: f.name);
      }

      await DevMode.setSimulateTrialExpired(false);
      expect(ent.hasFullAccess, isTrue, reason: 'instantly reversible');
      expect(ent.firstLaunchAt, anchor,
          reason: 'the real trial anchor is never touched');
    });

    test('a simulated expiry still honours Plus ownership', () async {
      final ent = EntitlementService();
      ent.resetForTest();
      await ent.initialize();
      await ent.registerPlusPurchase('plus_lifetime');

      DevMode.tryUnlock('budgetify.dev');
      await DevMode.setSimulateTrialExpired(true);
      expect(ent.trialActive, isFalse);
      expect(ent.hasFullAccess, isTrue,
          reason: 'simulation expires the TRIAL, not a purchase — '
              'exactly like day 183 for a paying user');
    });

    test('the overlay survives a relaunch while dev mode stays on', () async {
      DevMode.tryUnlock('budgetify.dev');
      await DevMode.setSimulateTrialExpired(true);

      // Simulate a relaunch.
      DevMode.debugReset();
      expect(EntitlementService.debugSimulateTrialExpired, isFalse);
      await DevMode.initialize();

      expect(DevMode.isActive, isTrue);
      expect(DevMode.simulateTrialExpired.value, isTrue);
      expect(EntitlementService.debugSimulateTrialExpired, isTrue);
    });

    test('disable clears the simulation now and for the next launch',
        () async {
      DevMode.tryUnlock('budgetify.dev');
      await DevMode.setSimulateTrialExpired(true);

      final tp = ThemeProvider();
      await tp.initialize();
      await DevMode.disable(tp);
      expect(DevMode.simulateTrialExpired.value, isFalse);
      expect(EntitlementService.debugSimulateTrialExpired, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dev_mode_trial_expired'), isNull);

      // Relaunch: nothing comes back.
      await DevMode.initialize();
      expect(EntitlementService.debugSimulateTrialExpired, isFalse);
    });

    test('a stale overlay key is ignored while dev mode is off', () async {
      // Defensive: the key should never exist with dev mode off, but if it
      // does (manual prefs edit, crash mid-disable), it must not leak into
      // a prod-looking session.
      SharedPreferences.setMockInitialValues({
        'dev_mode_trial_expired': true,
      });
      await DevMode.initialize();
      expect(DevMode.isActive, isFalse);
      expect(EntitlementService.debugSimulateTrialExpired, isFalse);
    });
  });

  group('ThemeProvider session variant', () {
    test('setSessionVariant never persists; restore returns to saved', () async {
      SharedPreferences.setMockInitialValues(
          {'theme_variant': AppThemeVariant.dark.name});
      final tp = ThemeProvider();
      await tp.initialize();
      expect(tp.variant, AppThemeVariant.dark);

      tp.setSessionVariant(AppThemeVariant.royalIndigo);
      expect(tp.variant, AppThemeVariant.royalIndigo);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_variant'), AppThemeVariant.dark.name,
          reason: 'session preview must not touch persistence');

      await tp.restorePersistedVariant();
      expect(tp.variant, AppThemeVariant.dark);
    });
  });

  group('DevModeGate', () {
    // ThemeProvider sits ABOVE MaterialApp, matching the real app, so the
    // dialog route's context can read it.
    Widget host({DateTime Function()? now}) => ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: DevModeGate(
                  nowSource: now ?? DateTime.now,
                  child: const Text('Budgetify'),
                ),
              ),
            ),
          ),
        );

    testWidgets('five quick taps open the gate; correct password unlocks',
        (tester) async {
      await tester.pumpWidget(host());
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Budgetify'));
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pumpAndSettle();
      expect(find.text('Developer mode'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(DevMode.isActive, isFalse);
      expect(find.text('Incorrect password'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'budgetify.dev');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(DevMode.isActive, isTrue);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('slow taps never open the gate', (tester) async {
      // Simulated clock: each tap lands 900ms after the previous one.
      var fake = DateTime(2026, 1, 1);
      await tester.pumpWidget(host(now: () => fake));
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Budgetify'));
        await tester.pump(const Duration(milliseconds: 50));
        fake = fake.add(const Duration(milliseconds: 900));
      }
      await tester.pumpAndSettle();
      expect(find.text('Developer mode'), findsNothing);
    });

    testWidgets('while active, the gate offers Turn off and reverts previews',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'theme_variant': AppThemeVariant.light.name});
      DevMode.tryUnlock('budgetify.dev');
      GamificationService.sessionAvatarOverride = '19';

      await tester.pumpWidget(host());
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Budgetify'));
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('Developer mode is ON'), findsOneWidget);

      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();
      expect(DevMode.isActive, isFalse);
      expect(GamificationService.sessionAvatarOverride, isNull);
    });
  });
}
