import 'attachment.dart';
import 'checklist_item.dart';

class PrepSection {
  static const String defaultSolicitorIntro =
      'The solicitors hold the master documents.';

  final String id;
  final String estateId;
  final String title;
  final int orderIndex;
  final bool isStandard;
  final String notes;
  final String letterText;
  final String songsCsv;
  final String youtubeUrl;
  final String registrarPhone;
  final String registrarEmail;
  final String certifiedCopiesUrl;
  final String solicitorIntro;
  final String solicitorPhone;
  final String solicitorEmail;
  final String solicitorUrl;
  final String phonePin1;
  final String computerPassword1;
  final String phonePin2;
  final String computerPassword2;
  final String wifiPassword;
  final String petNotes;
  final String vetName;
  final String vetPhone;
  final String vetUrl;
  final String petInsuranceCompany;
  final String petPolicyNumber;
  final String petMicrochipNumber;

  /// Storage object path of the "My Video to You" clip in the private
  /// `estate-documents` bucket. Empty means no video has been added.
  final String videoPath;
  final String videoMime;
  final int videoSizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChecklistItem> checklistItems;
  final List<Attachment> attachments;

  const PrepSection({
    required this.id,
    required this.estateId,
    required this.title,
    required this.orderIndex,
    required this.isStandard,
    required this.notes,
    required this.letterText,
    required this.songsCsv,
    required this.youtubeUrl,
    required this.registrarPhone,
    required this.registrarEmail,
    required this.certifiedCopiesUrl,
    required this.solicitorIntro,
    required this.solicitorPhone,
    required this.solicitorEmail,
    required this.solicitorUrl,
    required this.phonePin1,
    required this.computerPassword1,
    required this.phonePin2,
    required this.computerPassword2,
    required this.wifiPassword,
    required this.petNotes,
    required this.vetName,
    required this.vetPhone,
    required this.vetUrl,
    this.petInsuranceCompany = '',
    this.petPolicyNumber = '',
    this.petMicrochipNumber = '',
    this.videoPath = '',
    this.videoMime = '',
    this.videoSizeBytes = 0,
    required this.createdAt,
    required this.updatedAt,
    this.checklistItems = const [],
    this.attachments = const [],
  });

