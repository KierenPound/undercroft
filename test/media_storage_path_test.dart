import 'package:flutter_test/flutter_test.dart';
import 'package:undercroft/models/about_you.dart';
import 'package:undercroft/models/attachment.dart';
import 'package:undercroft/models/prep_section.dart';
import 'package:undercroft/models/utility_detail.dart';

void main() {
  const legacyPath = 'estate-documents/estate-id/sections/file.pdf';

  test('legacy attachment paths become missing files', () {
    final attachment = Attachment.fromJson({
      'id': 'attachment-id',
      'section_id': 'section-id',
      'file_name': 'file.pdf',
      'type': 'pdf',
      'storage_path': legacyPath,
      'download_url': 'https://old-storage.example/file.pdf',
      'file_size': 123,
      'created_at': '2026-11-19T00:00:00Z',
    });

    expect(attachment.storagePath, isEmpty);
    expect(attachment.downloadUrl, isEmpty);
    expect(attachment.fileSize, 0);
  });

  test('legacy identity-document paths become missing files', () {
    final aboutYou = AboutYou.fromJson({
      'about_you_id': 'about-you-id',
      'estate_id': 'estate-id',
      'passport_storage_path': legacyPath,
      'passport_download_url': 'https://old-storage.example/passport.jpg',
      'passport_file_size': 123,
      'licence_storage_path': '',
      'licence_download_url': '',
      'licence_file_size': 0,
      'created_at': '2026-11-19T00:00:00Z',
    });

    expect(aboutYou.hasDocument(AboutYouDocument.passport), isFalse);
    expect(aboutYou.passportStoragePath, isEmpty);
    expect(aboutYou.passportFileSize, 0);
    expect(aboutYou.toUpdateJson()['passport_download_url'], isEmpty);
  });

  test('legacy video and utility paths become missing files', () {
    final section = PrepSection.fromJson({
      'id': 'section-id',
      'estate_id': 'estate-id',
      'video_path': legacyPath,
      'video_mime': 'video/mp4',
      'video_size_bytes': 123,
      'created_at': '2026-11-19T00:00:00Z',
      'updated_at': '2026-11-19T00:00:00Z',
    });
    final utility = UtilityDetail.fromJson({
      'utility_detail_id': 'utility-id',
      'estate_id': 'estate-id',
      'kind': 'gas_meter',
      'storage_path': legacyPath,
      'updated_at': '2026-11-19T00:00:00Z',
    });

    expect(section.videoPath, isEmpty);
    expect(section.videoMime, isEmpty);
    expect(section.videoSizeBytes, 0);
    expect(utility.storagePath, isEmpty);
    expect(utility.imageUrl, isEmpty);
  });
}
