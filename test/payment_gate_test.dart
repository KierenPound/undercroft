import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undercroft/services/estate_service.dart';
import 'package:undercroft/services/payment_service.dart';

void main() {
  group('handover invitation gate policy', () {
    test('production mobile requires a verified entitlement', () {
      expect(
        shouldLockHandoverInvites(
          hasDevTools: false,
          isMobile: true,
          testGateEnabled: false,
          unlocked: false,
        ),
        isTrue,
      );
      expect(
        shouldLockHandoverInvites(
          hasDevTools: false,
          isMobile: true,
          testGateEnabled: false,
          unlocked: true,
        ),
        isFalse,
      );
    });

    test('production Android requires a verified entitlement', () {
      expect(
        shouldLockHandoverInvites(
          hasDevTools: false,
          isMobile: true,
          testGateEnabled: false,
          unlocked: false,
        ),
        isTrue,
      );
      expect(
        shouldLockHandoverInvites(
          hasDevTools: false,
          isMobile: true,
          testGateEnabled: false,
          unlocked: true,
        ),
        isFalse,
      );
    });

    test('non-mobile platforms remain free in production', () {
      expect(
        shouldLockHandoverInvites(
          hasDevTools: false,
          isMobile: false,
          testGateEnabled: true,
          unlocked: false,
        ),
        isFalse,
      );
    });

    test('developer builds only lock after the rehearsal toggle is enabled',
        () {
      expect(
        shouldLockHandoverInvites(
          hasDevTools: true,
          isMobile: true,
          testGateEnabled: false,
          unlocked: false,
        ),
        isFalse,
      );
      expect(
        shouldLockHandoverInvites(
          hasDevTools: true,
          isMobile: true,
          testGateEnabled: true,
          unlocked: false,
        ),
        isTrue,
      );
    });
  });

  test('invitations remain free until the test gate is enabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(invitesLockedProvider), isFalse);
    container.read(testPaymentGateProvider.notifier).state = true;
    expect(container.read(invitesLockedProvider), isTrue);
    container.read(sessionInvitesUnlockedProvider.notifier).state = true;
    expect(container.read(invitesLockedProvider), isFalse);
  });

  test('turning off the test gate releases unpaid invitations', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(testPaymentGateProvider.notifier).state = true;
    expect(container.read(invitesLockedProvider), isTrue);
    container.read(testPaymentGateProvider.notifier).state = false;
    expect(container.read(invitesLockedProvider), isFalse);
  });

  test('session unlock does not carry into a new session', () {
    final first = ProviderContainer();
    first.read(sessionInvitesUnlockedProvider.notifier).state = true;
    first.dispose();

    final next = ProviderContainer();
    addTearDown(next.dispose);
    expect(next.read(invitesUnlockedProvider), isFalse);
    expect(next.read(testPaymentGateProvider), isFalse);
  });

  test('persisted entitlement unlocks invitations in a fresh session',
      () async {
    final container = ProviderContainer(
      overrides: [
        estateHandoverEntitlementProvider.overrideWith((ref) async => true),
      ],
    );
    addTearDown(container.dispose);

    container.read(testPaymentGateProvider.notifier).state = true;
    await container.read(estateHandoverEntitlementProvider.future);

    expect(container.read(invitesUnlockedProvider), isTrue);
    expect(container.read(invitesLockedProvider), isFalse);
  });

  test(
    'browser purchase returns unavailable without a store plugin',
    () async {
      final result = await PaymentService.purchaseHandoverUnlock();
      expect(
        result.outcome,
        PurchaseOutcome.unavailable,
      );
      expect(result.diagnosticCode, 'web_unsupported');
    },
    skip: !kIsWeb,
  );
}
