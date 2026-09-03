import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/models/achievement.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/billing_service.dart';
import 'package:budget_tracker/services/entitlement_service.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/avatar_picker_sheet.dart';
import 'package:budget_tracker/widgets/avatars.dart';

/// ELITE characters are earned again.
///
/// They shipped gated, were handed to everyone in v1.36.0, and are gated once
/// more here — on achievement badges, not money. The tier only means anything
/// while wearing one says something about what the wearer did; ten free
/// characters in a row marked ELITE is just a second free row with better art.
///
/// What these tests hold to:
///   * every elite names a badge the catalogue actually mints (a typo here
///     would lock a character behind nothing, forever);
///   * the ladder stays a ladder — ten distinct badges, no single habit
///     opening the whole row, and a reachable first rung;
///   * the picker locks and opens the right ones, and says why;
///   * nobody who chose an elite while it was free loses their face.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = AppStrings(AppLanguage.english);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EntitlementService().resetForTest();
    EntitlementService.debugTrialRestartAt = DateTime.utc(2000);
    BillingService().gateway = const UnavailableBillingGateway();
  });

  group('the ladder', () {
    test('every elite is gated on a badge the catalogue really mints', () {
      for (final e in kEliteAvatars) {
        final badge = badgeById(e.badgeId);
        expect(badge, isNotNull,
            reason: '${e.id} names ${e.badgeId}, which no group mints');
        expect(badge!.tierIndex, lessThan(badge.group.tiers.length),
            reason: e.id);
      }
    });

    test('no badge opens two characters', () {
      final ids = kEliteAvatars.map((e) => e.badgeId).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'a shared badge would open two elites in one stroke');
    });

    test('ten different ladders, so no single habit opens the row', () {
      final groups =
          kEliteAvatars.map((e) => badgeById(e.badgeId)!.group.id).toSet();
      // Nine, not ten: the streak ladder deliberately carries both ends of the
      // climb — a 30-day first rung and a 200-day last one.
      expect(groups.length, greaterThanOrEqualTo(9));
    });

    test('the first rung is reachable and the last one is not cheap', () {
      final first = badgeById(kEliteAvatars.first.badgeId)!;
      final last = badgeById(kEliteAvatars.last.badgeId)!;
      // The original gating asked for six DIAMOND badges and was scrapped
      // rather than tuned, because a wall nobody clears is indistinguishable
      // from a wall with nothing behind it.
      expect(first.group.tiers[first.tierIndex].rarity, BadgeRarity.copper);
      expect(
        last.group.tiers[last.tierIndex].rarity.index,
        greaterThanOrEqualTo(BadgeRarity.platinum.index),
      );
      for (final e in kEliteAvatars) {
        final b = badgeById(e.badgeId)!;
        expect(b.group.tiers[b.tierIndex].rarity, isNot(BadgeRarity.diamond),
            reason: '${e.id} is back behind a diamond — that is the mistake '
                'the first gating made');
      }
    });

    test('difficulty climbs with display order', () {
      // Sprite order is display order, and display order is meant to read
      // left-to-right as a climb. Rarity is the catalogue's own difficulty
      // scale, so it is the thing to check.
      final rarities = [
        for (final e in kEliteAvatars)
          badgeById(e.badgeId)!.group.tiers[badgeById(e.badgeId)!.tierIndex]
              .rarity
              .index,
      ];
      // Not strictly monotonic — Category Explorer's top rung is gold but
      // takes an afternoon of intent — so the check is that the back half
      // outranks the front half rather than that every step goes up.
      final front = rarities.take(5).reduce((a, b) => a + b);
      final back = rarities.skip(5).reduce((a, b) => a + b);
      expect(back, greaterThan(front));
    });
  });

  group('the legacy ledger', () {
    test('loading a profile that wears an elite banks it, once and for good',
        () async {
      final svc = GamificationService();
      final worn = kEliteAvatars.last;
      await svc.saveProfile(
        GamiProfile(avatarKind: 'pixel', avatarValue: '${worn.spriteIndex}'),
      );

      expect(await svc.legacyEliteSlots(), isEmpty, reason: 'not read yet');
      await svc.loadProfile();
      expect(await svc.legacyEliteSlots(), {worn.spriteIndex});

      // ...and it survives moving to something else, which is the whole point.
      await svc.saveProfile(
        const GamiProfile(avatarKind: 'pixel', avatarValue: '0'),
      );
      await svc.loadProfile();
      expect(await svc.legacyEliteSlots(), {worn.spriteIndex});
    });

    test('a plain avatar banks nothing', () async {
      final svc = GamificationService();
      await svc.saveProfile(
        const GamiProfile(avatarKind: 'pixel', avatarValue: '0'),
      );
      await svc.loadProfile();
      expect(await svc.legacyEliteSlots(), isEmpty);
    });

    test('the ledger rides the backup like every other key in the blob',
        () async {
      final svc = GamificationService();
      final worn = kEliteAvatars.first;
      await svc.saveProfile(
        GamiProfile(avatarKind: 'pixel', avatarValue: '${worn.spriteIndex}'),
      );
      await svc.loadProfile();
      final exported = await svc.exportSettings();

      SharedPreferences.setMockInitialValues({});
      final fresh = GamificationService();
      expect(await fresh.legacyEliteSlots(), isEmpty);
      await fresh.importSettings(exported);
      expect(await fresh.legacyEliteSlots(), {worn.spriteIndex});
    });
  });

  group('the picker', () {
    /// Stats that earn exactly the first elite's badge (one fully-tagged
    /// month) and nothing else on the row.
    const firstRungOnly = GamiStats(fullyTaggedMonths: 1);

    Widget host({
      required GamiProfile initial,
      GamiStats? stats,
      Set<int> legacy = const {},
    }) =>
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<AppPreferences>(
                create: (_) => AppPreferences()),
          ],
          child: MaterialApp(
            theme: AppTheme.of(AppThemeVariant.dark),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showAvatarPicker(
                      ctx,
                      initial,
                      stats: stats,
                      legacyEliteSlots: legacy,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// The tile for [e]: its avatar art inside the picker's ELITE row.
    Finder tileArt(EliteAvatar e) => find.byWidgetPredicate(
          (w) =>
              w is AvatarView &&
              w.value == '${e.spriteIndex}' &&
              w.size == 46,
        );

    /// Whether the tile is drawn dimmed — the lock's visible half.
    bool dimmed(WidgetTester tester, EliteAvatar e) {
      final op = tester.widgetList<Opacity>(
        find.ancestor(of: tileArt(e), matching: find.byType(Opacity)),
      );
      return op.any((o) => o.opacity < 1);
    }

    testWidgets('an earned badge opens its character; the rest stay locked',
        (tester) async {
      final earned = kEliteAvatars.first;
      final locked = kEliteAvatars.last;
      await tester.pumpWidget(host(
        initial: const GamiProfile(avatarKind: 'pixel', avatarValue: '0'),
        stats: firstRungOnly,
      ));
      await openPicker(tester);

      expect(dimmed(tester, earned), isFalse, reason: earned.id);
      expect(dimmed(tester, locked), isTrue, reason: locked.id);
      // ...and the section says where the user stands, as a score.
      expect(find.text(en.eliteEarnedCount(1, kEliteAvatars.length)),
          findsOneWidget);
    });

    testWidgets('tapping a locked elite explains it instead of equipping it',
        (tester) async {
      final locked = kEliteAvatars.last;
      GamiProfile? saved;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<AppPreferences>(
                create: (_) => AppPreferences()),
          ],
          child: MaterialApp(
            theme: AppTheme.of(AppThemeVariant.dark),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      saved = await showAvatarPicker(
                        ctx,
                        const GamiProfile(
                            avatarKind: 'pixel', avatarValue: '0'),
                        stats: firstRungOnly,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await openPicker(tester);

      // The ELITE row sits below the fold of the picker's scroll view.
      await tester.ensureVisible(tileArt(locked).first);
      await tester.pump();
      await tester.tap(tileArt(locked).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The sheet names the badge and the rung, not just "locked".
      final badge = badgeById(locked.badgeId)!;
      final tier = badge.group.tiers[badge.tierIndex];
      expect(
        find.text(en.eliteAvatarLock(
          en.achievementName(badge.group.id),
          en.tierBadgeLabel(tier.label),
        )),
        findsOneWidget,
      );
      // ...and how far off it is, which is what makes it a goal.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Close the explainer, then Save: the locked character was never taken.
      // Explicit pumps, not pumpAndSettle — the picker holds a breathing royal
      // avatar, a preview reel and a strolling character, so it never settles.
      await tester.ensureVisible(find.text(en.commonClose));
      await tester.pump();
      await tester.tap(find.text(en.commonClose));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text(en.commonSave));
      await tester.pump();
      await tester.tap(find.text(en.commonSave));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(saved?.avatarValue, '0');
    });

    testWidgets('an elite chosen while the tier was free is never confiscated',
        (tester) async {
      // Elites were ungated for two months. Someone who picked one then has no
      // badge for it, and taking it back would read as a bug or a shakedown.
      final worn = kEliteAvatars.last; // the platinum one, certainly unearned
      await tester.pumpWidget(host(
        initial: GamiProfile(
          avatarKind: 'pixel',
          avatarValue: '${worn.spriteIndex}',
        ),
        stats: const GamiStats(),
      ));
      await openPicker(tester);

      expect(dimmed(tester, worn), isFalse);
      // Only that one: the next locked elite is still locked.
      final other = kEliteAvatars.first;
      expect(dimmed(tester, other), isTrue);
      expect(find.text(en.eliteEarnedCount(1, kEliteAvatars.length)),
          findsOneWidget);
    });

    testWidgets('a banked elite stays open after switching away from it',
        (tester) async {
      // The reprieve has to survive leaving. Keyed to the CURRENT avatar alone
      // it would be a trap: try a free character for an afternoon, save, and
      // the elite worn legitimately for two months is gone with no way back.
      final banked = kEliteAvatars.last;
      await tester.pumpWidget(host(
        // Now wearing a plain character — the elite is only in the ledger.
        initial: const GamiProfile(avatarKind: 'pixel', avatarValue: '0'),
        stats: const GamiStats(),
        legacy: {banked.spriteIndex},
      ));
      await openPicker(tester);

      expect(dimmed(tester, banked), isFalse);
      expect(dimmed(tester, kEliteAvatars.first), isTrue);
    });

    testWidgets('no stats to hand reads as locked, not as open',
        (tester) async {
      await tester.pumpWidget(host(
        initial: const GamiProfile(avatarKind: 'pixel', avatarValue: '0'),
      ));
      await openPicker(tester);
      for (final e in kEliteAvatars) {
        expect(dimmed(tester, e), isTrue, reason: e.id);
      }
      expect(find.text(en.eliteEarnedCount(0, kEliteAvatars.length)),
          findsOneWidget);
    });
  });
}
