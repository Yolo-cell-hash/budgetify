import 'dart:math' as math;

import 'package:budget_tracker/services/app_icon_service.dart';
import 'package:budget_tracker/services/royal_notification_skin.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure mapping tests for the royal notification dress — which colour an
/// equipped royal paints its alerts. The persistence side (RoyalSkinService)
/// needs SharedPreferences, so it is verified on device.

/// CIE L*a*b* for [c], so two courts can be compared the way an eye would
/// rather than by `!=`. Plain sRGB → XYZ (D65) → Lab.
List<double> _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  final y = r * 0.2126 + g * 0.7152 + b * 0.0722;
  final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// Perceptual distance (CIE76). Roughly: 2 is the just-noticeable difference,
/// 10+ reads as "a different colour" at a glance.
double _deltaE(Color a, Color b) {
  final x = _lab(a), y = _lab(b);
  return math.sqrt(math.pow(x[0] - y[0], 2) +
      math.pow(x[1] - y[1], 2) +
      math.pow(x[2] - y[2], 2));
}

/// Contrast ratio against white — the glyph drawn inside the tinted circle.
double _contrastWithWhite(Color c) => 1.05 / (c.computeLuminance() + 0.05);

void main() {
  group('RoyalNotificationSkin.forRoyal', () {
    test('no royal equipped → no skin (the default Budgetify look)', () {
      expect(RoyalNotificationSkin.forRoyal(null), isNull);
    });

    test('an unknown royal id → no skin, never a half-dressed one', () {
      expect(RoyalNotificationSkin.forRoyal('archduke'), isNull);
    });

    test('every royal in the roster resolves to a full skin', () {
      for (final r in kRoyalAvatars) {
        final skin = RoyalNotificationSkin.forRoyal(r.id);
        expect(skin, isNotNull, reason: 'royal "${r.id}" has no skin');
        expect(RoyalAppIcon.all, contains(skin!.variant));
      }
    });

    test('the skin names the same gem as the launcher icon', () {
      // Whatever the home-screen icon shows, the notification belongs to the
      // same court.
      for (final r in kRoyalAvatars) {
        expect(
          RoyalNotificationSkin.forRoyal(r.id)!.variant,
          RoyalAppIcon.forRoyal[r.id],
          reason: '"${r.id}" notification gem disagrees with its app icon',
        );
      }
    });

    test('the accent is the shade-tuned gem, never the icon gem itself', () {
      // Measured on Android 12: the system darkens a light notification colour
      // for contrast against the pale shade, so the Princess's icon silver
      // (#CBD5E1) came out a flat grey. Guards a well-meaning "use the gem, it
      // matches the icon" change from draining the colour back out.
      for (final r in kRoyalAvatars) {
        final skin = RoyalNotificationSkin.forRoyal(r.id)!;
        expect(skin.accent, kRoyalNotificationAccent[skin.variant]);
        expect(
          skin.accent,
          isNot(kRoyalGemAccent[skin.variant]),
          reason: '"${r.id}" fell back to the light icon gem',
        );
      }
    });

    test('the named pairings hold: Princess silver, Prince golden', () {
      expect(RoyalNotificationSkin.forRoyal('princess')!.variant, 'silver');
      expect(RoyalNotificationSkin.forRoyal('prince')!.variant, 'golden');
    });

    test('no two courts are the same colour to the eye', () {
      // `!=` is not the bar. RoyalTheme.accentDeep passed an equality check
      // while the Sovereign (#8E1F2F) and the Dark Prince (#B02838) sat 2
      // degrees of hue apart — ΔE 12.7, which is one colour wearing two
      // names. Measure the real separation instead.
      for (final a in kRoyalAvatars) {
        for (final b in kRoyalAvatars) {
          if (a.id == b.id) continue;
          final d = _deltaE(
            RoyalNotificationSkin.forRoyal(a.id)!.accent,
            RoyalNotificationSkin.forRoyal(b.id)!.accent,
          );
          expect(
            d,
            greaterThan(25),
            reason: '"${a.id}" and "${b.id}" are too alike (ΔE '
                '${d.toStringAsFixed(1)}) — they read as the same court',
          );
        }
      }
    });

    test('accents are opaque and carry the white glyph inside them', () {
      for (final r in kRoyalAvatars) {
        final c = RoyalNotificationSkin.forRoyal(r.id)!.accent;
        expect(c.a, 1.0, reason: '"${r.id}" accent is translucent');
        final contrast = _contrastWithWhite(c);
        expect(
          contrast,
          greaterThan(4.4),
          reason: '"${r.id}" is too light behind a white mark '
              '(${contrast.toStringAsFixed(2)}:1)',
        );
      }
    });
  });

  group('gem accents (launcher icon / splash)', () {
    test('every launcher-icon variant has a gem colour', () {
      for (final v in RoyalAppIcon.all) {
        expect(kRoyalGemAccent.containsKey(v), isTrue, reason: 'no gem: $v');
      }
      expect(kRoyalGemAccent.length, RoyalAppIcon.all.length);
    });

    test('gem colours are opaque', () {
      for (final c in kRoyalGemAccent.values) {
        expect(c.a, 1.0);
      }
    });
  });

  group('RoyalNotificationSkin.royalIdForSeed', () {
    test('a royal seed names its royal', () {
      for (final r in kRoyalAvatars) {
        expect(RoyalNotificationSkin.royalIdForSeed(r.spriteIndex), r.id);
      }
    });

    test('a basic avatar seed is not a royal', () {
      expect(RoyalNotificationSkin.royalIdForSeed(0), isNull);
      expect(RoyalNotificationSkin.royalIdForSeed(-1), isNull);
    });
  });
}
