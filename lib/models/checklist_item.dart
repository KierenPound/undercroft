class ChecklistItem {
  final String id;
  final String sectionId;
  final String text;
  final bool isCompleted;
  final int orderIndex;
  final DateTime createdAt;

  const ChecklistItem({
    required this.id,
    required this.sectionId,
    required this.text,
    required this.isCompleted,
    required this.orderIndex,
    required this.createdAt,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      sectionId: json['section_id'] as String,
      text: json['text'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      orderIndex: json['order_index'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'section_id': sectionId,
      'text': text,
      'is_completed': isCompleted,
      'order_index': orderIndex,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'text': text,
      'is_completed': isCompleted,
      'order_index': orderIndex,
    };
  }

  ChecklistItem copyWith({
    String? text,
    bool? isCompleted,
    int? orderIndex,
  }) {
    return ChecklistItem(
      id: id,
      sectionId: sectionId,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt,
    );
  }
}
