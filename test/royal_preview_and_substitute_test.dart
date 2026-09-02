import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/models/streak_reward.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/billing_service.dart';
import 'package:budget_tracker/services/entitlement_service.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/avatar_picker_sheet.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/royal_character.dart';
import 'package:budget_tracker/widgets/royal_preview_stage.dart';
import 'package:budget_tracker/widgets/royal_reactions.dart';
import 'package:budget_tracker/widgets/streak_reward_road.dart';

/// Two things a buyer is owed before and after the sale.
///
/// BEFORE: the ROYALTY tier sells a full-body character that strolls the app
/// and signs off with its own move. A price with no preview asks someone to
/// pay for a description, so the court sheet runs a reel of the real thing.
///
/// AFTER: a royal pick is worth exactly the royal it opens. Buy the whole
/// court and the 10- and 24-day milestones have nothing left to give, so they
/// pay Streak Freezes instead and say why — rather than marching the user into
/// a picker where everything is already theirs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = AppStrings(AppLanguage.english);
  final royal = kRoyalAvatars.first; // The Sovereign

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EntitlementService().resetForTest();
    EntitlementService.debugTrialRestartAt = DateTime.utc(2000);
    BillingService().gateway = const UnavailableBillingGateway();
  });

  group('preview reel', () {
    /// The action the stage is painting right now.
    RoyalAction? paintedAction(WidgetTester tester) {
      final paints = tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(RoyalPreviewStage),
          matching: find.byType(CustomPaint),
        ),
      );
      for (final p in paints) {
        final painter = p.painter;
        if (painter is RoyalCharacterPainter) return painter.action;
      }
      return null;
    }

    Widget host(RoyalAvatar r) => MaterialApp(
          theme: AppTheme.of(AppThemeVariant.dark),
          home: Scaffold(body: Center(child: RoyalPreviewStage(royal: r))),
        );

    testWidgets('cycles idle → signature → travel', (tester) async {
      await tester.pumpWidget(host(royal));
      await tester.pump();

      // Beat boundaries are 2000 / 4800 / 7600ms; sample inside each.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(paintedAction(tester), RoyalAction.idle);

      await tester.pump(const Duration(milliseconds: 2400)); // 3400ms
      expect(paintedAction(tester), royalSignatureAction(royal.id));

      await tester.pump(const Duration(milliseconds: 2800)); // 6200ms
      expect(paintedAction(tester), RoyalAction.ride);

      // ...and loops back rather than sticking on the last beat.
      await tester.pump(const Duration(milliseconds: 2400)); // 8600 → 1000
      expect(paintedAction(tester), RoyalAction.idle);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every royal shows three DISTINCT actions', (tester) async {
      // The Huntress has no mount, and her first travel beat was a blade
      // dance — a planted move that made all three of her beats the same
      // standing pose. A reel where nothing changes sells nothing.
      for (final r in kRoyalAvatars) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(host(r));
        await tester.pump();
        final seen = <RoyalAction>{};
        for (final ms in [1000, 2400, 2800]) {
          await tester.pump(Duration(milliseconds: ms));
          final a = paintedAction(tester);
          expect(a, isNotNull, reason: r.id);
          seen.add(a!);
        }
        expect(seen.length, 3, reason: '${r.id} repeats a beat: $seen');
      }
    });

    testWidgets('a mounted beat gets the wide box, standing gets the tall one',
        (tester) async {
      await tester.pumpWidget(host(royal));
      await tester.pump();
      Size stageBox() => tester
          .widgetList<SizedBox>(find.descendant(
            of: find.byType(RoyalPreviewStage),
            matching: find.byType(SizedBox),
          ))
          .map((b) => Size(b.width ?? 0, b.height ?? 0))
          .firstWhere((s) => s.width > 0);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(stageBox(), kRoyalStandBox);
      await tester.pump(const Duration(milliseconds: 5200)); // 6200ms, riding
      expect(stageBox(), kRoyalRideBox);
    });

    testWidgets('the locked court sheet previews before it sells',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<AppPreferences>(
                create: (_) => AppPreferences()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showAvatarPicker(
                      ctx,
                      const GamiProfile(avatarKind: 'pixel', avatarValue: '0'),
                      nowSource: () => DateTime(2026, 7, 15),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final tile = find.byWidgetPredicate(
          (w) => w is AnimatedRoyalAvatar && w.royal.id == royal.id);
      await tester.ensureVisible(tile.first);
      await tester.pump();
      await tester.tap(tile.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The reel and its caption sit on the sheet that asks for money.
      expect(find.byType(RoyalPreviewStage), findsOneWidget);
      expect(find.text(en.royalPreviewCaption), findsOneWidget);
      expect(find.text(en.buyRoyalCta('₹49')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('a royal pick with nothing left to unlock', () {
    final gami = GamificationService();

    /// Seed a longest streak of [days] straight into the blob.
    Future<void> seedStreak(int days) async {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(
        'gamification_v1',
        '{"streak":{"current":$days,"longest":$days,"freezes":0}}',
      );
    }

    Future<void> buyWholeCourt() async {
      for (final r in kRoyalAvatars) {
        await EntitlementService().registerRoyalPurchase(r.id);
      }
    }

    test('an unowned court keeps its picks and pays no freezes', () async {
      await seedStreak(24);
      await EntitlementService().initialize();
      expect(await gami.allRoyalsUnlocked(), isFalse);
      await gami.syncRoyalPickSubstitutes();
      expect(await gami.substitutedRoyalPickIds(), isEmpty);
      expect(await gami.availableRoyalPicks(), 2);
      expect((await gami.freezeInfo()).available, 0);
    });

    test('buying the whole court before day 10 converts both milestones',
        () async {
      await EntitlementService().initialize();
      await buyWholeCourt();
      await seedStreak(24);

      expect(await gami.allRoyalsUnlocked(), isTrue);
      await gami.syncRoyalPickSubstitutes();

      expect(await gami.substitutedRoyalPickIds(),
          {'royal_pick_1', 'royal_pick_2'});
      // Nothing left to pick, so the picker is never told there is.
      expect(await gami.availableRoyalPicks(), 0);
      expect((await gami.freezeInfo()).available, kRoyalPickFreezeSubstitute * 2);
    });

    test('only milestones actually REACHED pay out', () async {
      await EntitlementService().initialize();
      await buyWholeCourt();
      await seedStreak(10); // first milestone only

      await gami.syncRoyalPickSubstitutes();
      expect(await gami.substitutedRoyalPickIds(), {'royal_pick_1'});
      expect((await gami.freezeInfo()).available, kRoyalPickFreezeSubstitute);

      // Reaching day 24 later pays the second, and only the second.
      await seedStreak(24);
      final prefs = await SharedPreferences.getInstance();
      // seedStreak rewrote the blob, so restore what was already granted.
      prefs.setString(
        'gamification_v1',
        '{"streak":{"current":24,"longest":24,"freezes":'
            '$kRoyalPickFreezeSubstitute},'
            '"royalPickFreezes":["royal_pick_1"]}',
      );
      await gami.syncRoyalPickSubstitutes();
      expect(await gami.substitutedRoyalPickIds(),
          {'royal_pick_1', 'royal_pick_2'});
      expect((await gami.freezeInfo()).available, kRoyalPickFreezeSubstitute * 2);
    });

    test('a pick already SPENT is never paid for twice', () async {
      await seedStreak(24);
      // Spent the first pick on the Sovereign, then bought the rest.
      await gami.unlockRoyal(royal.id);
      await EntitlementService().initialize();
      for (final r in kRoyalAvatars.where((r) => r.id != royal.id)) {
        await EntitlementService().registerRoyalPurchase(r.id);
      }

      expect(await gami.allRoyalsUnlocked(), isTrue);
      await gami.syncRoyalPickSubstitutes();

      // Only the SECOND milestone was still unspent.
      expect(await gami.substitutedRoyalPickIds(), {'royal_pick_2'});
      expect((await gami.freezeInfo()).available, kRoyalPickFreezeSubstitute);
    });

    test('running twice never double-grants', () async {
      await EntitlementService().initialize();
      await buyWholeCourt();
      await seedStreak(24);
      await gami.syncRoyalPickSubstitutes();
      await gami.syncRoyalPickSubstitutes();
      await gami.syncRoyalPickSubstitutes();
      expect((await gami.freezeInfo()).available, kRoyalPickFreezeSubstitute * 2);
    });

    testWidgets('the Road shows freezes and the reason, not "Unlock Now"',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StreakRewardRoad(
                  currentStreak: 24,
                  longestStreak: 24,
                  substitutedRoyalPicks: const {
                    'royal_pick_1',
                    'royal_pick_2'
                  },
                  onChooseRoyal: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(en.unlockNow), findsNothing);
      // The blurb is what identifies a SUBSTITUTED tile; the action line
      // reuses freezePackAdded, which the real freeze-pack milestones on the
      // same Road already show.
      expect(
          find.text(
              en.royalPickSubstituteBlurb(kRoyalPickFreezeSubstitute)),
          findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unsubstituted Road still offers the pick', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StreakRewardRoad(
                  currentStreak: 24,
                  longestStreak: 24,
                  onChooseRoyal: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(en.unlockNow), findsNWidgets(2));
      expect(
          find.text(
              en.royalPickSubstituteBlurb(kRoyalPickFreezeSubstitute)),
          findsNothing);
    });
  });
}
