import 'package:flutter_test/flutter_test.dart';
import 'package:undercroft/services/estate_service.dart';

void main() {
  test('co-owner readiness counts other accepted owners and executors', () {
    const invites = [
      EstateInvite(
        id: 'self',
        invitedEmail: 'brenda@example.com',
        role: 'owner',
        status: 'accepted',
        createdAt: null,
        isSelf: true,
      ),
      EstateInvite(
        id: 'other-owner',
        invitedEmail: 'kieren@example.com',
        role: 'owner',
        status: 'accepted',
        createdAt: null,
        isSelf: false,
      ),
      EstateInvite(
        id: 'executor',
        invitedEmail: 'executor@example.com',
        role: 'executor',
        status: 'accepted',
        createdAt: null,
        isSelf: false,
      ),
    ];

    final readiness = EstateReadiness.fromInvites(invites);

    expect(readiness.state, HandoverReadiness.prepared);
    expect(readiness.acceptedOwnerCount, 1);
    expect(readiness.acceptedExecutorCount, 1);
    expect(readiness.pendingCount, 0);
  });
}
