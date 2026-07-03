import 'package:budget_tracker/widgets/spotlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('spotlight shows its card and dismisses on the button',
      (tester) async {
    final targetKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(key: targetKey, width: 40, height: 40),
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    final done = showSpotlight(
      context,
      targetKey: targetKey,
      title: 'Your Rewards hub',
      message: 'Tap the avatar to open it.',
      buttonLabel: 'Got it',
    );

    // The ring pulses forever, so use timed pumps — never pumpAndSettle
    // while the overlay is up.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your Rewards hub'), findsOneWidget);
    expect(find.text('Tap the avatar to open it.'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump(); // start the fade-out ticker
    await tester.pump(const Duration(milliseconds: 300)); // finish the fade
    await tester.pump(); // overlay rebuilds after the entry is removed
    expect(find.text('Your Rewards hub'), findsNothing);
    await done; // resolves once the overlay is gone
  });

  testWidgets('no-ops when the target is not laid out', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));

    // Key was never attached to a widget — the call must resolve quietly.
    await showSpotlight(
      context,
      targetKey: GlobalKey(),
      title: 't',
      message: 'm',
      buttonLabel: 'ok',
    );
    expect(find.text('t'), findsNothing);
  });
}
