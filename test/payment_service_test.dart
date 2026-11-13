import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:undercroft/services/payment_service.dart';

class _Store extends Fake implements InAppPurchase {
  bool available = true;
  bool sheetShown = false;
  bool queried = false;
  bool checkoutStarted = false;
  bool restoreStarted = false;
  bool pendingCompletion = false;
  Object? completionError;
  int completionCount = 0;
  int streamListenCount = 0;
  Object? availabilityError;
  Object? queryError;
  Object? checkoutError;
  Object? restoreError;
  ProductDetailsResponse response = ProductDetailsResponse(
    productDetails: [],
    notFoundIDs: [handoverProductId],
  );
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  PurchaseStatus? finalStatus;

  @override
  Future<bool> isAvailable() async {
    if (availabilityError != null) throw availabilityError!;
    return available;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queried = true;
    expect(ids, {handoverProductId});
    if (queryError != null) throw queryError!;
    return response;
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    streamListenCount++;
    return updates.stream;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    checkoutStarted = true;
    expect(purchaseParam.productDetails.id, handoverProductId);
    if (checkoutError != null) throw checkoutError!;
    if (finalStatus != null) {
      updates.add([purchaseDetails(finalStatus!)]);
    }
    return sheetShown;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreStarted = true;
    if (restoreError != null) throw restoreError!;
    if (finalStatus != null) {
      updates.add([purchaseDetails(finalStatus!)]);
    }
  }

  PurchaseDetails purchaseDetails(PurchaseStatus status) {
    return PurchaseDetails(
      productID: handoverProductId,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'test',
      ),
      transactionDate: null,
      status: status,
    )..pendingCompletePurchase = pendingCompletion;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completionCount++;
    if (completionError != null) throw completionError!;
  }
}

ProductDetails _product(String id) => ProductDetails(
      id: id,
      title: 'Handover',
      description: 'Invite unlock',
      price: 'GBP 34.99',
      rawPrice: 34.99,
      currencyCode: 'GBP',
    );

