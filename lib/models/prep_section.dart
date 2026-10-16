import 'attachment.dart';
import 'checklist_item.dart';

class PrepSection {
  final String id;
  final String estateId;
  final String title;
  final int orderIndex;
  final bool isStandard;
  final String notes;
  final String letterText;
  final String youtubeUrl;
  final String registrarPhone;
  final String registrarEmail;
  final String certifiedCopiesUrl;
  final String solicitorPhone;
  final String solicitorEmail;
  final String solicitorUrl;
  final String phonePin1;
  final String computerPassword1;
  final String phonePin2;
  final String computerPassword2;
  final String petNotes;
  final String vetName;
  final String vetPhone;
  final String vetUrl;
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
    required this.youtubeUrl,
    required this.registrarPhone,
    required this.registrarEmail,
    required this.certifiedCopiesUrl,
    required this.solicitorPhone,
    required this.solicitorEmail,
    required this.solicitorUrl,
    required this.phonePin1,
    required this.computerPassword1,
    required this.phonePin2,
    required this.computerPassword2,
    required this.petNotes,
    required this.vetName,
    required this.vetPhone,
    required this.vetUrl,
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
      youtubeUrl: json['youtube_url'] as String? ?? '',
      registrarPhone: json['registrar_phone'] as String? ?? '',
      registrarEmail: json['registrar_email'] as String? ?? '',
      certifiedCopiesUrl: json['certified_copies_url'] as String? ?? '',
      solicitorPhone: json['solicitor_phone'] as String? ?? '',
      solicitorEmail: json['solicitor_email'] as String? ?? '',
      solicitorUrl: json['solicitor_url'] as String? ?? '',
      phonePin1: json['phone_pin_1'] as String? ?? '',
      computerPassword1: json['computer_password_1'] as String? ?? '',
      phonePin2: json['phone_pin_2'] as String? ?? '',
      computerPassword2: json['computer_password_2'] as String? ?? '',
      petNotes: json['pet_notes'] as String? ?? '',
      vetName: json['vet_name'] as String? ?? 'Tower vets',
      vetPhone: json['vet_phone'] as String? ?? '01738 583083',
      vetUrl: json['vet_url'] as String? ??
          'https://ivc.co.uk/find-a-vet/tower-vets-perth?utm_source=gmb&utm_medium=organic&utm_campaign=attribute',
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
      'youtube_url': youtubeUrl,
      'registrar_phone': registrarPhone,
      'registrar_email': registrarEmail,
      'certified_copies_url': certifiedCopiesUrl,
      'solicitor_phone': solicitorPhone,
      'solicitor_email': solicitorEmail,
      'solicitor_url': solicitorUrl,
      'phone_pin_1': phonePin1,
      'computer_password_1': computerPassword1,
      'phone_pin_2': phonePin2,
      'computer_password_2': computerPassword2,
      'pet_notes': petNotes,
      'vet_name': vetName,
      'vet_phone': vetPhone,
      'vet_url': vetUrl,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'order_index': orderIndex,
      'is_standard': isStandard,
      'notes': notes,
      'letter_text': letterText,
      'youtube_url': youtubeUrl,
      'registrar_phone': registrarPhone,
      'registrar_email': registrarEmail,
      'certified_copies_url': certifiedCopiesUrl,
      'solicitor_phone': solicitorPhone,
      'solicitor_email': solicitorEmail,
      'solicitor_url': solicitorUrl,
      'phone_pin_1': phonePin1,
      'computer_password_1': computerPassword1,
      'phone_pin_2': phonePin2,
      'computer_password_2': computerPassword2,
      'pet_notes': petNotes,
      'vet_name': vetName,
      'vet_phone': vetPhone,
      'vet_url': vetUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  PrepSection copyWith({
    String? notes,
    String? letterText,
    String? youtubeUrl,
    String? registrarPhone,
    String? registrarEmail,
    String? certifiedCopiesUrl,
    String? solicitorPhone,
    String? solicitorEmail,
    String? solicitorUrl,
    String? phonePin1,
    String? computerPassword1,
    String? phonePin2,
    String? computerPassword2,
    String? petNotes,
    String? vetName,
    String? vetPhone,
    String? vetUrl,
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
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      registrarPhone: registrarPhone ?? this.registrarPhone,
      registrarEmail: registrarEmail ?? this.registrarEmail,
      certifiedCopiesUrl: certifiedCopiesUrl ?? this.certifiedCopiesUrl,
      solicitorPhone: solicitorPhone ?? this.solicitorPhone,
      solicitorEmail: solicitorEmail ?? this.solicitorEmail,
      solicitorUrl: solicitorUrl ?? this.solicitorUrl,
      phonePin1: phonePin1 ?? this.phonePin1,
      computerPassword1: computerPassword1 ?? this.computerPassword1,
      phonePin2: phonePin2 ?? this.phonePin2,
      computerPassword2: computerPassword2 ?? this.computerPassword2,
      petNotes: petNotes ?? this.petNotes,
      vetName: vetName ?? this.vetName,
      vetPhone: vetPhone ?? this.vetPhone,
      vetUrl: vetUrl ?? this.vetUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      checklistItems: checklistItems ?? this.checklistItems,
      attachments: attachments ?? this.attachments,
    );
  }
}
