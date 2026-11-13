import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../utils/log.dart';

/// The one-off unlock that lets an estate owner bring other people into it.
///
/// A non-consumable, so it is bought once per Apple or Google account and can
/// be restored. This string has to match the product created in App Store
/// Connect and the Play Console exactly; it cannot be changed afterwards.
const String handoverProductId = 'com.kierenpound.undercroft.handover';

/// How a purchase attempt ended, so the UI can explain it without knowing
/// anything about StoreKit or Play Billing.
enum PurchaseOutcome {
  /// Paid, or already owned. The gate can open.
  purchased,

  /// The user backed out of the payment sheet. Not a failure.
  cancelled,

  /// The store completed a restore request without returning this product.
  noPurchasesFound,

  /// No store to talk to: the web build, a device without Google Play, or a
  /// product that has not been published yet.
  unavailable,

  /// The store refused the payment.
  failed,
}

/// Failure details deliberately exclude receipts, account data and raw errors.
class PurchaseResult {
  const PurchaseResult(this.outcome, {this.message, this.diagnosticCode});

  final PurchaseOutcome outcome;
  final String? message;
  final String? diagnosticCode;
}

/// The platform store, for the single "Complete the Handover" product.
///
/// The listener reports store transactions to the app for a session-only
/// unlock. Trusted backend code must verify transactions and grant durable
/// access through `estate_handover_entitlements`.
class PaymentService {
  static StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  static InAppPurchase? _listeningStore;
  static void Function()? _onHandoverUnlocked;
  static Completer<PurchaseOutcome>? _pendingOutcome;

  /// Starts the app-lifetime listener. Repeated calls for the same store reuse
  /// the subscription rather than adding another listener.
  static Future<void> startPurchaseListener({
    InAppPurchase? store,
    void Function()? onHandoverUnlocked,
  }) async {
    final iap = store ?? InAppPurchase.instance;
    if (identical(_listeningStore, iap) && _purchaseSubscription != null) {
      if (onHandoverUnlocked != null) {
        _onHandoverUnlocked = onHandoverUnlocked;
      }
      return;
    }

    if (_purchaseSubscription != null) {
      await stopPurchaseListener();
    } else {
      _listeningStore = null;
      _onHandoverUnlocked = null;
    }
    _listeningStore = iap;
    _onHandoverUnlocked = onHandoverUnlocked;
    try {
      _purchaseSubscription = iap.purchaseStream.listen(
        (purchases) => _handlePurchaseUpdates(iap, purchases),
        onError: (Object error) {
          logDebug('IAP purchase stream errorType=${error.runtimeType}');
          final completer = _pendingOutcome;
          if (completer != null && !completer.isCompleted) {
            completer.complete(PurchaseOutcome.failed);
          }
        },
      );
    } catch (error) {
      _listeningStore = null;
      _onHandoverUnlocked = null;
      logDebug('IAP listener start errorType=${error.runtimeType}');
    }
  }

  /// Stops the listener when the app's root is disposed, and for test cleanup.
  static Future<void> stopPurchaseListener() async {
    final subscription = _purchaseSubscription;
    _purchaseSubscription = null;
    _listeningStore = null;
    _onHandoverUnlocked = null;
    final pendingOutcome = _pendingOutcome;
    _pendingOutcome = null;
    if (pendingOutcome != null && !pendingOutcome.isCompleted) {
      pendingOutcome.complete(PurchaseOutcome.failed);
    }
    if (subscription == null) return;
    try {
      await subscription.cancel();
    } catch (error) {
      logDebug('IAP listener cancel errorType=${error.runtimeType}');
    }
  }

