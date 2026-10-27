import 'package:flutter/material.dart';

/// Confirmation rich-content dashboard.
///
/// Cloned from the FamilyPrep (iOS) `ConfirmationDashboardView`, covering the
/// sections from "You're almost done" through to "Receive the Grant of
/// Confirmation & Unlock the Cash" — i.e. everything between the Memory photo
/// (handled by [PhotoSection]) and the Song for the page
/// (handled by [SongForThePageSection]).
class ConfirmationDashboard extends StatelessWidget {
  const ConfirmationDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIntroAlmostDoneSection(),
        const SizedBox(height: 28),
        _buildLocateWillSection(),
        const SizedBox(height: 28),
        _buildDateOfDeathValuationsSection(),
        const SizedBox(height: 28),
        _buildHmrcReferenceSection(),
        const SizedBox(height: 28),
        _buildTaxFormsSection(),
        const SizedBox(height: 28),
        _buildPayTaxSection(),
        const SizedBox(height: 28),
        _buildIht421AndCourtSection(),
        const SizedBox(height: 28),
        _buildGrantConfirmationSection(),
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

  Widget _formCard({
    required String title,
    required IconData icon,
    required Color tint,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: tint, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2C2E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCallout({
    required Color tint,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.22), width: 0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C2C2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBlock({
    required IconData icon,
    required Color tint,
    required int stepNumber,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$stepNumber',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: tint,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2C2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _postalCard({required String address, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.22), width: 0.6),
      ),
      child: Text(
        address,
        style: const TextStyle(
          fontSize: 15,
          fontFamily: 'monospace',
          color: Color(0xFF2C2C2E),
        ),
      ),
    );
  }

  Widget _flowChipRow({required List<String> items, required Color tint}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tint,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // MARK: - You're almost done (Intro)

  Widget _buildIntroAlmostDoneSection() {
    const tint = Colors.teal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: "You're almost done",
          icon: Icons.auto_awesome,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "As the end is near, what better than a musical interlude "
                  "to set you up for the hardest (and most lucrative) steps.  "
                  "Please play the Song for the day at the end and think of us, "
                  "kindly.  Or laugh.  Hopefully both!",
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified,
                          color: Colors.teal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You've got this",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Everything from here on is linear paperwork.  "
                            "Take it one card at a time and you'll be done in "
                            "a few weeks.",
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
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

  // MARK: - Locate the Will

  Widget _buildLocateWillSection() {
    const tint = Colors.purple;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Locate the Will & Identify the Executors',
          icon: Icons.draw,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Before touching any accounts, find the original paper Will.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C2C2E),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Why it matters:  The Will explicitly names the Executors.  '
                  'These are the only people legally allowed to sign the '
                  'upcoming HMRC tax returns and court inventories.',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.find_in_page,
                          color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'The Original Document',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'A photocopy is useless for the court.  The '
                            'physical paper original must be kept safe.  It is '
                            'located in the bureau',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '[The master copy is held securely at the solicitors]',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C2C2E),
                              ),
                            ),
                          ),
                        ],
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

  // MARK: - Date of Death Valuations

  Widget _buildDateOfDeathValuationsSection() {
    const tint = Colors.orange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Request "Date of Death" Valuations',
          icon: Icons.balance,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You must get the exact financial value of everything owned '
                  'on the specific day of passing.  Contact each company below '
                  'and ask for a "Date of Death Balance Certificate":',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.brown.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          const Icon(Icons.home, color: Colors.brown, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The Houses',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'You must get a formal, written valuation from a '
                            'chartered surveyor or a local estate agent for the '
                            'open-market value of all the properties',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance,
                          color: Colors.indigo, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'The Banks',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Contact the following for final balances across '
                            'all listed account numbers (see Who to Contact):',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          _flowChipRow(
                            items: const [
                              'TSB',
                              'Starling',
                              'Tembo',
                              'NS&I',
                              'eToro',
                            ],
                            tint: Colors.indigo,
                          ),
                        ],
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

  // MARK: - HMRC Tax Reference

  Widget _buildHmrcReferenceSection() {
    const tint = Colors.indigo;
    const mint = Color(0xFF00C7BE);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Get an HMRC Tax Reference Number',
          icon: Icons.onetwothree,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.public,
                          color: Colors.indigo, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The Action',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Go online to GOV.UK and apply for an Inheritance '
                            'Tax Reference Number using Form IHT422.',
                            style: TextStyle(
                                fontSize: 15, color: Color(0xFF2C2C2E)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: mint.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.schedule, color: mint, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The Timeline',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Do this immediately after getting your '
                            'valuations.  It takes HMRC about 3 weeks to '
                            'generate and post this reference number to you, '
                            'and you cannot pay the tax or submit forms '
                            'without it.',
                            style: TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                        ],
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

  // MARK: - HMRC Tax Forms

  Widget _buildTaxFormsSection() {
    const tint = Colors.blue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Fill in the HMRC Tax Forms',
          icon: Icons.description,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Once you have your reference number and all your exact '
                  'estate values, the executors must complete the heavy tax '
                  'paperwork:',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _formCard(
                  title: 'Form IHT400 (The Inheritance Tax Account)',
                  icon: Icons.article,
                  tint: Colors.blue,
                  body: 'This is the main, comprehensive 16-page tax return '
                      'where you list everything, including the house '
                      'valuations, bank cash, and any major gifts given away '
                      'in the last 7 years.',
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _formCard(
                  title: 'Form C1 (The Confirmation Inventory)',
                  icon: Icons.account_balance,
                  tint: Colors.purple,
                  body: 'This is the Scottish court form where you list the '
                      'exact same assets line-by-line.  You must fill this in '
                      'alongside your tax return.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Pay the Tax

  Widget _buildPayTaxSection() {
    const tint = Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Pay the Tax (Bypassing the Cash Trap)',
          icon: Icons.payments,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HMRC expects you to pay the tax bill before the court will '
                  'grant Confirmation.  To clear this hurdle without spending '
                  'your own personal money, use these tools:',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _infoCallout(
                  tint: Colors.indigo,
                  icon: Icons.assignment,
                  title: 'Form IHT423 (The Direct Payment Scheme)',
                  body: 'Complete a copy of this form for TSB and Starling.  '
                      'This sends a legal instruction to the banks to pull '
                      'money directly from my frozen accounts and wire it '
                      'straight to HMRC to clear the tax bill.  We\'ll try to '
                      'ensure there is cash enough to do this',
                ),
                const SizedBox(height: 12),
                _infoCallout(
                  tint: Colors.brown,
                  icon: Icons.cottage,
                  title: 'The Property Installment Option',
                  body: 'Because much of the value is tied up in '
                      'bricks-and-mortar (Rowanbank and 5 Grey Row), HMRC '
                      'allows the tax owed on houses to be split into 10 '
                      'annual installments.  You only need to pay the first '
                      '10% installment upfront to pass this step.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - IHT421 Stamped Cert + Perth Sheriff Court

  Widget _buildIht421AndCourtSection() {
    const tint = Colors.red;
    const courtPackageItems = [
      'Your completed Form C1 (Asset Inventory)',
      'The Original physical paper Will',
      'A certified copy of the Death Certificate',
      'The required Court Submission Fee',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'IHT421 Stamped Certificate & Perth Sheriff Court',
          icon: Icons.mail,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stepBlock(
                  icon: Icons.upload_file,
                  tint: Colors.red,
                  stepNumber: 1,
                  title: 'Mail IHT400 to HMRC',
                  body: 'Mail your completed Form IHT400 to:',
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: _postalCard(
                    address: 'HM Revenue and Customs\nBX9 1HT',
                    tint: Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _stepBlock(
                  icon: Icons.verified_user,
                  tint: Colors.orange,
                  stepNumber: 2,
                  title: 'Wait for the stamped IHT421 certificate',
                  body: 'Once HMRC receives your paperwork and checks that the '
                      'tax payment from Step 5 has cleared, they will not send '
                      'you a physical receipt.  Instead, they will generate a '
                      'secure, stamped digital certificate called an IHT421 '
                      '(or an online clearance code).  They will send this '
                      'code directly to the court as proof that the tax hurdle '
                      'is cleared.',
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _stepBlock(
                  icon: Icons.account_balance,
                  tint: Colors.purple,
                  stepNumber: 3,
                  title: 'Submit to the Perth Sheriff Court',
                  body: 'Once HMRC issues your tax clearance code, mail your '
                      'final court package to the Perth Sheriff Court:',
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: courtPackageItems
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 7),
                                  child: Icon(Icons.circle,
                                      size: 6, color: Colors.purple),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                        fontSize: 15, color: Color(0xFF2C2C2E)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Receive Grant of Confirmation

  Widget _buildGrantConfirmationSection() {
    const tint = Colors.teal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Receive the Grant of Confirmation & Unlock the Cash',
          icon: Icons.verified,
          tint: tint,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The Sheriff Court will review the Will and inventory.  '
                  'Within 2 to 4 weeks, they will issue the formal Grant of '
                  'Confirmation.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.celebration,
                          color: Colors.green, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The End!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'If you have reached here, well done! '
                            'I know it has been a lot of paperwork, but it  '
                            'only has to be done once ',
                            style: TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                _infoCallout(
                  tint: Colors.teal,
                  icon: Icons.menu_book,
                  title: '🏡 Note on the properties',
                  body: 'You cannot update the house deeds yourself.  In '
                      'Scotland, property records are held by Registers of '
                      'Scotland (RoS).  Once you receive the Grant of '
                      'Confirmation from the court, you must hand it to a '
                      'Scottish solicitor (see Legal Documents). '
                      'They will draft a legal document called a '
                      'Disposition to either transfer the titles to '
                      'the family or manage the sale of the properties.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
