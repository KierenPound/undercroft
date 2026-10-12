import 'attachment.dart';
import 'checklist_item.dart';

class PrepSection {
  final String id;
  final String estateId;
  final String title;
  final int orderIndex;
  final bool isStandard;
  final String notes;
  final String youtubeUrl;
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
    required this.youtubeUrl,
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
      youtubeUrl: json['youtube_url'] as String? ?? '',
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
      'youtube_url': youtubeUrl,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'order_index': orderIndex,
      'is_standard': isStandard,
      'notes': notes,
      'youtube_url': youtubeUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  PrepSection copyWith({
    String? notes,
    String? youtubeUrl,
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
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      checklistItems: checklistItems ?? this.checklistItems,
      attachments: attachments ?? this.attachments,
    );
  }
}
