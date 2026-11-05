/// Which scanned identity document a slot holds.
enum AboutYouDocument { passport, licence }

/// A single estate owner's identity record — the details an executor needs to
/// identify and administer that person's affairs.
///
/// Each estate can hold one record per owner. Alongside the text fields, each
/// record carries a scanned image of the owner's passport and driving licence,
/// stored in the `estate-documents` bucket under an `about-you/` prefix.
class AboutYou {
  final String aboutYouId;
  final String estateId;
  final String fullName;
  final String niNumber;
  final String chiNumber;
  final String passportStoragePath;
  final String passportDownloadUrl;
  final int passportFileSize;
  final String licenceStoragePath;
  final String licenceDownloadUrl;
  final int licenceFileSize;
  final DateTime createdAt;

  const AboutYou({
    required this.aboutYouId,
    required this.estateId,
    required this.fullName,
    required this.niNumber,
    required this.chiNumber,
    this.passportStoragePath = '',
    this.passportDownloadUrl = '',
    this.passportFileSize = 0,
    this.licenceStoragePath = '',
    this.licenceDownloadUrl = '',
    this.licenceFileSize = 0,
    required this.createdAt,
  });

  factory AboutYou.fromJson(Map<String, dynamic> json) {
    return AboutYou(
      aboutYouId: json['about_you_id'] as String,
      estateId: json['estate_id'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      niNumber: (json['ni_number'] as String?) ?? '',
      chiNumber: (json['chi_number'] as String?) ?? '',
      passportStoragePath: (json['passport_storage_path'] as String?) ?? '',
      passportDownloadUrl: (json['passport_download_url'] as String?) ?? '',
      passportFileSize: (json['passport_file_size'] as num?)?.toInt() ?? 0,
      licenceStoragePath: (json['licence_storage_path'] as String?) ?? '',
      licenceDownloadUrl: (json['licence_download_url'] as String?) ?? '',
      licenceFileSize: (json['licence_file_size'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'estate_id': estateId,
      'full_name': fullName,
      'ni_number': niNumber,
      'chi_number': chiNumber,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'full_name': fullName,
      'ni_number': niNumber,
      'chi_number': chiNumber,
      'passport_storage_path': passportStoragePath,
      'passport_download_url': passportDownloadUrl,
      'passport_file_size': passportFileSize,
      'licence_storage_path': licenceStoragePath,
      'licence_download_url': licenceDownloadUrl,
      'licence_file_size': licenceFileSize,
    };
  }

  String storagePathFor(AboutYouDocument doc) =>
      doc == AboutYouDocument.passport
          ? passportStoragePath
          : licenceStoragePath;

  int fileSizeFor(AboutYouDocument doc) =>
      doc == AboutYouDocument.passport ? passportFileSize : licenceFileSize;

  bool hasDocument(AboutYouDocument doc) =>
      storagePathFor(doc).isNotEmpty && downloadUrlFor(doc).isNotEmpty;

  String downloadUrlFor(AboutYouDocument doc) => doc == AboutYouDocument.passport
      ? passportDownloadUrl
      : licenceDownloadUrl;

  /// Returns a copy with one document slot replaced (path, URL and size).
  AboutYou withDocument(
    AboutYouDocument doc, {
    required String storagePath,
    required String downloadUrl,
    required int fileSize,
  }) {
    return doc == AboutYouDocument.passport
        ? copyWith(
            passportStoragePath: storagePath,
            passportDownloadUrl: downloadUrl,
            passportFileSize: fileSize,
          )
        : copyWith(
            licenceStoragePath: storagePath,
            licenceDownloadUrl: downloadUrl,
            licenceFileSize: fileSize,
          );
  }

  /// Returns a copy with one document slot cleared.
  AboutYou withoutDocument(AboutYouDocument doc) => doc == AboutYouDocument.passport
      ? copyWith(
          passportStoragePath: '',
          passportDownloadUrl: '',
          passportFileSize: 0,
        )
      : copyWith(
          licenceStoragePath: '',
          licenceDownloadUrl: '',
          licenceFileSize: 0,
        );

  AboutYou copyWith({
    String? fullName,
    String? niNumber,
    String? chiNumber,
    String? passportStoragePath,
    String? passportDownloadUrl,
    int? passportFileSize,
    String? licenceStoragePath,
    String? licenceDownloadUrl,
    int? licenceFileSize,
  }) {
    return AboutYou(
      aboutYouId: aboutYouId,
      estateId: estateId,
      fullName: fullName ?? this.fullName,
      niNumber: niNumber ?? this.niNumber,
      chiNumber: chiNumber ?? this.chiNumber,
      passportStoragePath: passportStoragePath ?? this.passportStoragePath,
      passportDownloadUrl: passportDownloadUrl ?? this.passportDownloadUrl,
      passportFileSize: passportFileSize ?? this.passportFileSize,
      licenceStoragePath: licenceStoragePath ?? this.licenceStoragePath,
      licenceDownloadUrl: licenceDownloadUrl ?? this.licenceDownloadUrl,
      licenceFileSize: licenceFileSize ?? this.licenceFileSize,
      createdAt: createdAt,
    );
  }
}
