import 'package:flutter/material.dart';

/// Cars rich-content dashboard.
///
/// Cloned from the FamilyPrep (iOS) `CarsDashboardView`, containing the
/// "Vehicle Transfer & Insurance Rules (DVLA)" section — i.e. everything
/// between the Memory photo (handled by [PhotoSection]) and the Song for the
/// page (handled by [SongForThePageSection]).
class CarsDashboard extends StatelessWidget {
  const CarsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDvlaSection(),
      ],
    );
  }

  // MARK: - Shared helpers

  Widget _sectionHeader({
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _infoCallout({
    required IconData icon,
    required Color tint,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.25), width: 0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C2C2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subSectionHeader({
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2E),
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
              color: tint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _insuranceRuleBullet({required String title, required String text}) {
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF2C2C2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _keepCarStep({
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
            style: const TextStyle(
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF2C2C2E),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2C2E),
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

  Widget _buildDvlaSection() {
    const tint = Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Vehicle Transfer & Insurance Rules (DVLA)',
          icon: Icons.shield,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Intro paragraphs
                const Text(
                  'A motor vehicle is a personal possession. You do not have '
                  'to wait for Confirmation to transfer or sell any of the '
                  'cars.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),
                const SizedBox(height: 10),
                const Text(
                  'However, there are strict legal rules regarding insurance '
                  'and the logbook.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),
                const SizedBox(height: 22),

                // Info callout: V5 in black folder
                _infoCallout(
                  icon: Icons.info,
                  tint: Colors.blue,
                  text: 'The physical V5 documents are in the black folder '
                      'in the sitting room.',
                ),
                const SizedBox(height: 22),
                const Divider(height: 1),
                const SizedBox(height: 22),

                // Important Insurance Rules
                _subSectionHeader(
                  title: 'Important Insurance Rules',
                  icon: Icons.warning_amber_rounded,
                  tint: Colors.red,
                ),
                const SizedBox(height: 12),
                _insuranceRuleBullet(
                  title: 'Named Drivers are NOT Covered:',
                  text: 'Even if you are listed as a named driver on my car '
                      'insurance policy, your cover becomes instantly invalid '
                      'the moment we shuffle off this mortal coil.',
                ),
                const SizedBox(height: 12),
                _insuranceRuleBullet(
                  title: 'Do Not Drive the Car:',
                  text: 'The car must be left parked safely on private land '
                      '(a driveway or garage). Do not drive it on a public '
                      'road until you have explicitly called the car '
                      'insurance provider to arrange "Executor Cover", a '
                      'temporary policy (via apps like Cuvva), or a '
                      'brand-new policy in your own name. Driving it under '
                      'the old policy is illegal and means you are driving '
                      'uninsured.',
                ),
                const SizedBox(height: 22),
                const Divider(height: 1),
                const SizedBox(height: 22),

                // How to Transfer Ownership (via Post)
                _subSectionHeader(
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
                ),
                const SizedBox(height: 12),
                _keepCarStep(
                  number: 1,
                  title: 'Fill out details:',
                  text: 'Fill out the "new keeper" details section in the '
                      'physical V5C Logbook with your name and address.',
                ),
                const SizedBox(height: 12),
                _keepCarStep(
                  number: 2,
                  title: 'Keep green slip:',
                  text: 'Tear off the green "new keeper" slip (Section 2) '
                      'and keep it. You must use this slip to tax the '
                      'vehicle in your name immediately online, as the old '
                      'road tax cancels automatically.',
                ),
                const SizedBox(height: 12),
                _keepCarStep(
                  number: 3,
                  title: 'Write a cover letter:',
                  text: 'Write a brief covering letter to the DVLA explaining '
                      'your relationship to me, the date I expired, and who '
                      'should receive any road tax refund.',
                ),
                const SizedBox(height: 12),
                _keepCarStep(
                  number: 4,
                  title: 'Send to DVLA:',
                  text: 'Post the main part of the V5C Logbook and your '
                      'covering letter to:',
                  trailingBlock: 'Sensitive Casework Team\nDVLA\nSwansea\nSA99 1ZZ',
                ),
                const SizedBox(height: 22),
                const Divider(height: 1),
                const SizedBox(height: 22),

                // SELL the car flow
                _subHeaderChip(
                  title: 'If you are SELLING the Car:',
                  icon: Icons.payments,
                  tint: Colors.red,
                ),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.description, color: Colors.red, size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Follow the exact same steps as above, but fill out '
                        'the V5C Logbook with the buyer\'s details, hand them '
                        'the green slip so they can tax it, and mail the rest '
                        'of the logbook with your covering letter to the DVLA '
                        'Sensitive Casework Team.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF2C2C2E),
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
