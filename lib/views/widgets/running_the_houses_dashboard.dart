import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Running the Houses rich-content dashboard.
///
/// Cloned from the FamilyPrep (iOS) `RunningTheHousesDashboardView`,
/// containing the "Tradesmen" section — i.e. everything between the Memory
/// photo (handled by [PhotoSection]) and the Song for the page
/// (handled by [SongForThePageSection]).
class RunningTheHousesDashboard extends StatelessWidget {
  const RunningTheHousesDashboard({super.key});

  static const _tradesmen = <_TradesLocationGroup>[
    _TradesLocationGroup(
      location: 'Perth',
      icon: Icons.location_on,
      tint: Colors.red,
      tradesmen: [
        _TradesmanContact(
          name: 'Neil',
          role: 'Gas and Plumbing',
          company: 'Perth Renu',
          phoneNumber: '07894 248726',
          icon: Icons.local_fire_department,
          accent: Colors.orange,
        ),
        _TradesmanContact(
          name: 'Fraser',
          role: 'Electrics',
          company: 'FM Electrics',
          phoneNumber: '07545 078968',
          icon: Icons.bolt,
          accent: Colors.amber,
        ),
        _TradesmanContact(
          name: 'Andrew Gallagher',
          role: 'Electrics (Dunning)',
          company: null,
          phoneNumber: '07977 194742',
          icon: Icons.bolt,
          accent: Colors.amber,
        ),
      ],
    ),
    _TradesLocationGroup(
      location: 'Ayr',
      icon: Icons.location_on,
      tint: Colors.blue,
      tradesmen: [
        _TradesmanContact(
          name: 'Darwin Johnstone',
          role: 'Gas and Plumbing',
          company: null,
          phoneNumber: '07793 486802',
          icon: Icons.local_fire_department,
          accent: Colors.orange,
        ),
        _TradesmanContact(
          name: 'Klearflow drains',
          role: 'Drain cleaning (usually Bath Place)',
          company: null,
          phoneNumber: '01292 501059',
          icon: Icons.water_drop,
          accent: Colors.teal,
        ),
        _TradesmanContact(
          name: 'Steven Mitchell',
          role: 'Electrical checks and repairs',
          company: 'Mitchell Electrics',
          phoneNumber: '07850 956254',
          icon: Icons.bolt,
          accent: Colors.amber,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTradesmenSection(),
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

  Future<void> _call(String phoneNumber) async {
    final digits = phoneNumber.replaceAll(RegExp(r'\s'), '');
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // MARK: - Tradesmen

  Widget _buildTradesmenSection() {
    const tint = Colors.indigo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Tradesmen',
          icon: Icons.handyman,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _tradesmen.length; i++) ...[
                  if (i > 0) const SizedBox(height: 22),
                  _locationGroupCard(_tradesmen[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _locationGroupCard(_TradesLocationGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: group.tint.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(group.icon, color: group.tint, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                group.location,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2C2E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < group.tradesmen.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _tradesmanRow(group.tradesmen[i]),
            ],
          ],
        ),
      ],
    );
  }

  Widget _tradesmanRow(_TradesmanContact trade) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: trade.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(trade.icon, color: trade.accent, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trade.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2E),
                ),
              ),
              if (trade.company != null)
                Text(
                  trade.company!,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              Text(
                trade.role,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _call(trade.phoneNumber),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.25),
                      width: 0.4,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone, color: Colors.green, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        trade.phoneNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TradesLocationGroup {
  final String location;
  final IconData icon;
  final Color tint;
  final List<_TradesmanContact> tradesmen;

  const _TradesLocationGroup({
    required this.location,
    required this.icon,
    required this.tint,
    required this.tradesmen,
  });
}

class _TradesmanContact {
  final String name;
  final String role;
  final String? company;
  final String phoneNumber;
  final IconData icon;
  final Color accent;

  const _TradesmanContact({
    required this.name,
    required this.role,
    required this.company,
    required this.phoneNumber,
    required this.icon,
    required this.accent,
  });
}
