import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Settings painted its own greys — `isDark ? Color(0xFF2E313A) :
/// Color(0xFFE9E9E4)` and five more pairs like it — so brightness was the only
/// question it ever asked. The six streak-reward palettes share their
/// brightness with light or dark, which meant an unlocked theme never reached
/// the one screen people go to *in order to switch themes*: dividers, secondary
/// text and card fills all stayed the base greys. A paid unlock that visibly
/// does nothing is worse than no unlock.
///
/// The honest test would pump the screen under each variant and read the
/// painted colours back. It can't: Settings touches the database on the way up,
/// and this project has no sqflite test factory, so the widget never finishes
/// mounting. Rather than add a dev dependency for one test, the rule is pinned
/// where it was broken — in the source. If Settings starts asking about
/// brightness again, or pastes a base-theme grey back in, this goes red.
void main() {
  final source = File('lib/screens/settings_screen.dart').readAsStringSync();

  /// The literals that used to be hardcoded here. They still exist — they are
  /// the light and dark palettes' own values — but Settings must reach them
  /// through [AppColors], never by writing them down.
  const copiedFromThePalette = <String, String>{
    '0xFF2E313A': 'a dark border that was not even the dark palette\'s border',
    '0xFFE9E9E4': 'light border',
    '0xFF8A8D96': 'dark secondary text',
    '0xFF6E727C': 'light secondary text',
    '0xFF9A9DA6': 'dark secondary text',
    '0xFF16181E': 'dark card',
    '0xFF2A2D35': 'dark divider',
  };

  group('settings screen follows the equipped palette', () {
    test('no palette colour is written down by hand', () {
      for (final entry in copiedFromThePalette.entries) {
        expect(
          source.contains(entry.key),
          isFalse,
          reason: 'settings_screen.dart hardcodes ${entry.key} '
              '(${entry.value}). Read it from AppColors.of(context) instead, '
              'or the six reward palettes will not reach this screen.',
        );
      }
    });

    test('brightness never picks a colour', () {
      // `isDark` survives for one job — cards carry a drop shadow only on a
      // light canvas — so the guard is against brightness choosing a *colour*,
      // not against the flag existing.
      final colourFromBrightness = RegExp(
        r'isDark\s*\?[^;]*Color\(0x|'
        r'brightness == Brightness\.dark\s*\?[^;]*Color\(0x',
      );
      expect(
        colourFromBrightness.hasMatch(source),
        isFalse,
        reason: 'a colour is being chosen from brightness again. Brightness '
            'cannot tell smokyIvory from light — only the palette can.',
      );
    });

    test('the palette is actually consulted', () {
      // Guards against the cheap way to make the two tests above pass: delete
      // the colours instead of sourcing them.
      expect(
        RegExp(r'AppColors\.of\(context\)').allMatches(source).length,
        greaterThan(5),
        reason: 'settings_screen.dart should read its colours from the '
            'active palette',
      );
    });
  });
}
