import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/estate_service.dart';

/// Green when a readiness step is met, orange while it is still outstanding.
const _metColor = Color(0xFF3A8D5A);
const _unmetColor = Color(0xFFE08A2C);

/// Owner-facing summary of how ready the estate is for a handover, shown on
/// its own "Readiness" section rather than inside Settings.
///
/// Driven entirely by who has been invited and who has accepted. Never
/// consults payment state: an unredeemed paid invite is exactly as unprepared
/// as an unsent one, so money alone never turns a step green.
class ReadinessDashboard extends ConsumerWidget {
  const ReadinessDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInvites = ref.watch(estateInvitesProvider);

    return asyncInvites.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const Text(
        'Could not load your handover readiness.',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      ),
      data: (invites) {
        final readiness = EstateReadiness.fromInvites(invites);

        final otherInvited = readiness.pendingCount > 0 ||
            readiness.acceptedOwnerCount > 0 ||
            readiness.acceptedExecutorCount > 0;
        final anyAccepted =
            readiness.acceptedOwnerCount > 0 || readiness.acceptedExecutorCount > 0;

        // Least to most ready, so the executor — the person who will actually
        // have to act — sits at the bottom as the goal.
        final steps = <({String label, bool met})>[
          (
            label: 'You have invited someone else to access your estate',
            met: otherInvited,
          ),
          (label: 'An invite has been accepted', met: anyAccepted),
          (
            label: 'Another owner can reach the estate',
            met: readiness.acceptedOwnerCount > 0,
          ),
          (
            label: 'An executor can reach the estate',
            met: readiness.acceptedExecutorCount > 0,
          ),
        ];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _ReadinessStep(label: steps[i].label, met: steps[i].met),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A single readiness line: a green tick when met, an orange ring when not.
class _ReadinessStep extends StatelessWidget {
  final String label;
  final bool met;

  const _ReadinessStep({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final color = met ? _metColor : _unmetColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 22,
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C2C2E),
            ),
          ),
        ),
      ],
    );
  }
}
