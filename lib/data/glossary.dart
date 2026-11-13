/// The text behind the introduction and glossary screen.
///
/// Held as data rather than widgets because the same words appear in two
/// places: once when someone first signs in, and again on demand from
/// Settings. Both read from here, so the two cannot drift apart.
///
/// The definitions are deliberately plain English. The reader is usually an
/// executor meeting these terms for the first time, often in the days after a
/// death, so each entry says what the thing is and why it matters rather than
/// restating a statute.
///
/// Where a term means different things under Scots law and the law of
/// England, Wales and Northern Ireland, it carries a [GlossaryEntry.jurisdiction]
/// so the reader is not misled. Null means it means the same thing UK-wide.
library;

/// Heading shown above the introduction paragraphs.
const String introductionTitle = 'Welcome to UnderCroft';

/// The introduction itself, one paragraph per entry.
const List<String> introductionParagraphs = [
  'This record was put together by the estate owner to help whoever deals '
      'with their affairs. It holds the personal and financial details of the '
      'estate, along with pointers to who to contact and when.',
  'If you are the executor, or helping someone who is, there is no need to '
      'read it all at once. Work through the sections in whatever order suits '
      'you — the legal process checklist sets out what has to be done, and in '
      'what order.',
  'The glossary below explains the terms you are likely to meet along the '
      'way: the forms, the courts and the tax. It is here whenever you want '
      'it, from Settings.',
  'Nothing in this app is legal advice, and it does not replace a solicitor.',
];

/// One glossary entry: the term, what it means, and where it applies.
class GlossaryEntry {
  const GlossaryEntry(this.term, this.definition, {this.jurisdiction});

  final String term;
  final String definition;

  /// Null where the term applies across the UK.
  final String? jurisdiction;
}

/// A titled group of entries, so the list reads as sections rather than one
/// undifferentiated wall of definitions.
class GlossarySection {
  const GlossarySection(this.title, this.entries);

  final String title;
  final List<GlossaryEntry> entries;
}

const String _scotland = 'Scotland';
const String _ewni = 'England, Wales & NI';
const String _northernIreland = 'Northern Ireland';

