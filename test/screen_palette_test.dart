import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The same leak Settings had, in the three screens that carried the most of
/// it: colour decided by `isDark ? … : …`, with the two branches pasted out of
/// the light and dark palettes.
///
/// Brightness cannot tell `smokyIvory` from `light`, or `royalIndigo` from
/// `dark` — each reward palette shares its brightness with a base theme. So
/// every one of them stopped at these screens: budgets, the transaction list
/// and transaction detail all stayed in base greys no matter what was
/// equipped.
///
/// Guarded at the source rather than by rendering: these screens reach the
/// database while mounting and the project has no sqflite test factory, so a
/// widget test never gets a tree to read colours off. See
/// settings_screen_theme_test.dart, which makes the same trade — when both
/// have landed, the two files should fold into this one.
void main() {
  const screens = [
    'lib/screens/budget_screen.dart',
    'lib/screens/transaction_detail_screen.dart',
    'lib/screens/transactions_screen.dart',
  ];

  /// Every neutral these screens used to write down by hand. They are real
  /// palette values — that is the point: they must be *read* from
  /// [AppColors], never restated, or the six reward palettes never arrive.
  const palettePastedByHand = <String, String>{
    '0xFF16181E': 'dark card',
    '0xFF121318': 'dark surface',
    '0xFF0A0B0E': 'dark background',
    '0xFF262931': 'dark border',
    '0xFF2E313A': 'a dark grey that was never any palette value',
    '0xFFE9E9E4': 'light border',
    '0xFFF6F6F3': 'light background',
    '0xFFFAFAF8': 'light cardAlt',
    '0xFF9A9DA6': 'dark secondary text',
    '0xFF6E727C': 'light secondary text',
    '0xFF8A8D96': 'a grey used on both brightnesses at once',
    '0xFF4E525C': 'a mid grey standing in for tertiary text',
    '0xFFD5D5CF': 'its light-mode counterpart',
    '0xFF3D4758': 'a chip border',
    '0xFFEFE6D2': 'a cream selection tint that suited only the light theme',
    '0xFF2A3B52': 'the steel blue the category picker used to select with',
    '0xFF8FA9C7': 'its border, which did not even follow brightness',
  };

  for (final path in screens) {
    final name = path.split('/').last;
    final source = File(path).readAsStringSync();

    group(name, () {
      test('writes no palette colour down by hand', () {
        for (final entry in palettePastedByHand.entries) {
          expect(
            source.contains(entry.key),
            isFalse,
            reason: '$name hardcodes ${entry.key} (${entry.value}). Read it '
                'from AppColors.of(context) instead, or the reward palettes '
                'will not reach this screen.',
          );
        }
      });

      test('never picks a colour from brightness', () {
        // Brightness legitimately decides two things here and both survive: the
        // *alpha* of a tint (the same wash reads heavier on a dark canvas) and
        // whether a card carries a shadow at all. Only a brightness-chosen
        // Color is a regression.
        final colourFromBrightness = RegExp(
          r'isDark(?:Mode)?\s*\?[^;]{0,200}?Color\(0x|'
          r'brightness == Brightness\.dark\s*\?[^;]{0,200}?Color\(0x',
        );
        expect(
          colourFromBrightness.hasMatch(source),
          isFalse,
          reason: '$name is choosing a colour from brightness again. '
              'Brightness cannot tell smokyIvory from light.',
        );
      });

      test('consults the palette', () {
        // Guards the cheap way to pass the two tests above: delete the colours
        // rather than source them.
        expect(
          RegExp(r'AppColors\.of\(context\)').allMatches(source).length,
          greaterThan(3),
          reason: '$name should read its colours from the active palette',
        );
      });
    });
  }
}
