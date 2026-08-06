import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/widgets/unconfirmed_caveat.dart';

/// Pump the caveat inside a hero-sized box. 328 is the real width it gets on a
/// 360dp phone: the screen's 16pt page margin and the hero card's own 24pt
/// padding come off both sides.
Future<void> _pump(
  WidgetTester tester, {
  required double amount,
  double width = 328,
  AppLanguage language = AppLanguage.english,
  bool privacy = false,
  bool dark = false,
  VoidCallback? onTap,
}) async {
  final locale = LocaleProvider();
  if (language != AppLanguage.english) await locale.setLanguage(language);
  final prefs = AppPreferences();
  if (privacy) await prefs.setPrivacyMode(true);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: locale),
        ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Scaffold(
          // Loose horizontal constraints, like the hero card's own
          // `crossAxisAlignment: start` Column. A tight SizedBox would force
          // the row to the full width and hide whether it stretches on its
          // own.
          body: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: UnconfirmedCaveat(
                amount: amount,
                onTap: onTap ?? () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UnconfirmedCaveat', () {
    testWidgets('names the flagged rupee amount, not a row count',
        (tester) async {
      await _pump(tester, amount: 10240);
      expect(find.textContaining('₹10,240'), findsOneWidget);
    });

    testWidgets('renders nothing at zero', (tester) async {
      await _pump(tester, amount: 0);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(Icon), findsNothing);
      expect(tester.getSize(find.byType(UnconfirmedCaveat)).height, 0);
    });

    testWidgets('renders nothing for a negative amount', (tester) async {
      await _pump(tester, amount: -1);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('tapping opens the queue', (tester) async {
      var taps = 0;
      await _pump(tester, amount: 500, onTap: () => taps++);
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('privacy mode masks the figure but keeps the prompt readable',
        (tester) async {
      await _pump(tester, amount: 10240, privacy: true);
      expect(find.textContaining('10,240'), findsNothing);
      // The point of masking only the ₹ figure: the user can still see that
      // something needs checking without revealing how much.
      expect(find.textContaining('₹••••'), findsOneWidget);
    });

    // The hero is dark in the default theme and champagne in the light
    // variants, so the amber has to switch with it — the deep #C05621 is
    // unreadable on near-black, and the lifted #E9A76B washes out on ivory.
    testWidgets('takes the amber that suits the hero surface', (tester) async {
      await _pump(tester, amount: 500, dark: false);
      final light = tester.widget<Icon>(find.byIcon(Icons.error_outline)).color;

      await _pump(tester, amount: 500, dark: true);
      final dark = tester.widget<Icon>(find.byIcon(Icons.error_outline)).color;

      expect(light, isNotNull);
      expect(dark, isNotNull);
      expect(dark, isNot(light));
    });

    // The layout guard. `Flexible` is loose here on purpose, so the label
    // shrinks instead of overflowing when a translation runs long — the Hindi,
    // Bengali and Tamil lines are all wider than the English one.
    testWidgets('fits every language at hero width', (tester) async {
      for (final language in AppLanguage.values) {
        await _pump(tester, amount: 1234567, language: language);
        expect(tester.takeException(), isNull, reason: language.name);
      }
    });

    testWidgets('fits a narrow card without overflowing', (tester) async {
      for (final language in AppLanguage.values) {
        await _pump(tester, amount: 1234567, language: language, width: 220);
        expect(tester.takeException(), isNull, reason: language.name);
      }
    });

    testWidgets('the chevron stays beside the label, not at the far edge',
        (tester) async {
      // Measured in a box with real slack. The test font renders one em per
      // glyph, so this line is roughly twice its on-device width — at the true
      // 328pt hero width it fills the row here and the "did it stretch?"
      // question can't be answered. 600 leaves room either way.
      await _pump(tester, amount: 500, width: 600);
      final row = tester.getRect(find.byType(Row));
      final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
      // A loose Flexible keeps the row at its natural width; an Expanded would
      // stretch the label and push the chevron out to the far edge.
      expect(row.width, lessThan(600));
      expect(chevron.right, lessThanOrEqualTo(row.right + 0.5));
    });
  });
}
