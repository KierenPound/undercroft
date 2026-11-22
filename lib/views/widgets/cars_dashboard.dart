import 'package:material_ui/material_ui.dart';

import '../../services/estate_service.dart';
import '../../theme/app_palette.dart';

/// Cars rich-content dashboard.
///
/// Cloned from the FamilyPrep (iOS) `CarsDashboardView`, containing the
/// "Vehicle Transfer & Insurance Rules (DVLA)" section — i.e. everything
/// between the Memory photo (handled by [PhotoSection]) and the Song for the
/// page (handled by [SongForThePageSection]).
class CarsDashboard extends StatelessWidget {
  final EstateProcessRegion processRegion;

  const CarsDashboard({super.key, required this.processRegion});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDvlaSection(
          context: context,
          grantName: processRegion == EstateProcessRegion.scotland
              ? 'Confirmation'
              : 'Probate',
        ),
      ],
    );
  }

  // MARK: - Shared helpers

  Widget _sectionHeader({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color tint,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: tint, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _subSectionHeader({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color tint,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: tint, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _subHeaderChip({
    required String title,
    required IconData icon,
    required Color tint,
    required BuildContext context,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: tint, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _insuranceRuleBullet({
    required BuildContext context,
    required String title,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cancel, color: Colors.red, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _keepCarStep({
    required BuildContext context,
    required int number,
    required String title,
    required String text,
    String? trailingBlock,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.green,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (trailingBlock != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trailingBlock,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // MARK: - DVLA Vehicle Transfer & Insurance Rules

  Widget _buildDvlaSection({
    required BuildContext context,
    required String grantName,
  }) {
    const tint = Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context: context,
          title: 'Vehicle Transfer & Insurance Rules (DVLA)',
          icon: Icons.shield,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Intro paragraphs
                Text(
                  'A motor vehicle is a personal possession. You do not have '
                  'to wait for $grantName to transfer or sell any of the '
                  'cars.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'However, there are strict legal rules regarding insurance '
                  'and the logbook.',
                  style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
                ),
                const Divider(height: 1),
                const SizedBox(height: 22),

                // Important Insurance Rules
                _subSectionHeader(
                  context: context,
                  title: 'Important Insurance Rules',
                  icon: Icons.warning_amber_rounded,
                  tint: Colors.red,
                ),
                const SizedBox(height: 12),
                _insuranceRuleBullet(
                  context: context,
                  title: 'Important: Check Motor Insurance Cover',
                  text: 'Even if you are listed as a named driver on my car '
                      'insurance policy, your cover nearly always becomes invalid '
                      'the moment we shuffle off this mortal coil.  Check with the insurer',
                ),
                const SizedBox(height: 12),
                _insuranceRuleBullet(
                  context: context,
                  title: 'Do Not Drive the Car:',
                  text: 'The car must be left parked safely on private land '
                      '(a driveway or garage). Do not drive it on a public '
                      'road until you have explicitly called the car '
                      'insurance provider to arrange "Executor Cover", a '
                      'temporary policy (via apps like Cuvva), or a '
                      'brand-new policy in your own name. Driving it under '
                      'the old policy may be illegal and means you are driving '
                      'uninsured.',
                ),
                const SizedBox(height: 22),
                const Divider(height: 1),
                const SizedBox(height: 22),

                // How to Transfer Ownership (via Post)
                _subSectionHeader(
                  context: context,
                  title: 'How to Transfer Ownership (via Post)',
                  icon: Icons.mail,
                  tint: Colors.indigo,
                ),
                const SizedBox(height: 12),

                // KEEP the car flow
                _subHeaderChip(
                  title: 'If you are KEEPING the Car:',
                  icon: Icons.directions_car,
                  tint: Colors.green,
                  context: context,
                ),
                const SizedBox(height: 12),
                _keepCarStep(
                  context: context,
                  number: 1,
                  title: 'Fill out details:',
                  text: 'Fill out the "new keeper" details section in the '
                      'physical V5C Logbook with your name and address.',
                ),
                const SizedBox(height: 12),
                _keepCarStep(
                  context: context,
                  number: 2,
                  title: 'Keep green slip:',
                  text: 'Tear off the green "new keeper" slip (Section 2) '
                      'and keep it. You must use this slip to tax the '
                      'vehicle in your name immediately online, as the old '
                      'road tax cancels automatically.',
                ),
                const SizedBox(height: 12),
                _keepCarStep(
                  context: context,
                  number: 3,
                  title: 'Write a cover letter:',
                  text: 'Write a brief covering letter to the DVLA explaining '
                      'your relationship to me, the date I expired, and who '
                      'should receive any road tax refund.',
                ),
                const SizedBox(height: 12),
                _keepCarStep(
                  context: context,
                  number: 4,
                  title: 'Send to DVLA:',
                  text: 'Post the main part of the V5C Logbook and your '
                      'covering letter to:',
                  trailingBlock:
                      'Sensitive Casework Team\nDVLA\nSwansea\nSA99 1ZZ',
                ),
                const SizedBox(height: 22),
                const Divider(height: 1),
                const SizedBox(height: 22),

                // SELL the car flow
                _subHeaderChip(
                  title: 'If you are SELLING the Car:',
                  icon: Icons.payments,
                  tint: Colors.red,
                  context: context,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description, color: Colors.red, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Follow the exact same steps as above, but fill out '
                        'the V5C Logbook with the buyer\'s details, hand them '
                        'the green slip so they can tax it, and mail the rest '
                        'of the logbook with your covering letter to the DVLA '
                        'Sensitive Casework Team.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.phonelink_erase, color: Colors.red, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Remember to erase your personal data, like phones or '
                        'sat nav destinations.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded surface used for the dashboard's content blocks, tinted by the
/// selected colour scheme.
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.of(context).cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
