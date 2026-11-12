import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/estate_service.dart';

/// Green when a readiness step is met, orange while it is still outstanding.
const _metColor = Color(0xFF3A8D5A);
const _unmetColor = Color(0xFFE08A2C);

/// Owner-facing summary of how ready the estate is for a handover, shown on
/// its own "Readiness" section rather than inside Settings.
///
/// Invitation status and the owner's annual review confirmation drive the
/// checklist. It never consults payment state: an unredeemed paid invite is
/// exactly as unprepared as an unsent one, so money alone never turns a step
/// green.
class ReadinessDashboard extends ConsumerWidget {
  const ReadinessDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInvites = ref.watch(estateInvitesProvider);

    final readinessContent = asyncInvites.when(
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

        // Estate-level, so it reads the same for an owner and a co-owner.
        // The estate has invited someone else once more than one person has
        // access, or an invite is still outstanding. Counted across the whole
        // estate rather than relative to the viewer (unlike the isSelf-based
        // steps below), so a co-owner never sees a personal version of it.
        var acceptedMembers = 0;
        var pendingInvites = 0;
        for (final invite in invites) {
          if (invite.isRevoked) continue;
          if (invite.isPending) {
            pendingInvites++;
          } else if (invite.status == 'accepted') {
            acceptedMembers++;
          }
        }
        final estateInvitedSomeone = acceptedMembers >= 2 || pendingInvites > 0;

        final anyAccepted = readiness.acceptedOwnerCount > 0 ||
            readiness.acceptedExecutorCount > 0;

        // Least to most ready, so the executor — the person who will actually
        // have to act — sits at the bottom as the goal.
        final steps = <({String label, bool met})>[
          (
            label:
                'The estate owner has invited someone else to access this estate',
            met: estateInvitedSomeone,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        readinessContent,
        const SizedBox(height: 16),
        const _EstateReviewCheckIn(),
      ],
    );
  }
}

class _EstateReviewCheckIn extends ConsumerStatefulWidget {
  const _EstateReviewCheckIn();

  @override
  ConsumerState<_EstateReviewCheckIn> createState() =>
      _EstateReviewCheckInState();
}

class _EstateReviewCheckInState extends ConsumerState<_EstateReviewCheckIn> {
  bool _saving = false;

  Future<void> _confirmReview() async {
    final estateId = ref.read(estateIdProvider).valueOrNull ?? '';
    if (estateId.isEmpty) return;

    setState(() => _saving = true);
    try {
      await confirmEstateDetailsReviewed(estateId: estateId);
      ref.invalidate(estateOwnerReviewStatusProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your review date has been updated')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your review date')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(estateRoleProvider).valueOrNull;
    if (role != 'owner') return const SizedBox.shrink();

    final asyncStatus = ref.watch(estateOwnerReviewStatusProvider);

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
          Text(
            'Annual details review',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          asyncStatus.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const Text(
              'Could not load your review status.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            data: (status) {
              final lastReviewedAt = status?.lastReviewedAt;
              final isCurrent = lastReviewedAt != null &&
                  status!.nextReminderAt.isAfter(DateTime.now());
              final label = lastReviewedAt == null
                  ? 'Estate details have not been reviewed yet'
                  : isCurrent
                      ? 'Estate details last reviewed on '
                          '${_reviewDate(lastReviewedAt)}'
                      : 'Estate details are due for review. Last checked on '
                          '${_reviewDate(lastReviewedAt)}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReadinessStep(label: label, met: isCurrent),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _confirmReview,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('I have checked my details'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
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

String _reviewDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
