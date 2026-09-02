import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/models/plus_products.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/billing_service.dart';
import 'package:budget_tracker/services/entitlement_service.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/avatar_picker_sheet.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';

/// A royal that isn't waiting on a streak pick is for SALE, and the court
/// sheet has to say so honestly: Play's own price when the store answers, the
/// catalogue constant until then, and a struck-through "was" price only when
/// Play is really about to charge less.
///
/// The free route never closes — a streak pick still takes a royal for
/// nothing, and where a pick is waiting the picker must not mention money at
/// all.

/// An open store, quoting whatever the test seeds. The CLOSED store is the
/// shipped [UnavailableBillingGateway] itself, so no flag is needed for it.
class _FakeGateway implements BillingGateway {
  final Map<String, StorePrice> priceList;

  /// The product the store was last asked to sell.
  String? lastPurchased;

  _FakeGateway({this.priceList = const <String, StorePrice>{}});

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<BillingPurchase>> queryPurchases() async =>
      const <BillingPurchase>[];

  @override
  Future<BillingResult> launchPurchase(String productId,
      {bool preferOffer = false, String? replaces}) async {
    lastPurchased = productId;
    // A real store hands the receipt back with the verdict; the fake must
    // too, or the grant path never sees a purchase time.
    return BillingResult(
      BillingOutcome.success,
      purchase: BillingPurchase(
        productId: productId,
        purchaseToken: 'tok_$productId',
        purchaseTimeMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<Map<String, StorePrice>> queryPrices(Iterable<String> productIds,
          {bool preferOffer = false}) async =>
      priceList;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = AppStrings(AppLanguage.english);
  final royal = kRoyalAvatars.first; // The Sovereign, sprite 18

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EntitlementService().resetForTest();
    // The production restart is dated in the future, which would put every
    // seeded install back inside its free window. Neutralised so these tests
    // read the calendar they pin, not the one the clock happens to be on.
    EntitlementService.debugTrialRestartAt = DateTime.utc(2000);
    BillingService().gateway = const UnavailableBillingGateway();
  });

  /// An ordinary mid-July day: no festival window, so royals are quoted at the
  /// everyday price. Pinned because the price is calendar-dependent.
  DateTime plainDay() => DateTime(2026, 7, 15);

  /// Inside the Diwali 2026 window (anchor 8 Nov, opens four days earlier).
  DateTime offerDay() => DateTime(2026, 11, 6);

  Widget host({
    Set<String> unlockedRoyals = const {},
    int picks = 0,
    DateTime Function()? now,
    void Function(GamiProfile?)? onResult,
  }) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<AppPreferences>(create: (_) => AppPreferences()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final edited = await showAvatarPicker(
                      ctx,
                      const GamiProfile(avatarKind: 'pixel', avatarValue: '0'),
                      unlockedRoyals: unlockedRoyals,
                      royalPicksAvailable: picks,
                      nowSource: now ?? plainDay,
                    );
                    onResult?.call(edited);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  /// Open the picker and then [royal]'s court sheet.
  Future<void> openCourtSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final tile = find.byWidgetPredicate(
        (w) => w is AnimatedRoyalAvatar && w.royal.id == royal.id);
    await tester.ensureVisible(tile.first);
    await tester.pump();
    await tester.tap(tile.first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder struckThrough(String text) => find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data == text &&
            w.style?.decoration == TextDecoration.lineThrough,
      );

  testWidgets('a locked royal carries its price, not a promise',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Every royal tile is for sale, so each pill quotes the everyday price.
    expect(find.text('₹49'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the court sheet quotes the price and offers to sell',
      (tester) async {
    await tester.pumpWidget(host());
    await openCourtSheet(tester);

    expect(find.text(en.royalPriceCaption), findsOneWidget);
    expect(find.text(en.buyRoyalCta('₹49')), findsOneWidget);
    // The free route stays visible — paying is never the only way in.
    expect(find.text(en.royalLockedSheetNote), findsOneWidget);
    // Nothing is struck through on an ordinary day.
    expect(struckThrough('₹49'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Play’s own price replaces the catalogue constant',
      (tester) async {
    BillingService().gateway = _FakeGateway(
      priceList: {
        royalProductId(royal.id):
            const StorePrice(formatted: 'Rp 15.000', amount: 15000),
      },
    );
    await tester.pumpWidget(host());
    await openCourtSheet(tester);

    // The store answered for the Sovereign, so his sheet quotes Play. The
    // other royals went unanswered and keep the fallback.
    expect(find.text(en.buyRoyalCta('Rp 15.000')), findsOneWidget);
    expect(find.text('Rp 15.000'), findsWidgets);
  });

  testWidgets('an offer window strikes the everyday price through',
      (tester) async {
    BillingService().gateway = _FakeGateway(
      priceList: {
        royalProductId(royal.id):
            const StorePrice(formatted: '₹29', amount: 29),
      },
    );
    await tester.pumpWidget(host(now: offerDay));
    await openCourtSheet(tester);

    expect(struckThrough('₹49'), findsOneWidget);
    expect(find.text(en.buyRoyalCta('₹29')), findsOneWidget);
  });

  testWidgets('an offer window with no Console discount claims nothing',
      (tester) async {
    // Our calendar says "sale", the Play Console does not. Quoting a saving
    // here would advertise a discount Play won't honour.
    BillingService().gateway = _FakeGateway(
      priceList: {
        royalProductId(royal.id):
            const StorePrice(formatted: '₹49', amount: 49),
      },
    );
    await tester.pumpWidget(host(now: offerDay));
    await openCourtSheet(tester);

    expect(struckThrough('₹49'), findsNothing);
    expect(find.text(en.buyRoyalCta('₹49')), findsOneWidget);
  });

  testWidgets('buying grants ownership, equips, and survives Save',
      (tester) async {
    final gateway = _FakeGateway();
    BillingService().gateway = gateway;
    GamiProfile? result;
    await tester.pumpWidget(host(onResult: (p) => result = p));
    await openCourtSheet(tester);

    // The court sheet scrolls on a short viewport; bring the CTA up first.
    await tester.ensureVisible(find.text(en.buyRoyalCta('₹49')));
    await tester.pump();
    await tester.tap(find.text(en.buyRoyalCta('₹49')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The store was asked for THIS royal's product, and ownership is recorded
    // by the purchase itself — not by Save, so backing out can't lose it.
    expect(gateway.lastPurchased, royalProductId(royal.id));
    await EntitlementService().initialize();
    expect(EntitlementService().ownsRoyal(royal.id), isTrue);

    // The sheet closed and the royal is equipped, awaiting Save.
    expect(find.text(en.buyRoyalCta('₹49')), findsNothing);
    await tester.ensureVisible(find.text(en.commonSave));
    await tester.pump();
    await tester.tap(find.text(en.commonSave));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, isNotNull);
    expect(result!.avatarValue, '${royal.spriteIndex}');
  });

  testWidgets('a closed store says so and keeps the sheet open',
      (tester) async {
    await tester.pumpWidget(host()); // default: UnavailableBillingGateway
    await openCourtSheet(tester);

    // The court sheet scrolls on a short viewport; bring the CTA up first.
    await tester.ensureVisible(find.text(en.buyRoyalCta('₹49')));
    await tester.pump();
    await tester.tap(find.text(en.buyRoyalCta('₹49')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(en.plusStoreUnavailable), findsOneWidget);
    expect(find.text(en.buyRoyalCta('₹49')), findsOneWidget);
    await EntitlementService().initialize();
    expect(EntitlementService().ownsRoyal(royal.id), isFalse);
  });

  testWidgets('a waiting pick beats money — the sheet never mentions a price',
      (tester) async {
    await tester.pumpWidget(host(picks: 1));
    await openCourtSheet(tester);

    expect(find.text(en.unlockRoyalCta), findsOneWidget);
    expect(find.text(en.buyRoyalCta('₹49')), findsNothing);
    expect(find.text('₹49'), findsNothing);
  });

  testWidgets('an owned royal is equipped, never re-sold', (tester) async {
    await tester.pumpWidget(host(unlockedRoyals: {royal.id}));
    await openCourtSheet(tester);

    expect(find.text(en.equipRoyal), findsOneWidget);
    expect(find.text(en.buyRoyalCta('₹49')), findsNothing);
  });
}