  factory PrepSection.fromJson(Map<String, dynamic> json) {
    return PrepSection(
      id: json['id'] as String,
      estateId: json['estate_id'] as String,
      title: json['title'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      isStandard: json['is_standard'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      letterText: json['letter_text'] as String? ?? '',
      songsCsv: json['songs_csv'] as String? ?? '',
      youtubeUrl: json['youtube_url'] as String? ?? '',
      registrarPhone: json['registrar_phone'] as String? ?? '',
      registrarEmail: json['registrar_email'] as String? ?? '',
      certifiedCopiesUrl: json['certified_copies_url'] as String? ?? '',
      solicitorIntro: json['solicitor_intro'] as String? ?? '',
      solicitorPhone: json['solicitor_phone'] as String? ?? '',
      solicitorEmail: json['solicitor_email'] as String? ?? '',
      solicitorUrl: json['solicitor_url'] as String? ?? '',
      phonePin1: json['phone_pin_1'] as String? ?? '',
      computerPassword1: json['computer_password_1'] as String? ?? '',
      phonePin2: json['phone_pin_2'] as String? ?? '',
      computerPassword2: json['computer_password_2'] as String? ?? '',
      wifiPassword: json['wifi_password'] as String? ?? '',
      petNotes: json['pet_notes'] as String? ?? '',
      vetName: json['vet_name'] as String? ?? '',
      vetPhone: json['vet_phone'] as String? ?? '',
      vetUrl: json['vet_url'] as String? ?? '',
      petInsuranceCompany: json['pet_insurance_company'] as String? ?? '',
      petPolicyNumber: json['pet_policy_number'] as String? ?? '',
      petMicrochipNumber: json['pet_microchip_number'] as String? ?? '',
      videoPath: json['video_path'] as String? ?? '',
      videoMime: json['video_mime'] as String? ?? '',
      videoSizeBytes: (json['video_size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'estate_id': estateId,
      'title': title,
      'order_index': orderIndex,
      'is_standard': isStandard,
      'notes': notes,
      'letter_text': letterText,
      'songs_csv': songsCsv,
      'youtube_url': youtubeUrl,
      'registrar_phone': registrarPhone,
      'registrar_email': registrarEmail,
      'certified_copies_url': certifiedCopiesUrl,
      'solicitor_intro': solicitorIntro,
      'solicitor_phone': solicitorPhone,
      'solicitor_email': solicitorEmail,
      'solicitor_url': solicitorUrl,
      'phone_pin_1': phonePin1,
      'computer_password_1': computerPassword1,
      'phone_pin_2': phonePin2,
      'computer_password_2': computerPassword2,
      'wifi_password': wifiPassword,
      'pet_notes': petNotes,
      'vet_name': vetName,
      'vet_phone': vetPhone,
      'vet_url': vetUrl,
      'pet_insurance_company': petInsuranceCompany,
      'pet_policy_number': petPolicyNumber,
      'pet_microchip_number': petMicrochipNumber,
      'video_path': videoPath,
      'video_mime': videoMime,
      'video_size_bytes': videoSizeBytes,
    };
  }

  /// The columns a generic section save writes back.
  ///
  /// The video columns are deliberately absent: the video is only ever written
  /// through the dedicated repository methods, so a letter autosave can never
  /// wipe a clip that was uploaded after the editor last read the row.
  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'order_index': orderIndex,
      'is_standard': isStandard,
      'notes': notes,
      'letter_text': letterText,
      'songs_csv': songsCsv,
      'youtube_url': youtubeUrl,
      'registrar_phone': registrarPhone,
      'registrar_email': registrarEmail,
      'certified_copies_url': certifiedCopiesUrl,
      'solicitor_intro': solicitorIntro,
      'solicitor_phone': solicitorPhone,
      'solicitor_email': solicitorEmail,
      'solicitor_url': solicitorUrl,
      'phone_pin_1': phonePin1,
      'computer_password_1': computerPassword1,
      'phone_pin_2': phonePin2,
      'computer_password_2': computerPassword2,
      'wifi_password': wifiPassword,
      'pet_notes': petNotes,
      'vet_name': vetName,
      'vet_phone': vetPhone,
      'vet_url': vetUrl,
      'pet_insurance_company': petInsuranceCompany,
      'pet_policy_number': petPolicyNumber,
      'pet_microchip_number': petMicrochipNumber,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  PrepSection copyWith({
    String? notes,
    String? letterText,
    String? songsCsv,
    String? youtubeUrl,
    String? registrarPhone,
    String? registrarEmail,
    String? certifiedCopiesUrl,
    String? solicitorIntro,
    String? solicitorPhone,
    String? solicitorEmail,
    String? solicitorUrl,
    String? phonePin1,
    String? computerPassword1,
    String? phonePin2,
    String? computerPassword2,
    String? wifiPassword,
    String? petNotes,
    String? vetName,
    String? vetPhone,
    String? vetUrl,
    String? petInsuranceCompany,
    String? petPolicyNumber,
    String? petMicrochipNumber,
    String? videoPath,
    String? videoMime,
    int? videoSizeBytes,
    List<ChecklistItem>? checklistItems,
    List<Attachment>? attachments,
  }) {
    return PrepSection(
      id: id,
      estateId: estateId,
      title: title,
      orderIndex: orderIndex,
      isStandard: isStandard,
      notes: notes ?? this.notes,
      letterText: letterText ?? this.letterText,
      songsCsv: songsCsv ?? this.songsCsv,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      registrarPhone: registrarPhone ?? this.registrarPhone,
      registrarEmail: registrarEmail ?? this.registrarEmail,
      certifiedCopiesUrl: certifiedCopiesUrl ?? this.certifiedCopiesUrl,
      solicitorIntro: solicitorIntro ?? this.solicitorIntro,
      solicitorPhone: solicitorPhone ?? this.solicitorPhone,
      solicitorEmail: solicitorEmail ?? this.solicitorEmail,
      solicitorUrl: solicitorUrl ?? this.solicitorUrl,
      phonePin1: phonePin1 ?? this.phonePin1,
      computerPassword1: computerPassword1 ?? this.computerPassword1,
      phonePin2: phonePin2 ?? this.phonePin2,
      computerPassword2: computerPassword2 ?? this.computerPassword2,
      wifiPassword: wifiPassword ?? this.wifiPassword,
      petNotes: petNotes ?? this.petNotes,
      vetName: vetName ?? this.vetName,
      vetPhone: vetPhone ?? this.vetPhone,
      vetUrl: vetUrl ?? this.vetUrl,
      petInsuranceCompany:
          petInsuranceCompany ?? this.petInsuranceCompany,
      petPolicyNumber: petPolicyNumber ?? this.petPolicyNumber,
      petMicrochipNumber: petMicrochipNumber ?? this.petMicrochipNumber,
      videoPath: videoPath ?? this.videoPath,
      videoMime: videoMime ?? this.videoMime,
      videoSizeBytes: videoSizeBytes ?? this.videoSizeBytes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      checklistItems: checklistItems ?? this.checklistItems,
      attachments: attachments ?? this.attachments,
    );
  }
}
