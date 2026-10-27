/// Default sections and their starter checklist items.
///
/// These are applied to a freshly created estate during onboarding so that new
/// users have a sensible starting point instead of blank sections.
///
/// Each entry mirrors the section configs used by the home dashboard
/// ([SectionConfig]) so the youtube URLs and ordering stay consistent.
///
/// To add or change defaults, edit the list below. The seeding logic in
/// [SectionsRepository.seedDefaults] is idempotent: checklist items are only
/// inserted for sections that have none, so re-running the seed never
/// duplicates existing entries.
class DefaultSection {
  final String title;
  final int orderIndex;
  final String youtubeUrl;
  final List<String> checklistItems;

  const DefaultSection({
    required this.title,
    required this.orderIndex,
    this.youtubeUrl = '',
    this.checklistItems = const [],
  });
}

const List<DefaultSection> defaultSections = [
  DefaultSection(
    title: 'My Letter to You',
    orderIndex: 0,
  ),
  DefaultSection(
    title: 'What to Do First',
    orderIndex: 1,
    youtubeUrl: 'https://www.youtube.com/watch?v=b4ZypVnbYHM',
    checklistItems: [
      'Arrange for the immediate care of dependents or pets',
      'Secure the home and any valuables',
      'Contact the GP or hospital doctor to get the Medical Certificate of Cause of Death (MCCD)',
      'Register the death (within 8 days in Scotland, 5 days in England/Wales)',
      'Obtain multiple copies of the death certificate',
      'Use the Tell Us Once service to notify HMRC, DWP, local council etc',
    ],
  ),
  DefaultSection(
    title: 'Legal Documents',
    orderIndex: 2,
    youtubeUrl: 'https://www.youtube.com/watch?v=GaZp4fJVHmQ',
    checklistItems: [
      'Locate the last will and testament documents',
      'Contact the lawyer to inform them, as they can help you when you need advice',
      'Collect title deeds and mortgage documents',
    ],
  ),
  DefaultSection(
    title: 'Who to Notify',
    orderIndex: 3,
    youtubeUrl: 'https://www.youtube.com/watch?v=tuyBCSYTs5A',
    checklistItems: [
      'Family members and close friends - see Contacts',
      'GP / doctor\'s surgery',
      'Employer (if applicable)',
      'Use Life Ledger to notify companies and organisations',
    ],
  ),
  DefaultSection(
    title: 'Running the Houses',
    orderIndex: 4,
    youtubeUrl: 'https://www.youtube.com/watch?v=jqpAgMxhx30',
    checklistItems: [
      'Redirect post via Royal Mail',
      'Cancel or redirect regular deliveries (milk, papers, subscriptions)',
      'Review standing orders and direct debits',
      'Inform mortgage lender or landlord (if appropriate)',
      'Maintain garden and security (lights, timers)',
      'Familiarise yourself with meters and stopcock locations',
    ],
  ),
  DefaultSection(
    title: 'Funeral Arrangements',
    orderIndex: 5,
    youtubeUrl: 'https://www.youtube.com/watch?v=02T6xLNXEE0',
    checklistItems: [
      'Check the Funerals section for funeral wishes',
      'Action the request as they wished, if you can',
    ],
  ),
  DefaultSection(
    title: 'Cars',
    orderIndex: 6,
    youtubeUrl: 'https://www.youtube.com/watch?v=rbgiJu7YFvo',
    checklistItems: [
      'Locate the vehicle registration document(s) (V5C)',
      'Find car insurance documents',
      'Cancel or transfer car insurance',
    ],
  ),
  DefaultSection(
    title: 'Confirmation',
    orderIndex: 7,
    youtubeUrl: 'https://www.youtube.com/watch?v=lHzhH_tJ7ak',
    checklistItems: [
      'Arrange a formal written valuation for the house(s) from a chartererd surveyor',
      'Confirm final balances across all financial accounts (see Organisations in Who To Notify)',
      'Confirm HMRC to get an Inheritance Tax Refernce Number',
      'Fill in HMRC Tax Forms',
      'Pay the tax (sorry!)',
      'Get the IHT421 certificate and submit to the Sheriff Court',
      'Receive the Grant of Confirmation and unlock the cash (if any)'
    ],
  ),
  DefaultSection(
    title: 'My Songs',
    orderIndex: 8,
  ),
];
