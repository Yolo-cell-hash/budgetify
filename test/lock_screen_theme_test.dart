// The lock screen is the app's front door, and it used to paint a hardcoded
// midnight-and-gold surface — so a light theme, a streak-reward theme or an
// equipped royal's court dress all still met a dark stranger at unlock. These
// tests pin it to the active theme's HeroStyle, which is the same channel the
// royal dress rewrites.
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/screens/lock_screen.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart'
    show courtDressFor, kRoyalAvatars;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Pumps the lock screen under [theme]. The screen fires the platform
/// biometric prompt from a post-frame callback; there's no plugin behind the
/// channel in a widget test, so the resulting MissingPluginException is
/// collected and discarded — it's orthogonal to what these tests check.
Future<void> _pumpLock(WidgetTester tester, ThemeData theme,
    {Object? key}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<LocaleProvider>(
      create: (_) => LocaleProvider(),
      child: MaterialApp(
        // A fresh key per theme plus no theme animation: otherwise
        // MaterialApp's AnimatedTheme cross-fades from the previously pumped
        // theme and a single pump reads a half-interpolated surface.
        key: ValueKey(key ?? theme.hashCode),
        themeAnimationDuration: Duration.zero,
        theme: theme,
        home: LockScreen(onUnlocked: () {}),
      ),
    ),
  );
  await tester.pump();
  tester.takeException();
}

/// The gradient actually painted behind the lock content.
LinearGradient _paintedGradient(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration as BoxDecoration).gradient as LinearGradient;
}

Color _titleColor(WidgetTester tester, String title) =>
    tester.widget<Text>(find.text(title)).style!.color!;

/// The unlock CTA. Deliberately NOT `find.byType(ElevatedButton)`: the screen
/// builds it with the `ElevatedButton.icon` factory, whose widget is the
/// private subclass `_ElevatedButtonWithIcon`, and `byType` matches on exact
/// runtime type — so it would silently find nothing.
ElevatedButton _unlockButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(
      find.byWidgetPredicate((w) => w is ElevatedButton),
    );

void main() {
  const title = 'Budgetify is locked';

  testWidgets('wears the hero surface of every built-in theme',
      (tester) async {
    for (final variant in AppThemeVariant.values) {
      final theme = AppTheme.of(variant);
      final hero = theme.extension<AppPalette>()!.hero;

      await _pumpLock(tester, theme, key: variant);

      expect(_paintedGradient(tester).colors, hero.gradientColors,
          reason: '$variant should paint its own hero gradient');
      expect(_titleColor(tester, title), hero.foreground,
          reason: '$variant title should use its hero foreground');
      // The unlock CTA carries the theme accent, not a fixed gold.
      expect(
        _unlockButton(tester).style!.backgroundColor!.resolve({}),
        hero.accent,
        reason: '$variant unlock button should use its hero accent',
      );
    }
  });

  testWidgets('light and dark do not share a surface', (tester) async {
    await _pumpLock(tester, AppTheme.of(AppThemeVariant.light));
    final light = _paintedGradient(tester).colors;
    await _pumpLock(tester, AppTheme.of(AppThemeVariant.dark));
    final dark = _paintedGradient(tester).colors;
    expect(light, isNot(dark));
  });

  testWidgets('follows an equipped royal court dress', (tester) async {
    // The dress re-skins the hero through the AppPalette extension; the lock
    // screen reads that extension, so the court reaches it for free. A royal
    // dresses whichever of light/dark is its home brightness. Note the avatar
    // value is a *sprite* index, not a position in kRoyalAvatars.
    final royal = kRoyalAvatars.first;
    final maybeDress = courtDressFor('pixel', '${royal.spriteIndex}');
    expect(maybeDress, isNotNull,
        reason: '${royal.id} should carry a court dress');
    final dress = maybeDress!;

    for (final variant in [AppThemeVariant.light, AppThemeVariant.dark]) {
      final base = AppTheme.of(variant);
      final dressed = dress(variant, base);
      final dressedHero = dressed.extension<AppPalette>()!.hero;

      await _pumpLock(tester, dressed, key: 'dressed-$variant');
      expect(_paintedGradient(tester).colors, dressedHero.gradientColors);
      expect(_titleColor(tester, title), dressedHero.foreground);
    }

    // ...and on its home brightness the court actually changes the surface,
    // so this is a real assertion and not a tautology.
    final home =
        dress(AppThemeVariant.light, AppTheme.of(AppThemeVariant.light));
    final away = dress(AppThemeVariant.dark, AppTheme.of(AppThemeVariant.dark));
    final changedLight = home.extension<AppPalette>()!.hero.accent !=
        AppTheme.of(AppThemeVariant.light).extension<AppPalette>()!.hero.accent;
    final changedDark = away.extension<AppPalette>()!.hero.accent !=
        AppTheme.of(AppThemeVariant.dark).extension<AppPalette>()!.hero.accent;
    expect(changedLight || changedDark, isTrue,
        reason: 'the court dress should retint one of the base themes');
  });
}
