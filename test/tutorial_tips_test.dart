import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/services/tutorial_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the regression where advancing a step cancelled the *next* tip
/// while its async `show()` was still in flight — the tour would stall
/// (classically "stuck before Goals") and tab tips flickered in and out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TutorialService.instance.debugReset();
    TutorialTips.dismiss();
  });

  tearDown(TutorialTips.dismiss);

  testWidgets('advancing a step keeps the next tip (no mid-show cancel)',
      (tester) async {
    final keyA = GlobalKey();
    final keyB = GlobalKey();

    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: SizedBox(key: keyA, width: 40, height: 40),
                ),
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: SizedBox(key: keyB, width: 40, height: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    final svc = TutorialService.instance;
    await svc.restart();
    svc.advanceTo(TutorialStep.health);

    // A screen-like listener registered BEFORE the first show() — so it fires
    // ahead of the internal stale-close callback (which registers lazily on
    // the first show), reproducing production listener order.
    void onTick() {
      if (svc.isAt(TutorialStep.goals)) {
        TutorialTips.show(
          context,
          step: TutorialStep.goals,
          anchor: keyB,
          title: 'Goals tip',
          message: 'This one must survive.',
        );
      }
    }

    svc.addListener(onTick);
    addTearDown(() => svc.removeListener(onTick));

    // Show tip A; this also registers the internal cleanup listener (now last).
    TutorialTips.show(
      context,
      step: TutorialStep.health,
      anchor: keyA,
      title: 'Health tip',
      message: 'First one.',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Health tip'), findsOneWidget);

    // Advance health → goals in one notify: the screen listener kicks off
    // show(goals) (which suspends on layout), then the cleanup listener closes
    // the health tip. The goals tip must still appear.
    svc.advanceFrom(TutorialStep.health);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Health tip'), findsNothing);
    expect(find.text('Goals tip'), findsOneWidget);
  });
}
