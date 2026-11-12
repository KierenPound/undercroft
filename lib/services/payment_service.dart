import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// The one-off unlock that lets an estate owner bring other people into it.
///
/// A non-consumable, so it is bought once per Apple or Google account and can
/// be restored. This string has to match the product created in App Store
/// Connect and the Play Console exactly; it cannot be changed afterwards.
const String handoverProductId = 'com.kierenpound.undercroft.handover';

/// What the unlock button shows. The store localises and prices the real
/// product, so this only has to agree with what is configured there.
const String handoverPriceLabel = '£34.99';

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
/// Stateless on purpose: the entitlement this returns is held by the caller for
/// the session until trusted backend code verifies the store transaction and
/// grants a row in `estate_handover_entitlements`.
class PaymentService {
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
          message: 'The device reports that store purchases are unavailable.',
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
        message: 'The store operation failed during $stage.',
        diagnosticCode: '$stage:${error.code}',
      );
    } catch (_) {
      return PurchaseResult(
        PurchaseOutcome.failed,
        message: 'The store operation failed during $stage.',
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
          message: 'The device reports that store purchases are unavailable. '
              'Check your store sign-in and any device restrictions '
              'on in-app purchases.',
          diagnosticCode: 'store_unavailable',
        );
      }

      stage = 'product_lookup';
      final response = await iap.queryProductDetails({handoverProductId});
      final error = response.error;
      if (error != null) {
        return PurchaseResult(
          PurchaseOutcome.unavailable,
          message: 'The store returned an error while looking up the '
              'handover purchase. Please share the diagnostic code.',
          diagnosticCode: 'product_lookup:${error.code}',
        );
      }
      final products = response.productDetails
          .where((product) => product.id == handoverProductId);
      if (products.isEmpty) {
        return const PurchaseResult(
          PurchaseOutcome.unavailable,
          message: 'The store returned no matching handover product. '
              'Check the product status, identifier and availability '
              'in the store console, and the tester account storefront.',
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
        message: 'The store operation failed during $stage. '
            'Please share the diagnostic code.',
        diagnosticCode: '$stage:${error.code}',
      );
    } catch (_) {
      return PurchaseResult(
        PurchaseOutcome.failed,
        message: 'The store operation failed during $stage. '
            'Please share the diagnostic code.',
        diagnosticCode: '$stage:unexpected_error',
      );
    }
  }

  static Future<PurchaseOutcome> _checkout(
    InAppPurchase iap,
    ProductDetails product,
  ) async {
    final completer = Completer<PurchaseOutcome>();
    final subscription = _settle(iap, completer);

    try {
      final sheetShown = await iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!sheetShown) return PurchaseOutcome.failed;

      return await completer.future;
    } finally {
      // Also release the listener if opening the payment sheet throws.
      await subscription.cancel();
    }
  }

  static Future<PurchaseOutcome> _restore(
    InAppPurchase iap,
    Duration timeout,
  ) async {
    final completer = Completer<PurchaseOutcome>();
    final subscription = iap.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          if (purchase.productID != handoverProductId) continue;

          switch (purchase.status) {
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              if (purchase.pendingCompletePurchase) {
                unawaited(iap.completePurchase(purchase));
              }
              if (!completer.isCompleted) {
                completer.complete(PurchaseOutcome.purchased);
              }
            case PurchaseStatus.error:
              if (!completer.isCompleted) {
                completer.complete(PurchaseOutcome.failed);
              }
            case PurchaseStatus.canceled:
            case PurchaseStatus.pending:
              break;
          }
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(PurchaseOutcome.failed);
      },
    );

    try {
      await iap.restorePurchases();
      return await completer.future.timeout(
        timeout,
        onTimeout: () => PurchaseOutcome.noPurchasesFound,
      );
    } finally {
      await subscription.cancel();
    }
  }

  /// Bridges the plugin's purchase stream into a single [Future].
  static StreamSubscription<List<PurchaseDetails>> _settle(
    InAppPurchase iap,
    Completer<PurchaseOutcome> completer,
  ) {
    return iap.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          if (purchase.productID != handoverProductId) continue;

          // The store re-sends a purchase until it is acknowledged, so without
          // this the sheet would reappear on the next launch.
          if (purchase.pendingCompletePurchase) {
            iap.completePurchase(purchase);
          }

          switch (purchase.status) {
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              if (!completer.isCompleted) {
                completer.complete(PurchaseOutcome.purchased);
              }
            case PurchaseStatus.canceled:
              if (!completer.isCompleted) {
                completer.complete(PurchaseOutcome.cancelled);
              }
            case PurchaseStatus.error:
              if (!completer.isCompleted) {
                completer.complete(PurchaseOutcome.failed);
              }
            // Deferred payment: neither bought nor refused yet, so keep waiting.
            case PurchaseStatus.pending:
              break;
          }
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(PurchaseOutcome.failed);
      },
    );
  }
}
