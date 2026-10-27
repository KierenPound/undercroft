import 'package:flutter/material.dart';

import '../../models/utility_detail.dart';
import 'tradespeople_section.dart';
import 'utility_detail_section.dart';

/// Running the Houses rich-content dashboard.
///
/// Cloned from the FamilyPrep (iOS) `RunningTheHousesDashboardView`, containing
/// everything between the Memory photo (handled by [PhotoSection]) and the
/// Song for the page (handled by [SongForThePageSection]): the tradespeople the
/// estate relies on, then a card each for the Gas meter, Electric meter and
/// Stopcock.
class RunningTheHousesDashboard extends StatelessWidget {
  final String estateId;
  final bool isOwner;

  const RunningTheHousesDashboard({
    super.key,
    required this.estateId,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TradespeopleSection(estateId: estateId, isOwner: isOwner),
        const SizedBox(height: 28),
        UtilityDetailSection(
          estateId: estateId,
          isOwner: isOwner,
          kind: UtilityKind.gasMeter,
        ),
        const SizedBox(height: 28),
        UtilityDetailSection(
          estateId: estateId,
          isOwner: isOwner,
          kind: UtilityKind.electricMeter,
        ),
        const SizedBox(height: 28),
        UtilityDetailSection(
          estateId: estateId,
          isOwner: isOwner,
          kind: UtilityKind.stopcock,
        ),
      ],
    );
  }
}
