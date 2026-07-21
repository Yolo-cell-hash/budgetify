import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/services/app_icon_service.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';

/// Pure mapping/decision tests for the "match app icon to my royal" feature.
/// The platform side (AppIconService.sync / channel) needs a device and is
/// verified manually; only RoyalAppIcon is unit-testable here.
void main() {
  group('RoyalAppIcon mapping', () {
    test('every royal in the roster has a launcher-icon variant', () {
      for (final r in kRoyalAvatars) {
        expect(
          RoyalAppIcon.forRoyal.containsKey(r.id),
          isTrue,
          reason: 'royal "${r.id}" has no app-icon mapping',
        );
      }
    });

    test('the mapping only references known icon variants', () {
      for (final v in RoyalAppIcon.forRoyal.values) {
        expect(RoyalAppIcon.all, contains(v));
      }
    });

    test('each royal maps to a distinct icon (no two share one)', () {
      final vals = RoyalAppIcon.forRoyal.values.toList();
      expect(vals.toSet().length, vals.length);
    });

    test('the user-specified pairings hold', () {
      expect(RoyalAppIcon.forRoyal['darkprince'], 'ruby');
      expect(RoyalAppIcon.forRoyal['prince'], 'golden');
      expect(RoyalAppIcon.forRoyal['royalmedic'], 'emerald');
      expect(RoyalAppIcon.forRoyal['empress'], 'amethyst');
      expect(RoyalAppIcon.forRoyal['sovereign'], 'bronze');
      expect(RoyalAppIcon.forRoyal['princess'], 'silver');
    });
  });

  group('RoyalAppIcon.desiredIcon', () {
    int seedOf(String id) =>
        kRoyalAvatars.firstWhere((r) => r.id == id).spriteIndex;

    test('feature off → always the default icon (null)', () {
      expect(
        RoyalAppIcon.desiredIcon(seed: seedOf('darkprince'), enabled: false),
        isNull,
      );
      expect(RoyalAppIcon.desiredIcon(seed: 0, enabled: false), isNull);
    });

    test("feature on + equipped royal → that royal's icon", () {
      expect(
        RoyalAppIcon.desiredIcon(seed: seedOf('darkprince'), enabled: true),
        'ruby',
      );
      expect(
        RoyalAppIcon.desiredIcon(seed: seedOf('empress'), enabled: true),
        'amethyst',
      );
      expect(
        RoyalAppIcon.desiredIcon(seed: seedOf('princess'), enabled: true),
        'silver',
      );
    });

    test('feature on + non-royal avatar → default icon (null)', () {
      expect(RoyalAppIcon.desiredIcon(seed: 0, enabled: true), isNull);
      expect(RoyalAppIcon.desiredIcon(seed: -1, enabled: true), isNull);
    });
  });
}
