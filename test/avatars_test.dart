import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/models/achievement.dart';
import 'package:budget_tracker/widgets/avatars.dart';

void main() {
  group('Pixel avatar sprites', () {
    test('every sprite is a well-formed grid (equal-length rows)', () {
      for (var i = 0; i < kPixelAvatarCount; i++) {
        final rows = debugSpriteRows(i);
        expect(rows, isNotEmpty, reason: 'sprite $i');
        final cols = rows.first.length;
        for (var r = 0; r < rows.length; r++) {
          expect(rows[r].length, cols,
              reason: 'sprite $i row $r has ${rows[r].length} cols, want $cols');
        }
      }
    });

    test('every sprite has a halo gradient', () {
      for (var i = 0; i < kPixelAvatarCount; i++) {
        expect(pixelHaloOf(i).length, 2, reason: 'sprite $i');
      }
    });
  });

  group('Elite avatars', () {
    test('occupy the sprite slots right after the free characters', () {
      expect(kFreePixelAvatarCount + kEliteAvatars.length, kPixelAvatarCount);
      for (var i = 0; i < kEliteAvatars.length; i++) {
        expect(kEliteAvatars[i].spriteIndex, kFreePixelAvatarCount + i,
            reason: kEliteAvatars[i].id);
      }
    });

    test('every unlock badge id resolves in the achievement catalog', () {
      for (final e in kEliteAvatars) {
        final b = badgeById(e.badgeId);
        expect(b, isNotNull, reason: '${e.id} → ${e.badgeId}');
        // Elite art is prestige: gate only on the two rarest tiers.
        expect(
          b!.group.tiers[b.tierIndex].rarity.index >=
              BadgeRarity.ruby.index - 1,
          isTrue,
          reason: '${e.id} should be gated behind a top-tier badge',
        );
      }
    });

    test('free sprite indexes resolve to no elite character', () {
      for (var i = 0; i < kFreePixelAvatarCount; i++) {
        expect(eliteAvatarAt(i), isNull, reason: 'sprite $i');
      }
      for (final e in kEliteAvatars) {
        expect(eliteAvatarAt(e.spriteIndex)?.id, e.id);
      }
    });
  });
}
