import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/models/achievement.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/billing_service.dart';
import 'package:budget_tracker/services/entitlement_service.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/avatar_picker_sheet.dart';
import 'package:budget_tracker/widgets/avatars.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/royal_showcase.dart';

/// The court sheet has to fit on one screen.
///
/// It stopped fitting by accretion: a circle, then a reel, then a dashboard
/// still, each defensible on its own, all stacked inside a sheet capped at the
/// Material default of 9/16 of the screen. Measured on an ordinary 914dp phone
/// that was **1204dp of content in a 470dp window** — the sheet showed 39% of
/// itself, and the two things a shopper needs (what it costs, and the button
/// that charges it) were both two scrolls down.
///
/// So the numbers are the test. Anything added to this sheet from here has to
/// earn its height against a budget, and this is where it finds out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = AppStrings(AppLanguage.english);
  final royal = kRoyalAvatars.firstWhere((r) => r.id == 'sentinel');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EntitlementService().resetForTest();
    EntitlementService.debugTrialRestartAt = DateTime.utc(2000);
    BillingService().gateway = const UnavailableBillingGateway();
    // The app-icon row is Android-only, so a desktop test host measures a
    // sheet 53dp shorter than the tallest one that ships — which is exactly
    // the configuration the guarantee has to hold for.
    debugForceRoyalAppIconRow = true;
  });

  tearDown(() => debugForceRoyalAppIconRow = false);

  /// Opens the picker, then [royal]'s court sheet, and hands back the sheet's
  /// scroll position.
  Future<ScrollPosition> openCourtSheet(
    WidgetTester tester, {
    required bool owned,
    Size screen = const Size(1080, 2400),
    double dpr = 2.625,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
          ChangeNotifierProvider<AppPreferences>(create: (_) => AppPreferences()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.of(AppThemeVariant.dark),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAvatarPicker(
                    ctx,
                    const GamiProfile(avatarKind: 'pixel', avatarValue: '0'),
                    stats: const GamiStats(),
                    unlockedRoyals: owned ? {royal.id} : const {},
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

    final tile = find.byWidgetPredicate((w) =>
        w is AvatarView && w.value == '${royal.spriteIndex}' && w.size >= 60);
    await tester.ensureVisible(tile.first);
    await tester.pump();
    await tester.tap(tile.first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The court sheet's middle band, identified by what it contains rather
    // than by tree order: the picker behind has a scroll view of its own, and
    // the showcase has a horizontal one inside it.
    return tester
        .state<ScrollableState>(find.ancestor(
          of: find.byType(RoyalShowcase),
          matching: find.byType(Scrollable),
        ))
        .position;
  }

  group('it fits on one screen', () {
    testWidgets('a locked royal: nothing to scroll at all', (tester) async {
      final pos = await openCourtSheet(tester, owned: false);
      expect(pos.maxScrollExtent, 0,
          reason: 'the sales sheet must open whole — it was 734dp short');
    });

    testWidgets('an owned royal, every control shown: nothing to scroll',
        (tester) async {
      // The tallest sheet that ships: three switches, the mode row, the
      // showcase and the Equip action.
      final pos = await openCourtSheet(tester, owned: true);
      expect(pos.maxScrollExtent, 0);
    });

    testWidgets('the price and the button are both on the first screen',
        (tester) async {
      await openCourtSheet(tester, owned: false);
      // Not just "in the tree" — actually hit-testable where they are drawn,
      // which is what "visible at a glance" has to mean.
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      for (final f in [
        find.text(en.royalPriceCaption),
        find.text(en.buyRoyalCta('₹49')),
        // The picker behind the sheet mentions royal picks too, so scope
        // this to the sheet's own footer note.
        find.text(en.royalLockedSheetNote),
      ]) {
        expect(f, findsOneWidget);
        // Not just "in the tree" — laid out inside the screen's bounds, which
        // is what "visible at a glance" has to mean. Every one of these was
        // off the bottom before.
        final rect = tester.getRect(f.first);
        expect(rect.bottom, lessThanOrEqualTo(screenHeight),
            reason: 'drawn past the bottom of the screen');
        expect(rect.top, greaterThanOrEqualTo(0.0));
      }
    });
  });

  group('when it genuinely cannot fit', () {
    testWidgets('the action stays put and only the middle scrolls',
        (tester) async {
      // A short phone at a large accessibility text scale — the case no fixed
      // budget survives. The promise degrades to the one that matters: the
      // decision never scrolls away.
      final pos = await openCourtSheet(
        tester,
        owned: true,
        screen: const Size(720, 1280),
        dpr: 2.0,
        textScale: 1.6,
      );
      expect(pos.maxScrollExtent, greaterThan(0),
          reason: 'this configuration is meant to overflow');

      // The equip action is still on screen, unscrolled.
      final cta = find.text(en.equipRoyal);
      expect(cta, findsOneWidget);
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getCenter(cta).dy, lessThan(screenHeight));

      // ...and it stays there after the middle band is scrolled.
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump();
      expect(tester.getCenter(cta).dy, lessThan(screenHeight));
    });
  });

  group('the showcase', () {
    testWidgets('carries both views and starts on the character',
        (tester) async {
      await openCourtSheet(tester, owned: false);
      expect(find.byType(RoyalShowcase), findsOneWidget);
      final pages = tester.widget<PageView>(find.descendant(
        of: find.byType(RoyalShowcase),
        matching: find.byType(PageView),
      ));
      expect(pages.controller!.page ?? pages.controller!.initialPage, 0);
      // Page one is the reel, so the still's A/B is not showing yet.
      expect(find.text(en.royalStillWithout), findsNothing);
      expect(find.text(en.royalPreviewCaption), findsOneWidget);

      await tester.drag(
        find.descendant(
          of: find.byType(RoyalShowcase),
          matching: find.byType(PageView),
        ),
        const Offset(-400, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Page two hands over the comparison, and takes the caption's slot.
      expect(find.text(en.royalStillWithout), findsOneWidget);
      expect(find.text(en.royalPreviewCaption), findsNothing);
    });
  });
}
