import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/services/notification_parser_service.dart';
import 'package:budget_tracker/widgets/notif_coverage_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The coverage breakdown is the only place the app admits that most of the
/// allowlist can never see a debit. Two things must hold for it to do that
/// job: every allowlisted app appears (it is also the privacy disclosure of
/// what gets read), and the copy fits on a small phone in every language —
/// this lives inside a dialog, where overflow means the explanation is the
/// part that gets clipped.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Widget> harness(AppLanguage lang) async {
    final lp = LocaleProvider();
    await lp.initialize();
    await lp.setLanguage(lang);
    return ChangeNotifierProvider.value(
      value: lp,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: NotifCoverageList(),
          ),
        ),
      ),
    );
  }

  testWidgets('names every watched app, grouped by what it can see',
      (tester) async {
    await tester.pumpWidget(await harness(AppLanguage.english));
    await tester.pumpAndSettle();

    for (final app in NotificationParserService.watchedPackages.values) {
      expect(find.text(app.label), findsOneWidget,
          reason: '${app.label} is read but never disclosed');
    }

    final strings = AppStrings(AppLanguage.english);
    expect(find.text(strings.notifCoverageBothWays), findsOneWidget);
    expect(find.text(strings.notifCoverageCreditsOnly), findsOneWidget);
    expect(find.text(strings.notifCoverageCreditsOnlyNote), findsOneWidget);
  });

  testWidgets('fits a small phone at large text in every language',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final lang in AppLanguage.values) {
      await tester.pumpWidget(await harness(lang));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$lang overflows');
      expect(find.text('PayZapp'), findsOneWidget, reason: '$lang');
    }
  });
}
