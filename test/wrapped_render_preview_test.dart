// Dev-only design proofing harness: renders the redesigned Wrapped card
// across theme variants, privacy/amounts modes and royal seals to PNGs so
// the poster can be verified by eye (a fixed 360×640 composition authored
// blind WILL have spacing issues). Not an assertion suite — it only fails if
// the card throws. Sheets land in WRAPPED_PREVIEW_DIR (or the system temp
// dir) as wrapped_<scenario>.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:budget_tracker/models/monthly_recap.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/wrapped_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _outDirOverride = String.fromEnvironment('WRAPPED_PREVIEW_DIR');

MonthlyRecap _demoRecap() {
  final daily = List<double>.generate(
      30,
      (i) => i == 13
          ? 9400.0
          : (i % 5 == 0 ? 0.0 : 600.0 + (i * 631) % 2800));
  return MonthlyRecap(
    month: DateTime(2026, 6, 1),
    availableDays: 30,
    hasData: true,
    savingsRatePct: 18,
    spendVsLastMonthPct: -12,
    topCategories: const [
      RecapHighlight(label: 'Rent', icon: '🏠', sharePct: 48, amount: 40000),
      RecapHighlight(
          label: 'Food & Dining', icon: '🍔', sharePct: 21, amount: 17400),
      RecapHighlight(label: 'Groceries', icon: '🛒', sharePct: 9, amount: 7500),
    ],
    topMerchant: const RecapHighlight(
        label: 'Malandkar Santosh Ramchandra',
        icon: '🏪',
        sharePct: 48,
        amount: 40000),
    categoryMover: const RecapMover(label: 'Travel', icon: '✈️', changePct: 35),
    netWorthChangePct: 4,
    investedPct: 62,
    transactionCount: 266,
    merchantCount: 102,
    trends: RecapTrends(
      dailySpend: daily,
      peakDay: DateTime(2026, 6, 14),
      peakDayAmount: 9400,
      busiestDay: DateTime(2026, 6, 27),
      busiestDayTxns: 21,
      trackedDays: 30,
      noSpendDays: 6,
    ),
    appTimeSeconds: 4 * 3600 + 23 * 60,
    totalSpent: 82932,
    totalIncome: 101000,
    avgPerDay: 2764,
    biggestTxnAmount: 35000,
    biggestTxnLabel: 'Malandkar Santosh Ramchandra',
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('render wrapped card proof sheets', (tester) async {
    final dir = _outDirOverride.isNotEmpty
        ? _outDirOverride
        : Directory.systemTemp.createTempSync('wrapped_previews').path;
    Directory(dir).createSync(recursive: true);

    // Real brand typography, so the proof reflects the shipped composition.
    await tester.runAsync(() async {
      final loader = FontLoader('Manrope');
      for (final weight in ['400', '500', '600', '700', '800']) {
        loader.addFont(rootBundle.load('assets/fonts/manrope-$weight.ttf'));
      }
      await loader.load();
    });

    tester.view.physicalSize = const Size(760, 1360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final lp = LocaleProvider();
    await lp.initialize();

    // (name, theme, showAmounts, royal). Royal scenarios wear the court
    // dress the same way ThemeProvider applies it in the app.
    final scenarios = <(String, ThemeData, bool, RoyalAvatar?)>[
      ('dark_privacy', AppTheme.of(AppThemeVariant.dark), false, null),
      ('dark_amounts', AppTheme.of(AppThemeVariant.dark), true, null),
      ('light_privacy', AppTheme.of(AppThemeVariant.light), false, null),
      ('light_amounts', AppTheme.of(AppThemeVariant.light), true, null),
      ('smoky_privacy', AppTheme.of(AppThemeVariant.smokyIvory), false, null),
      ('seashell_amounts', AppTheme.of(AppThemeVariant.seashellMauve), true, null),
      ('onyx_privacy', AppTheme.of(AppThemeVariant.onyxAmber), false, null),
      ('royalindigo_privacy', AppTheme.of(AppThemeVariant.royalIndigo), false, null),
      ('midnight_amounts', AppTheme.of(AppThemeVariant.midnightIndigo), true, null),
      (
        'dark_darkprince',
        courtDressFor('pixel', '21')!(
            AppThemeVariant.dark, AppTheme.of(AppThemeVariant.dark)),
        false,
        royalAvatarAt(21),
      ),
      (
        'light_sovereign',
        courtDressFor('pixel', '18')!(
            AppThemeVariant.light, AppTheme.of(AppThemeVariant.light)),
        true,
        royalAvatarAt(18),
      ),
    ];

    for (final (name, theme, amounts, royal) in scenarios) {
      final key = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: lp,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: WrappedCard(
                    recap: _demoRecap(),
                    showAmounts: amounts,
                    royal: royal,
                    animate: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // Let AnimatedTheme finish lerping to this scenario's palette before
      // capturing, or every sheet wears the first theme.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'threw on $name');

      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File('$dir/wrapped_$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
      });
    }

    // Where to look, when run by hand.
    // ignore: avoid_print
    print('Wrapped proof sheets → $dir');
  });
}
