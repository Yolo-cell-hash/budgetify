import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/screens/app_tour_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _en = AppStrings(AppLanguage.english);

/// Pumps a host screen with a button that pushes the tour via its real
/// route, so pop-on-finish can be observed.
Future<void> _openTour(WidgetTester tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<LocaleProvider>(
      create: (_) => LocaleProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).push(AppTourScreen.route()),
                child: const Text('open tour'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open tour'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('walks all five pages and finishes back to the host',
      (tester) async {
    await _openTour(tester);

    expect(find.text(_en.tour1Title), findsOneWidget);
    expect(find.text(_en.tourSkip), findsOneWidget);

    // Advance through every page with Next.
    for (final title in [
      _en.tour2Title,
      _en.tour3Title,
      _en.tour4Title,
      _en.tour5Title,
    ]) {
      await tester.tap(find.text(_en.tourNext));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }

    // Last page: the CTA changes and finishing pops back to the host.
    expect(find.text(_en.tourStart), findsOneWidget);
    await tester.tap(find.text(_en.tourStart));
    await tester.pumpAndSettle();
    expect(find.text(_en.tour5Title), findsNothing);
    expect(find.text('open tour'), findsOneWidget);
  });

  testWidgets('skip leaves the tour immediately', (tester) async {
    await _openTour(tester);

    await tester.tap(find.text(_en.tourSkip));
    await tester.pumpAndSettle();

    expect(find.text(_en.tour1Title), findsNothing);
    expect(find.text('open tour'), findsOneWidget);
  });
}
