enum AttachmentType { photo, pdf, unknown }

class Attachment {
  final String id;
  final String sectionId;
  final String fileName;
  final AttachmentType type;
  final String storagePath;
  final String downloadUrl;
  final int fileSize;
  final DateTime createdAt;

  const Attachment({
    required this.id,
    required this.sectionId,
    required this.fileName,
    required this.type,
    required this.storagePath,
    required this.downloadUrl,
    required this.fileSize,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? 'unknown').toLowerCase();
    AttachmentType type;
    switch (typeStr) {
      case 'photo':
        type = AttachmentType.photo;
        break;
      case 'pdf':
        type = AttachmentType.pdf;
        break;
      default:
        type = AttachmentType.unknown;
    }

    return Attachment(
      id: json['id'] as String,
      sectionId: json['section_id'] as String,
      fileName: json['file_name'] as String,
      type: type,
      storagePath: json['storage_path'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      fileSize: json['file_size'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'section_id': sectionId,
      'file_name': fileName,
      'type': type.name,
      'storage_path': storagePath,
      'download_url': downloadUrl,
      'file_size': fileSize,
    };
  }

  Attachment copyWith({
    String? id,
    String? sectionId,
    String? fileName,
    AttachmentType? type,
    String? storagePath,
    String? downloadUrl,
    int? fileSize,
    DateTime? createdAt,
  }) {
    return Attachment(
      id: id ?? this.id,
      sectionId: sectionId ?? this.sectionId,
      fileName: fileName ?? this.fileName,
      type: type ?? this.type,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get formattedSize {
    if (fileSize <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = fileSize.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}
