import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/royal_character.dart';
import 'package:budget_tracker/widgets/royal_court_still.dart';
import 'package:budget_tracker/widgets/theme_preview_sheet.dart';

/// The third thing a buyer is owed: *what does my app look like afterwards.*
///
/// The reel answers "what does this character do". It cannot answer the other
/// half of what the ROYALTY tier sells — a THEME — because a chibi on a velvet
/// rectangle is a figure with no ground. [RoyalCourtStill] gives it a ground:
/// the Appearance picker's own dashboard still, handed the court's real
/// [ThemeDress].
///
/// These tests exist to keep the still HONEST. Its whole claim is that nothing
/// in it was chosen to flatter the royal — every colour comes from
/// [courtDressFor], the same function that dresses the live app. The moment a
/// preview starts painting its own idea of the court, it stops being evidence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = AppStrings(AppLanguage.english);
  final royal = kRoyalAvatars.first; // The Sovereign

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child, {AppThemeVariant variant = AppThemeVariant.dark}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
          ChangeNotifierProvider<AppPreferences>(create: (_) => AppPreferences()),
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider()..setVariant(variant),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.of(variant),
          home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
        ),
      );

  /// The palette the still is actually painting itself with — read off the
  /// [Theme] the still installs, not off anything the test assumes.
  AppColors stillColors(WidgetTester tester) {
    final theme = tester.widget<Theme>(
      find.descendant(of: find.byType(ThemeStill), matching: find.byType(Theme)),
    );
    return theme.data.extension<AppPalette>()!.colors;
  }

  /// The full-body character painted over the still, if any.
  RoyalCharacterPainter? painted(WidgetTester tester) {
    for (final p in tester.widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(RoyalCourtStillFrame),
        matching: find.byType(CustomPaint),
      ),
    )) {
      if (p.painter is RoyalCharacterPainter) {
        return p.painter as RoyalCharacterPainter;
      }
    }
    return null;
  }

  group('the dress is the real one', () {
    testWidgets('the dressed still wears the court accent, not the app gold',
        (tester) async {
      await tester.pumpWidget(
        host(RoyalCourtStillFrame(royal: royal, dressed: true)),
      );
      await tester.pump();

      // Not "some gold-ish colour" — the exact shade courtDressFor computes.
      // If the dress changes, this moves with it; if the preview ever starts
      // inventing its own accent, this fails.
      final dressed = courtDressFor('pixel', '${royal.spriteIndex}')!;
      final expected = dressed(
        AppThemeVariant.dark,
        AppTheme.of(AppThemeVariant.dark),
      ).extension<AppPalette>()!.colors;

      expect(stillColors(tester).brandAccent, expected.brandAccent);
      expect(stillColors(tester).brandAccent,
          isNot(AppTheme.of(AppThemeVariant.dark)
              .extension<AppPalette>()!
              .colors
              .brandAccent));
    });

    testWidgets('the undressed side is the app exactly as it ships',
        (tester) async {
      await tester.pumpWidget(
        host(RoyalCourtStillFrame(royal: royal, dressed: false)),
      );
      await tester.pump();

      // The control half of the A/B. If this drifted toward the court even
      // slightly, the comparison would overstate what the royal changes.
      expect(
        stillColors(tester).brandAccent,
        AppTheme.of(AppThemeVariant.dark)
            .extension<AppPalette>()!
            .colors
            .brandAccent,
      );
      expect(painted(tester), isNull, reason: 'no character on the control');
    });

    testWidgets('it previews the mode the reader is actually in',
        (tester) async {
      // Showing a royal on the dark theme to somebody reading in light answers
      // a question they did not ask.
      await tester.pumpWidget(
        host(
          RoyalCourtStillFrame(royal: royal, dressed: true),
          variant: AppThemeVariant.light,
        ),
      );
      await tester.pump();

      final dressed = courtDressFor('pixel', '${royal.spriteIndex}')!;
      final expected = dressed(
        AppThemeVariant.light,
        AppTheme.of(AppThemeVariant.light),
      ).extension<AppPalette>()!.colors;
      expect(stillColors(tester).brandAccent, expected.brandAccent);
      // Light gets the deep, ink-legible shade rather than the bright one.
      expect(stillColors(tester).brandAccent, royal.theme.accentDeep);
    });
  });

  group('the character in it', () {
    testWidgets('strolls the page and stops mid-way to wave', (tester) async {
      await tester.pumpWidget(
        host(RoyalCourtStillFrame(royal: royal, dressed: true)),
      );
      await tester.pump();

      // The crossing is 6400ms: walk, wave from 42% to 62%, walk out.
      await tester.pump(const Duration(milliseconds: 1000)); // 16%
      expect(painted(tester)?.action, RoyalAction.walk);

      await tester.pump(const Duration(milliseconds: 2300)); // 52% — waving
      expect(painted(tester)?.action, RoyalAction.wave);

      await tester.pump(const Duration(milliseconds: 1600)); // 77% — walking on
      expect(painted(tester)?.action, RoyalAction.walk);
    });

    testWidgets('reduced motion parks the figure instead of looping it',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: host(RoyalCourtStillFrame(royal: royal, dressed: true)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      // Parked mid-page, mid-wave — the pose that says "this character stands
      // on your screen" — and unchanged on the next frame.
      expect(painted(tester)?.action, RoyalAction.wave);
      final t = painted(tester)!.t;
      await tester.pump(const Duration(milliseconds: 900));
      expect(painted(tester)?.t, t);
    });
  });

  group('the A/B', () {
    testWidgets('flips the still between the two apps', (tester) async {
      await tester.pumpWidget(host(RoyalCourtStill(royal: royal)));
      await tester.pump();

      // Opens on the dressed side: they came to look at the royal.
      final court = stillColors(tester).brandAccent;
      expect(painted(tester), isNotNull);

      await tester.tap(find.text(en.royalStillWithout));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(stillColors(tester).brandAccent, isNot(court));
      expect(painted(tester), isNull);
      expect(find.text(en.royalStillPlainCaption), findsOneWidget);

      await tester.tap(
        find.text(en.royalStillWith(en.royalAvatarName(royal.id))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(stillColors(tester).brandAccent, court);
    });
  });

  testWidgets('every royal dresses the still without blowing it up',
      (tester) async {
    for (final r in kRoyalAvatars) {
      await tester.pumpWidget(host(RoyalCourtStillFrame(royal: r, dressed: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull, reason: r.id);
      expect(painted(tester)?.royal.id, r.id);
    }
  });
}
