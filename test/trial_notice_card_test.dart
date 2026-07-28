import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/screens/plus_screen.dart';
import 'package:budget_tracker/services/entitlement_service.dart';
import 'package:budget_tracker/widgets/trial_notice_card.dart';

/// The card sits at the top of Home for the whole life of the app, so the
/// property that matters most is that it renders to nothing at all for the
/// ~76 days it has nothing to say.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final svc = EntitlementService();

  int daysAgo(int d) =>
      DateTime.now().subtract(Duration(days: d)).millisecondsSinceEpoch;

  Future<void> seedDaysIn(int days) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setInt('entitlement_first_launch_at', daysAgo(days));
    svc.resetForTest();
    EntitlementService.debugTrialRestartAt = DateTime.utc(2000);
    await svc.initialize();
  }

  tearDown(() => EntitlementService.debugTrialRestartAt = null);

  Widget host() => ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: TrialNoticeCard())),
        ),
      );

  testWidgets('renders nothing for most of the free window', (tester) async {
    await seedDaysIn(30); // 60 days left
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.byType(Container), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appears inside the last fortnight and names the days left',
      (tester) async {
    await seedDaysIn(80); // ~10 days left
    await tester.pumpWidget(host());
    await tester.pump();

    final en = AppStrings(AppLanguage.english);
    expect(find.text(en.trialEndingTitle(svc.trialDaysLeft)), findsOneWidget);
    // Leads with what survives, not with what stops.
    expect(find.text(en.trialEndingBody), findsOneWidget);
    expect(find.text(en.trialEndingCta), findsOneWidget);
  });

  testWidgets('dismissing hides it and records the dismissal', (tester) async {
    await seedDaysIn(80);
    await tester.pumpWidget(host());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    final en = AppStrings(AppLanguage.english);
    expect(find.text(en.trialEndingCta), findsNothing);
    expect(svc.pendingTrialNotice, isNull);
  });

  testWidgets('the CTA opens the paywall', (tester) async {
    await seedDaysIn(80);
    await tester.pumpWidget(host());
    await tester.pump();

    final en = AppStrings(AppLanguage.english);
    await tester.tap(find.text(en.trialEndingCta));
    await tester.pump(); // let the async handler start the push
    // Fixed span rather than pumpAndSettle: the paywall's CTA shimmer repeats
    // forever, so the tree never settles.
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PlusScreen), findsOneWidget);
  });

  testWidgets('stays hidden for someone who has already paid', (tester) async {
    await seedDaysIn(80);
    await svc.registerPlusPurchase('plus_lifetime');
    await tester.pumpWidget(host());
    await tester.pump();

    final en = AppStrings(AppLanguage.english);
    expect(find.text(en.trialEndingCta), findsNothing);
  });
}
