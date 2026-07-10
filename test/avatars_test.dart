import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/avatars.dart';
import 'package:budget_tracker/widgets/profile_share_card.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';

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
      expect(
          kFreePixelAvatarCount + kEliteAvatars.length + kRoyalAvatars.length,
          kPixelAvatarCount);
      for (var i = 0; i < kEliteAvatars.length; i++) {
        expect(kEliteAvatars[i].spriteIndex, kFreePixelAvatarCount + i,
            reason: kEliteAvatars[i].id);
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

  group('Royal avatars', () {
    test('occupy the sprite slots right after the elite block', () {
      final eliteEnd = kFreePixelAvatarCount + kEliteAvatars.length;
      expect(eliteEnd + kRoyalAvatars.length, kPixelAvatarCount);
      for (var i = 0; i < kRoyalAvatars.length; i++) {
        expect(kRoyalAvatars[i].spriteIndex, eliteEnd + i,
            reason: kRoyalAvatars[i].id);
      }
      // No overlap with the elite/free resolvers.
      for (final r in kRoyalAvatars) {
        expect(eliteAvatarAt(r.spriteIndex), isNull, reason: r.id);
        expect(royalAvatarAt(r.spriteIndex)?.id, r.id);
      }
      expect(royalAvatarAt(0), isNull);
    });

    test('every animation frame stays on the base grid', () {
      for (final r in kRoyalAvatars) {
        final cols = r.rows.first.length;
        expect(r.eyeRowWhites, inInclusiveRange(0, r.rows.length - 1));
        expect(r.eyeRowIris, inInclusiveRange(0, r.rows.length - 1));
        for (final variant in [r.eyesClosed, r.eyesLeft, r.eyesRight]) {
          expect(variant.length, 2, reason: r.id);
          for (final row in variant) {
            expect(row.length, cols, reason: '${r.id}: "$row"');
          }
        }
        // Every glyph used by the base art resolves to a colour.
        for (final row in r.rows) {
          for (final ch in row.split('')) {
            if (ch == '.') continue;
            expect(r.palette[ch], isNotNull,
                reason: '${r.id}: glyph "$ch" has no palette entry');
          }
        }
      }
    });

    test('royal halos come from the royal theme', () {
      for (final r in kRoyalAvatars) {
        expect(pixelHaloOf(r.spriteIndex), r.theme.halo, reason: r.id);
      }
    });

    testWidgets('AvatarView routes royal seeds to the living avatar',
        (tester) async {
      final seed = '${kRoyalAvatars.first.spriteIndex}';
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AvatarView(kind: 'pixel', value: seed, accent: 0, size: 84),
          ),
        ),
      );
      expect(find.byType(AnimatedRoyalAvatar), findsOneWidget);
      // Let the spawn finish and the idle loop tick through a blink, a
      // glance and the wave window — no layout/paint exceptions allowed.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('profile card adopts the equipped royal theme',
        (tester) async {
      final royal = kRoyalAvatars.first;
      await tester.pumpWidget(
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
          child: MaterialApp(
            home: SingleChildScrollView(
              child: ProfileShareCard(
                profile: GamiProfile(
                  username: 'Jay',
                  avatarKind: 'pixel',
                  avatarValue: '${royal.spriteIndex}',
                ),
                currentStreak: 12,
                titles: const [],
                showcased: const [],
                trophyCount: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      // The card paints the royal aura and hosts the living avatar.
      expect(find.byType(AnimatedRoyalAvatar), findsOneWidget);
      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ProfileShareCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final deco = card.decoration! as BoxDecoration;
      expect((deco.gradient! as LinearGradient).colors,
          royal.theme.cardGradient);
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    });
  });
}
