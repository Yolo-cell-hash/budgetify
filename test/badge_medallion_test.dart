import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:budget_tracker/models/achievement.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/avatars.dart';
import 'package:budget_tracker/widgets/badge_medallion.dart';
import 'package:budget_tracker/widgets/profile_share_card.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<LocaleProvider>(
      create: (_) => LocaleProvider(),
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100)); // not settle: badges loop
}

void main() {
  testWidgets('earned medallion shows its emblem and no lock', (tester) async {
    await _pump(
      tester,
      const BadgeMedallion(
          rarity: BadgeRarity.gold, emblem: '🔥', earned: true, animate: false),
    );
    expect(find.text('🔥'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('locked medallion shows a lock', (tester) async {
    await _pump(
      tester,
      const BadgeMedallion(
          rarity: BadgeRarity.diamond, emblem: '💎', earned: false),
    );
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });

  testWidgets('legacy emoji avatar migrates to its pixel sprite',
      (tester) async {
    // Emoji avatars are retired: a stored emoji kind renders the pixel
    // character it deterministically maps to — never the raw glyph.
    await _pump(
        tester, const AvatarView(kind: 'emoji', value: '🦊', size: 60));
    expect(find.text('🦊'), findsNothing);
    expect(
      find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PixelAvatarPainter),
      findsOneWidget,
    );
  });

  testWidgets('pixel avatar paints via PixelAvatarPainter', (tester) async {
    await _pump(
        tester, const AvatarView(kind: 'pixel', value: '3', size: 60));
    expect(
      find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PixelAvatarPainter),
      findsOneWidget,
    );
  });

  testWidgets('profile card shows name, streak and brand', (tester) async {
    await _pump(
      tester,
      const ProfileShareCard(
        profile: GamiProfile(username: 'Riya'),
        currentStreak: 12,
        titles: [],
        showcased: [
          (rarity: BadgeRarity.gold, emblem: '💎', label: '₹8L', group: 'Money Tracked')
        ],
        trophyCount: 7,
        animate: false,
      ),
    );
    expect(find.text('Riya'), findsOneWidget);
    expect(find.textContaining('day streak'), findsOneWidget);
    expect(find.text('Budgetify'), findsOneWidget);
  });
}
