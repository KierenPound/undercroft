import 'package:flutter_test/flutter_test.dart';
import 'package:undercroft/models/about_you.dart';
import 'package:undercroft/models/ad_hoc_data.dart';
import 'package:undercroft/models/attachment.dart';
import 'package:undercroft/models/checklist_item.dart';
import 'package:undercroft/models/contact.dart';
import 'package:undercroft/models/funeral_arrangement.dart';
import 'package:undercroft/models/notify_account_details.dart';
import 'package:undercroft/models/prep_section.dart';
import 'package:undercroft/models/tradesperson.dart';
import 'package:undercroft/models/utility_detail.dart';
import 'package:undercroft/models/who_to_notify.dart';

void main() {
  test('model factories default absent text and invalid dates safely', () {
    final before = DateTime.now().subtract(const Duration(seconds: 1));
    final prepSection = PrepSection.fromJson({
      'id': 'section-id',
      'estate_id': 'estate-id',
      'created_at': null,
      'updated_at': 'not-a-date',
    });
    final attachment = Attachment.fromJson({
      'id': 'attachment-id',
      'section_id': 'section-id',
      'created_at': null,
    });
    final aboutYou = AboutYou.fromJson({
      'about_you_id': 'about-you-id',
      'estate_id': 'estate-id',
      'created_at': 'invalid',
    });
    final adHocData = AdHocData.fromJson({
      'ad_hoc_data_id': 'ad-hoc-id',
      'estate_id': 'estate-id',
      'created_at': null,
    });
    final checklistItem = ChecklistItem.fromJson({
      'id': 'checklist-id',
      'section_id': 'section-id',
      'created_at': null,
    });
    final contact = Contact.fromJson({
      'contact_id': 'contact-id',
      'estate_id': 'estate-id',
      'created_at': null,
    });
    final funeralArrangement = FuneralArrangement.fromJson({
      'funeral_arrangement_id': 'funeral-id',
      'estate_id': 'estate-id',
      'created_at': null,
    });
    final tradesperson = Tradesperson.fromJson({
      'tradesperson_id': 'tradesperson-id',
      'estate_id': 'estate-id',
      'created_at': null,
    });
    final utilityDetail = UtilityDetail.fromJson({
      'utility_detail_id': 'utility-id',
      'estate_id': 'estate-id',
      'updated_at': null,
    });
    final whoToNotify = WhoToNotify.fromJson({
      'who_to_notify_id': 'organisation-id',
      'estate_id': 'estate-id',
      'created_at': null,
    });
    final accountDetails = NotifyAccountDetails.fromJson({
      'notify_account_details_id': 'account-details-id',
      'who_to_notify_id': 'organisation-id',
      'created_at': null,
    });
    final after = DateTime.now().add(const Duration(seconds: 1));

    expect(prepSection.title, '');
    expect(prepSection.notes, '');
    expect(attachment.fileName, '');
    expect(checklistItem.text, '');
    expect(funeralArrangement.name, '');
    expect(whoToNotify.companyName, '');
    expect(aboutYou.fullName, '');
    expect(adHocData.title, '');
    expect(contact.name, '');
    expect(tradesperson.name, '');
    expect(utilityDetail.notes, '');

    final parsedDates = [
      prepSection.createdAt,
      prepSection.updatedAt,
      attachment.createdAt,
      aboutYou.createdAt,
      adHocData.createdAt,
      checklistItem.createdAt,
      contact.createdAt,
      funeralArrangement.createdAt,
      tradesperson.createdAt,
      utilityDetail.updatedAt,
      whoToNotify.createdAt,
      accountDetails.createdAt,
    ];
    expect(parsedDates.every((date) => date.isAfter(before)), isTrue);
    expect(parsedDates.every((date) => date.isBefore(after)), isTrue);
  });

  test('required identifiers remain strict', () {
    expect(
      () => Attachment.fromJson({'section_id': 'section-id'}),
      throwsA(isA<TypeError>()),
    );
  });
}
