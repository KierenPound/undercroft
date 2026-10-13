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
    title: 'What to Do First',
    orderIndex: 0,
    youtubeUrl: 'https://www.youtube.com/watch?v=b4ZypVnbYHM',
    checklistItems: [
      'Register the death (within 5 days in England/Wales)',
      'Obtain multiple copies of the death certificate',
      'Arrange for the immediate care of dependents or pets',
      'Secure the home and any valuables',
      'Notify the person\'s GP and employer',
      'Locate the will and any funeral wishes',
    ],
  ),
  DefaultSection(
    title: 'Legal Documents',
    orderIndex: 1,
    youtubeUrl: 'https://youtu.be/AL8chWFuM-s',
    checklistItems: [
      'Locate the last will and testament',
      'Find any enduring/lasting power of attorney documents',
      'Gather birth, marriage, and divorce certificates',
      'Collect property deeds and mortgage documents',
      'Locate insurance policies (life, home, car)',
      'Gather bank and investment account statements',
      'Find passport and driving licence',
    ],
  ),
  DefaultSection(
    title: 'Who to Notify',
    orderIndex: 2,
    youtubeUrl: 'https://www.youtube.com/watch?v=tuyBCSYTs5A',
    checklistItems: [
      'Family members and close friends',
      'GP / doctor\'s surgery',
      'Employer (if applicable)',
      'Bank and building society',
      'Pension provider',
      'HM Revenue & Customs (HMRC)',
      'Local council (council tax, electoral register)',
      'Utility companies (gas, electric, water, broadband)',
      'Insurance companies',
      'DVLA (driving licence, vehicle)',
    ],
  ),
  DefaultSection(
    title: 'Running the Houses',
    orderIndex: 3,
    youtubeUrl: 'https://www.youtube.com/watch?v=jqpAgMxhx30',
    checklistItems: [
      'Secure all properties and update alarm codes if needed',
      'Redirect post via Royal Mail',
      'Cancel or redirect regular deliveries (milk, papers, subscriptions)',
      'Review standing orders and direct debits',
      'Inform mortgage lender or landlord',
      'Check home insurance validity',
      'Arrange for pets or livestock to be cared for',
      'Maintain garden and security (lights, timers)',
    ],
  ),
  DefaultSection(
    title: 'Funeral Arrangements',
    orderIndex: 4,
    youtubeUrl: 'https://www.youtube.com/watch?v=02T6xLNXEE0',
    checklistItems: [
      'Check for any funeral wishes or a prepaid plan',
      'Choose a funeral director',
      'Decide between burial and cremation',
      'Select coffin or casket',
      'Arrange transport (hearse, limousines)',
      'Plan the service (music, readings, eulogy)',
      'Order flowers',
      'Notify attendees and arrange order of service',
      'Arrange catering for the wake',
    ],
  ),
  DefaultSection(
    title: 'Cars',
    orderIndex: 5,
    youtubeUrl: 'https://www.youtube.com/watch?v=rbgiJu7YFvo',
    checklistItems: [
      'Locate the vehicle registration document (V5C)',
      'Find car insurance documents',
      'Check MOT status',
      'Inform DVLA of the death (log book)',
      'Cancel or transfer car insurance',
      'Arrange for vehicle valuation if selling',
      'Collect spare keys',
    ],
  ),
  DefaultSection(
    title: 'Confirmation',
    orderIndex: 6,
    youtubeUrl: 'https://www.youtube.com/watch?v=lHzhH_tJ7ak',
    checklistItems: [
      'Confirm all utility accounts are closed or transferred',
      'Verify bank accounts are settled',
      'Confirm HMRC notified and tax affairs in order',
      'Check all subscriptions and memberships cancelled',
      'Final confirmation that all parties have been informed',
    ],
  ),
];
