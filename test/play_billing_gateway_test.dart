import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:budget_tracker/services/billing_service.dart';
import 'package:budget_tracker/services/play_billing_gateway.dart';

/// A stand-in store we can push verdicts through, so the gateway's stream
/// handling is exercised without a platform channel.
class _FakeIap implements InAppPurchase {
  final _updates = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  bool launchSucceeds = true;
  List<ProductDetails> catalogue = const [];

  void push(List<PurchaseDetails> details) => _updates.add(details);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _updates.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: catalogue.where((p) => ids.contains(p.id)).toList(),
        notFoundIDs: const [],
      );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      launchSucceeds;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async => launchSucceeds;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<String> countryCode() async => 'IN';

  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() =>
      throw UnimplementedError();
}

ProductDetails _product(String id, double price) => ProductDetails(
      id: id,
      title: id,
      description: id,
      price: '₹${price.toStringAsFixed(0)}',
      rawPrice: price,
      currencyCode: 'INR',
    );

/// A verdict Play reports with an EMPTY purchase list.
///
/// The plugin synthesises exactly this — `productID: ''` — for a buyer backing
/// out, for ITEM_ALREADY_OWNED, and for most billing errors. It is the shape
/// that used to strand the purchase future.
PurchaseDetails _productless(PurchaseStatus status) => PurchaseDetails(
      purchaseID: '',
      productID: '',
      status: status,
      transactionDate: null,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'google_play',
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeIap iap;
  late PlayBillingGateway gateway;

  setUp(() {
    iap = _FakeIap();
    iap.catalogue = [_product('plus_monthly', 49)];
    gateway = PlayBillingGateway(iap: iap);
  });

  /// Regression: these used to hang for the full five-minute timeout, because
  /// the verdict carries no product id and the waiter is keyed by one. The buy
  /// button spun long after the buyer had already backed out of Play's sheet.
  for (final (status, expected, label) in [
    (PurchaseStatus.canceled, BillingOutcome.cancelled, 'backing out'),
    (PurchaseStatus.error, BillingOutcome.error, 'ITEM_ALREADY_OWNED'),
  ]) {
    test('$label resolves the purchase instead of stranding it', () async {
      final pending = gateway.launchPurchase('plus_monthly');

      // Let launchPurchase get as far as awaiting the store's verdict.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      iap.push([_productless(status)]);

      final result = await pending.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw StateError('purchase future never resolved'),
      );
      expect(result.outcome, expected);
      expect(result.purchase, isNull, reason: 'nothing was bought');
    });
  }

  test('a real purchase still resolves by product id', () async {
    final pending = gateway.launchPurchase('plus_monthly');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    iap.push([
      PurchaseDetails(
        purchaseID: 'gpa.1',
        productID: 'plus_monthly',
        status: PurchaseStatus.purchased,
        transactionDate: '1756800000000',
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'token-1',
          source: 'google_play',
        ),
      ),
    ]);

    final result = await pending.timeout(const Duration(seconds: 2));
    expect(result.outcome, BillingOutcome.success);
    expect(result.purchase?.productId, 'plus_monthly');
    expect(result.purchase?.purchaseToken, 'token-1',
        reason: 'the receipt must travel back so the grant can anchor on it');
  });

  test('an unknown product never launches a flow', () async {
    final result = await gateway.launchPurchase('plus_nonexistent');
    expect(result.outcome, BillingOutcome.unavailable);
  });

  tearDown(() => gateway.dispose());
}