  /// Returns the store-localized product details for display.
  static Future<ProductDetails?> lookupHandoverProduct({
    InAppPurchase? store,
  }) async {
    if (kIsWeb) return null;
    try {
      final iap = store ?? InAppPurchase.instance;
      if (!await iap.isAvailable()) return null;
      final response = await iap.queryProductDetails({handoverProductId});
      if (response.error != null) return null;
      for (final product in response.productDetails) {
        if (product.id == handoverProductId) return product;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<String?> lookupHandoverPrice({InAppPurchase? store}) async {
    final product = await lookupHandoverProduct(store: store);
    return product?.price;
  }

  static void _handlePurchaseUpdates(
    InAppPurchase iap,
    List<PurchaseDetails> purchases,
  ) {
    for (final purchase in purchases) {
      if (purchase.productID != handoverProductId) continue;

      if (purchase.pendingCompletePurchase) {
        unawaited(_completePurchaseSafely(iap, purchase));
      }

      final outcome = switch (purchase.status) {
        PurchaseStatus.purchased => PurchaseOutcome.purchased,
        PurchaseStatus.restored => PurchaseOutcome.purchased,
        PurchaseStatus.canceled => PurchaseOutcome.cancelled,
        PurchaseStatus.error => PurchaseOutcome.failed,
        PurchaseStatus.pending => null,
      };
      if (outcome == PurchaseOutcome.purchased) {
        try {
          _onHandoverUnlocked?.call();
        } catch (error) {
          logDebug('IAP unlock callback errorType=${error.runtimeType}');
        }
      }

      final completer = _pendingOutcome;
      if (outcome != null && completer != null && !completer.isCompleted) {
        completer.complete(outcome);
      }
    }
  }

  static Future<void> _completePurchaseSafely(
    InAppPurchase iap,
    PurchaseDetails purchase,
  ) async {
    try {
      await iap.completePurchase(purchase);
    } catch (error) {
      logDebug('IAP completion errorType=${error.runtimeType}');
    }
  }

  static Future<Completer<PurchaseOutcome>?> _beginPurchaseAttempt(
    InAppPurchase iap,
  ) async {
    await startPurchaseListener(store: iap);
    if (_purchaseSubscription == null || _pendingOutcome != null) return null;
    final completer = Completer<PurchaseOutcome>();
    _pendingOutcome = completer;
    return completer;
  }

  static void _endPurchaseAttempt(Completer<PurchaseOutcome> completer) {
    if (identical(_pendingOutcome, completer)) _pendingOutcome = null;
  }

  /// Restores the platform store's previous purchases for the handover product.
  ///
  /// A matching transaction arrives asynchronously on [purchaseStream].
  static Future<PurchaseResult> restoreHandoverUnlock({
    InAppPurchase? store,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (kIsWeb) {
      return const PurchaseResult(
        PurchaseOutcome.unavailable,
        message: 'Purchases cannot be restored in the browser.',
        diagnosticCode: 'web_unsupported',
      );
    }

    var stage = 'store_availability';
    try {
      final iap = store ?? InAppPurchase.instance;
      if (!await iap.isAvailable()) {
        return const PurchaseResult(
          PurchaseOutcome.unavailable,
          message: 'Purchases are not available on this device right now.',
          diagnosticCode: 'store_unavailable',
        );
      }

      stage = 'restore';
      final outcome = await _restore(iap, timeout);
      return PurchaseResult(
        outcome,
        message: outcome == PurchaseOutcome.noPurchasesFound
            ? 'No previous handover purchase was found for this store account.'
            : outcome == PurchaseOutcome.failed
                ? 'The store could not restore the purchase.'
                : null,
        diagnosticCode: outcome == PurchaseOutcome.noPurchasesFound
            ? 'restore_no_matching_purchase'
            : outcome == PurchaseOutcome.failed
                ? 'restore_failed'
                : null,
      );
    } on PlatformException catch (error) {
      return PurchaseResult(
        PurchaseOutcome.failed,
        message: 'The store could not complete this request. Please try again.',
        diagnosticCode: '$stage:${error.code}',
      );
    } catch (_) {
      return PurchaseResult(
        PurchaseOutcome.failed,
        message: 'The store could not complete this request. Please try again.',
        diagnosticCode: '$stage:unexpected_error',
      );
    }
  }

  /// Opens the store's own payment sheet for [handoverProductId].
  ///
  /// Resolves only when the purchase reaches a final state, so the caller can
  /// hold a spinner for the whole sheet. The store reports through a stream
  /// rather than through the return value, which says only whether the sheet
  /// could be shown at all.
  static Future<PurchaseResult> purchaseHandoverUnlock({
    InAppPurchase? store,
  }) async {
    // The plugin has no web implementation, so there is nothing to call.
    if (kIsWeb) {
      return const PurchaseResult(
        PurchaseOutcome.unavailable,
        message: 'Purchases are not supported in the browser. '
            'Use the installed app to test purchases.',
        diagnosticCode: 'web_unsupported',
      );
    }

    var stage = 'store_availability';
    try {
      final iap = store ?? InAppPurchase.instance;
      if (!await iap.isAvailable()) {
        return const PurchaseResult(
          PurchaseOutcome.unavailable,
          message: 'Purchases are not available on this device right now.',
          diagnosticCode: 'store_unavailable',
        );
      }

      stage = 'product_lookup';
      final response = await iap.queryProductDetails({handoverProductId});
      final error = response.error;
      if (error != null) {
        return PurchaseResult(
          PurchaseOutcome.unavailable,
          message: 'The handover purchase could not be loaded. '
              'Please try again later.',
          diagnosticCode: 'product_lookup:${error.code}',
        );
      }
      final products = response.productDetails
          .where((product) => product.id == handoverProductId);
      if (products.isEmpty) {
        return const PurchaseResult(
          PurchaseOutcome.unavailable,
          message: 'The handover purchase is not available right now. '
              'Please try again later.',
          diagnosticCode: 'product_not_found',
        );
      }

      stage = 'checkout';
      final outcome = await _checkout(iap, products.first);
      return PurchaseResult(
        outcome,
        message: outcome == PurchaseOutcome.failed
            ? 'The store could not complete the purchase.'
            : null,
        diagnosticCode:
            outcome == PurchaseOutcome.failed ? 'checkout_failed' : null,
      );
    } on PlatformException catch (error) {
      return PurchaseResult(
        PurchaseOutcome.failed,
        message: 'The store could not complete this request. Please try again.',
        diagnosticCode: '$stage:${error.code}',
      );
    } catch (_) {
      return PurchaseResult(
        PurchaseOutcome.failed,
        message: 'The store could not complete this request. Please try again.',
        diagnosticCode: '$stage:unexpected_error',
      );
    }
  }

  static Future<PurchaseOutcome> _checkout(
    InAppPurchase iap,
    ProductDetails product,
  ) async {
    final completer = await _beginPurchaseAttempt(iap);
    if (completer == null) return PurchaseOutcome.failed;

    try {
      final sheetShown = await iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!sheetShown) return PurchaseOutcome.failed;

      return await completer.future;
    } finally {
      _endPurchaseAttempt(completer);
    }
  }

  static Future<PurchaseOutcome> _restore(
    InAppPurchase iap,
    Duration timeout,
  ) async {
    final completer = await _beginPurchaseAttempt(iap);
    if (completer == null) return PurchaseOutcome.failed;

    try {
      await iap.restorePurchases();
      return await completer.future.timeout(
        timeout,
        onTimeout: () => PurchaseOutcome.noPurchasesFound,
      );
    } finally {
      _endPurchaseAttempt(completer);
    }
  }
}
