import 'package:flutter/material.dart';

/// The three utilities shown on the Running the Houses page.
enum UtilityKind {
  gasMeter(
    'gas_meter',
    'Gas meter',
    Icons.local_fire_department,
    Colors.orange,
  ),
  electricMeter('electric_meter', 'Electric meter', Icons.bolt, Colors.amber),
  stopcock('stopcock', 'Stopcock', Icons.water_drop, Colors.teal);

  const UtilityKind(this.dbValue, this.label, this.icon, this.tint);

  /// Value stored in the `utility_details.kind` column.
  final String dbValue;
  final String label;
  final IconData icon;
  final Color tint;

  static UtilityKind fromDb(String value) => UtilityKind.values.firstWhere(
        (kind) => kind.dbValue == value,
        orElse: () => UtilityKind.gasMeter,
      );
}

/// Where a utility lives and how to read it: a photo of the meter or
/// stopcock, plus the description beside it. One row per [kind] per estate.
class UtilityDetail {
  final String utilityDetailId;
  final String estateId;
  final UtilityKind kind;
  final String notes;
  final String storagePath;

  /// Signed URL for [storagePath], resolved when the row is fetched. Empty
  /// when no photo has been uploaded yet, and never written back to the
  /// database.
  final String imageUrl;

  final DateTime updatedAt;

  const UtilityDetail({
    required this.utilityDetailId,
    required this.estateId,
    required this.kind,
    required this.notes,
    required this.storagePath,
    this.imageUrl = '',
    required this.updatedAt,
  });

  factory UtilityDetail.fromJson(Map<String, dynamic> json) {
    return UtilityDetail(
      utilityDetailId: json['utility_detail_id'] as String,
      estateId: json['estate_id'] as String,
      kind: UtilityKind.fromDb((json['kind'] as String?) ?? ''),
      notes: (json['notes'] as String?) ?? '',
      storagePath: (json['storage_path'] as String?) ?? '',
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'estate_id': estateId,
      'kind': kind.dbValue,
      'notes': notes,
      'storage_path': storagePath,
    };
  }

  UtilityDetail copyWith({
    String? notes,
    String? storagePath,
    String? imageUrl,
    DateTime? updatedAt,
  }) {
    return UtilityDetail(
      utilityDetailId: utilityDetailId,
      estateId: estateId,
      kind: kind,
      notes: notes ?? this.notes,
      storagePath: storagePath ?? this.storagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