const List<GlossarySection> glossary = [
  GlossarySection('People', [
    GlossaryEntry(
      'Estate owner',
      'The person this record belongs to, and whose estate it describes. They '
          'may still be alive, planning ahead, or may have died.',
    ),
    GlossaryEntry(
      'Executor',
      'The person named in a will to deal with the estate after a death: '
          'gather everything in, pay what is owed, and pass what remains to '
          'those who inherit. In this app, an executor is invited to join an '
          'estate.',
    ),
    GlossaryEntry(
      'Beneficiary',
      'Anyone who receives money, property or belongings from the estate, '
          'whether under the will or under inheritance law if there is no will.',
    ),
    GlossaryEntry(
      'Next of kin',
      'The closest living relative. This matters most when there is no will, '
          'as they decide who applies to administer the estate.',
    ),
    GlossaryEntry(
      'Solicitor',
      'A qualified lawyer. In Scotland, one who handles estates is often '
          'called an executry solicitor. You can run the whole process '
          'yourself, but many people use one.',
    ),
  ]),
  GlossarySection('Essential documents', [
    GlossaryEntry(
      'Will',
      'The signed document stating who should receive what, and who should be '
          'in charge. Only the most recent valid will counts.',
    ),
    GlossaryEntry(
      'Codicil',
      'A formal amendment to an existing will. It changes part of the will '
          'rather than replacing it.',
    ),
    GlossaryEntry(
      'Death certificate',
      'The official record of death, issued by the registrar. Banks, insurers '
          'and the court will each ask for a copy, so order several certified '
          'copies at the outset.',
    ),
    GlossaryEntry(
      'Grant of Probate',
      'The court\u2019s written authority for you to deal with the estate. Also '
          'called simply \u201cthe Grant\u201d, and issued by the Probate Registry.',
      jurisdiction: _ewni,
    ),
    GlossaryEntry(
      'Letters of Administration',
      'The same authority, but granted when there is no will, or no executor '
          'able to act.',
      jurisdiction: _ewni,
    ),
    GlossaryEntry(
      'Confirmation',
      'Scotland\u2019s equivalent of Probate: the Sheriff Court\u2019s authority to '
          'deal with the estate. Assets cannot be sold or transferred without '
          'it.',
      jurisdiction: _scotland,
    ),
    GlossaryEntry(
      'Confirmation Inventory (Form C1)',
      'The detailed list of everything in the estate and what it is worth, '
          'lodged with the Sheriff Court alongside the tax paperwork. HMRC '
          'stamps it before the court can grant Confirmation.',
      jurisdiction: _scotland,
    ),
    GlossaryEntry(
      'Title deeds',
      'The documents proving ownership of a property. You will need them to '
          'sell or transfer it.',
    ),
  ]),
  GlossarySection('Tax and forms', [
    GlossaryEntry(
      'HMRC',
      'HM Revenue & Customs, the UK tax authority. You deal with it for the '
          'estate\u2019s tax forms and any tax owed.',
    ),
    GlossaryEntry(
      'Inheritance Tax (IHT)',
      'A tax on the value of an estate above a set threshold. The estate pays '
          'it rather than the beneficiaries, though in practice it comes out of '
          'what they would have received.',
    ),
    GlossaryEntry(
      'Nil rate band',
      'The amount that can be left before Inheritance Tax is due. At the time '
          'of writing it is £325,000 per person, with an additional allowance '
          'where a home passes to direct descendants.',
    ),
    GlossaryEntry(
      'Form IHT400',
      'The main Inheritance Tax account. It sets out everything in the estate, '
          'what it is worth and any reliefs, and HMRC calculates the tax from '
          'it.',
    ),
    GlossaryEntry(
      'Form IHT421',
      'HMRC\u2019s summary of the estate\u2019s tax position, used only when '
          'applying for a grant in Northern Ireland. Estates in England and '
          'Wales are sent probate figures and a unique reference by HMRC '
          'instead, and Scottish estates use Form C1.',
      jurisdiction: _northernIreland,
    ),
    GlossaryEntry(
      'Form IHT423',
      'The Direct Payment Scheme form. It asks banks and building societies to '
          'pay Inheritance Tax directly from the deceased\u2019s accounts, so you '
          'are not left finding the money up front.',
    ),
    GlossaryEntry(
      'Tax clearance',
      'HMRC confirming the estate\u2019s tax position is settled. In England and '
          'Wales this is now a letter or email rather than a stamped form: it '
          'carries a unique code and the estate\u2019s probate figures, which are '
          'entered in the online probate application. Nothing can proceed until '
          'it arrives, so it is worth starting early.',
    ),
  ]),
  GlossarySection('The process', [
    GlossaryEntry(
      'Estate',
      'Everything the person owned and owed: property, money, investments and '
          'belongings, less debts, funeral costs and tax.',
    ),
    GlossaryEntry(
      'Assets and liabilities',
      'What the person owned, and what they owed. The difference is what '
          'passes to the beneficiaries.',
    ),
    GlossaryEntry(
      'Executry',
      'The Scottish name for the whole job of winding up an estate. The person '
          'doing it is the executor; the process is the executry. Elsewhere this '
          'is usually called estate administration.',
      jurisdiction: _scotland,
    ),
    GlossaryEntry(
      'Probate',
      'The court process that confirms your authority to act, and loosely the '
          'authority itself. Often used to mean \u201cthe Grant\u201d.',
      jurisdiction: _ewni,
    ),
    GlossaryEntry(
      'Intestate / intestacy',
      'Dying without a valid will. Inheritance law then decides who receives '
          'what, which may differ from what the person intended. Someone must '
          'apply to be appointed to administer the estate.',
    ),
    GlossaryEntry(
      'Sheriff Court',
      'The court that grants Confirmation. The Confirmation Inventory and tax '
          'paperwork are lodged with the Sheriff Clerk.',
      jurisdiction: _scotland,
    ),
    GlossaryEntry(
      'Probate Registry',
      'The court office that issues the Grant.',
      jurisdiction: _ewni,
    ),
    GlossaryEntry(
      'Frozen accounts',
      'Bank and building society accounts are usually locked as soon as the '
          'bank learns of the death, and stay locked until Confirmation or '
          'Probate is granted. This app calls the resulting cash shortage the '
          '\u201ccash trap\u201d.',
    ),
    GlossaryEntry(
      'Court fee',
      'The fee payable for the Grant or Confirmation application.',
    ),
    GlossaryEntry(
      'The executor\u2019s year',
      'The rough twelve-month target for completing the estate. The law allows '
          'executors up to a year before beneficiaries can press for their '
          'inheritance.',
    ),
  ]),
  GlossarySection('In this app', [
    GlossaryEntry(
      'Invite code',
      'A six-character code that lets someone join an estate as an executor. '
          'Share it only with people you trust.',
    ),
    GlossaryEntry(
      'Sections',
      'How the record is organised: My Letter to You, What to Do First, Legal '
          'Documents, Who to Notify, Running the House, Funeral Arrangements, '
          'Cars, Confirmation and My Songs.',
    ),
    GlossaryEntry(
      'Process region',
      'Whether the estate is being handled in Scotland, or in England, Wales & '
          'Northern Ireland. It decides which legal steps the app shows.',
    ),
    GlossaryEntry(
      'Legal process',
      'The step-by-step path through Confirmation or Probate, with a checklist '
          'of what to do and when.',
    ),
    GlossaryEntry(
      'Annual estate review',
      'A yearly prompt for the estate owner to check that their details are '
          'still accurate.',
    ),
    GlossaryEntry(
      'My Letter to You',
      'A personal note the estate owner can leave, shown at the start of the '
          'record.',
    ),
  ]),
];
