/// A per-owner funeral preference section (e.g. "Funeral (Kieren)").
///
/// Each estate can have one or more funeral arrangements. Each carries a
/// [name] (used in the section title "Funeral (name)"), free-text [notes],
/// and an optional [url].
class FuneralArrangement {
  final String funeralArrangementId;
  final String estateId;
  final String name;
  final String notes;
  final String url;
  final DateTime createdAt;

  const FuneralArrangement({
    required this.funeralArrangementId,
    required this.estateId,
    required this.name,
    required this.notes,
    required this.url,
    required this.createdAt,
  });

  factory FuneralArrangement.fromJson(Map<String, dynamic> json) {
    return FuneralArrangement(
      funeralArrangementId: json['funeral_arrangement_id'] as String,
      estateId: json['estate_id'] as String,
      name: json['name'] as String,
      notes: (json['notes'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'estate_id': estateId,
      'name': name,
      'notes': notes,
      'url': url,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'notes': notes,
      'url': url,
    };
  }

  FuneralArrangement copyWith({
    String? name,
    String? notes,
    String? url,
  }) {
    return FuneralArrangement(
      funeralArrangementId: funeralArrangementId,
      estateId: estateId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      url: url ?? this.url,
      createdAt: createdAt,
    );
  }
}