void main() {
  group('native store diagnostics', () {
    late _Store store;
    setUp(() {
      store = _Store();
    });
    tearDown(() async {
      await PaymentService.stopPurchaseListener();
      await store.updates.close();
    });

    void offerProduct() {
      store.response = ProductDetailsResponse(
        productDetails: [_product(handoverProductId)],
        notFoundIDs: [],
      );
    }

    test('unavailable store is distinct from an empty product lookup',
        () async {
      store.available = false;
      final result = await PaymentService.purchaseHandoverUnlock(store: store);
      expect(result.outcome, PurchaseOutcome.unavailable);
      expect(result.diagnosticCode, 'store_unavailable');
      expect(store.queried, isFalse);
      expect(store.checkoutStarted, isFalse);
    });

    test('empty product response is reported without attempting payment',
        () async {
      final result = await PaymentService.purchaseHandoverUnlock(store: store);
      expect(result.diagnosticCode, 'product_not_found');
      expect(result.outcome, PurchaseOutcome.unavailable);
      expect(store.checkoutStarted, isFalse);
    });

    test('unexpected product cannot be purchased', () async {
      store.response = ProductDetailsResponse(
        productDetails: [_product('another.product')],
        notFoundIDs: [handoverProductId],
      );
      final result = await PaymentService.purchaseHandoverUnlock(store: store);
      expect(result.diagnosticCode, 'product_not_found');
      expect(store.checkoutStarted, isFalse);
    });

    test('query error retains only its code, not private error details',
        () async {
      store.response = ProductDetailsResponse(
        productDetails: [],
        notFoundIDs: [handoverProductId],
        error: IAPError(
          source: 'test',
          code: 'storekit_error',
          message: 'private-error-message',
          details: {'receipt': 'private-receipt'},
        ),
      );
      final result = await PaymentService.purchaseHandoverUnlock(store: store);
      expect(result.diagnosticCode, 'product_lookup:storekit_error');
      expect(result.message, isNot(contains('private')));
      expect(store.checkoutStarted, isFalse);
    });

    test('availability exception identifies the failing stage', () async {
      store.availabilityError = PlatformException(code: 'connection_failed');
      final result = await PaymentService.purchaseHandoverUnlock(store: store);
      expect(result.outcome, PurchaseOutcome.failed);
      expect(result.diagnosticCode, 'store_availability:connection_failed');
      expect(store.queried, isFalse);
    });

    test('lookup exception identifies the failing stage', () async {
      store.queryError = PlatformException(code: 'network_error');
      final result = await PaymentService.purchaseHandoverUnlock(store: store);
      expect(result.outcome, PurchaseOutcome.failed);
      expect(result.diagnosticCode, 'product_lookup:network_error');
      expect(store.checkoutStarted, isFalse);
    });

    test('failed sheet presentation keeps the app listener active', () async {
      offerProduct();
      final result = await PaymentService.purchaseHandoverUnlock(store: store);
      expect(result.outcome, PurchaseOutcome.failed);
      expect(result.diagnosticCode, 'checkout_failed');
      expect(store.updates.hasListener, isTrue);
    });

    test('checkout exception keeps the app listener active', () async {
      offerProduct();
      store.checkoutError = PlatformException(code: 'sheet_error');
      final result = await PaymentService.purchaseHandoverUnlock(store: store);
      expect(result.diagnosticCode, 'checkout:sheet_error');
      expect(store.updates.hasListener, isTrue);
    });

    test('restore succeeds when the handover product is returned', () async {
      store.finalStatus = PurchaseStatus.restored;

      final result = await PaymentService.restoreHandoverUnlock(
        store: store,
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.outcome, PurchaseOutcome.purchased);
      expect(store.restoreStarted, isTrue);
      expect(store.updates.hasListener, isTrue);
    });

    test('restore distinguishes no matching purchase', () async {
      final result = await PaymentService.restoreHandoverUnlock(
        store: store,
        timeout: const Duration(milliseconds: 5),
      );

      expect(result.outcome, PurchaseOutcome.noPurchasesFound);
      expect(result.diagnosticCode, 'restore_no_matching_purchase');
      expect(store.updates.hasListener, isTrue);
    });

    test('restore exception includes the failing stage', () async {
      store.restoreError = PlatformException(code: 'restore_error');

      final result = await PaymentService.restoreHandoverUnlock(
        store: store,
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.outcome, PurchaseOutcome.failed);
      expect(result.diagnosticCode, 'restore:restore_error');
      expect(store.updates.hasListener, isTrue);
    });

    for (final entry in {
      PurchaseStatus.purchased: PurchaseOutcome.purchased,
      PurchaseStatus.canceled: PurchaseOutcome.cancelled,
    }.entries) {
      test('${entry.key.name} keeps its existing outcome', () async {
        offerProduct();
        store.sheetShown = true;
        store.finalStatus = entry.key;
        final result =
            await PaymentService.purchaseHandoverUnlock(store: store);
        expect(result.outcome, entry.value);
        expect(result.diagnosticCode, isNull);
        expect(store.updates.hasListener, isTrue);
      });
    }

    test('localized price comes from the store product', () async {
      offerProduct();

      expect(
        await PaymentService.lookupHandoverPrice(store: store),
        'GBP 34.99',
      );
    });

    test('pending purchase completion errors are contained', () async {
      offerProduct();
      store.sheetShown = true;
      store.finalStatus = PurchaseStatus.purchased;
      store.pendingCompletion = true;
      store.completionError = StateError('completion failed');

      final result = await PaymentService.purchaseHandoverUnlock(store: store);
      await Future<void>.delayed(Duration.zero);

      expect(result.outcome, PurchaseOutcome.purchased);
      expect(store.completionCount, 1);
    });

    test('app listener unlock callback handles restored purchases', () async {
      var unlockCount = 0;
      await PaymentService.startPurchaseListener(
        store: store,
        onHandoverUnlocked: () => unlockCount++,
      );
      await PaymentService.startPurchaseListener(store: store);
      store.updates.add([store.purchaseDetails(PurchaseStatus.restored)]);
      await Future<void>.delayed(Duration.zero);

      expect(unlockCount, 1);
      expect(store.streamListenCount, 1);
      expect(store.updates.hasListener, isTrue);
    });
  }, skip: kIsWeb);
}
