/// A per-owner funeral preference section (e.g. "Funeral (Kieren)").
///
/// Each estate can have one or more funeral arrangements. Each carries a
/// [name] (used in the section title "Funeral (name)"), free-text [notes],
/// free-text [prepaidDetails], and an optional [url].
class FuneralArrangement {
  final String funeralArrangementId;
  final String estateId;
  final String name;
  final String notes;
  final String prepaidDetails;
  final String url;
  final DateTime createdAt;

  const FuneralArrangement({
    required this.funeralArrangementId,
    required this.estateId,
    required this.name,
    required this.notes,
    this.prepaidDetails = '',
    required this.url,
    required this.createdAt,
  });

  factory FuneralArrangement.fromJson(Map<String, dynamic> json) {
    return FuneralArrangement(
      funeralArrangementId: json['funeral_arrangement_id'] as String,
      estateId: json['estate_id'] as String,
      name: json['name'] as String? ?? '',
      notes: (json['notes'] as String?) ?? '',
      prepaidDetails: (json['prepaid_details'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'estate_id': estateId,
      'name': name,
      'notes': notes,
      'prepaid_details': prepaidDetails,
      'url': url,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'notes': notes,
      'prepaid_details': prepaidDetails,
      'url': url,
    };
  }

  FuneralArrangement copyWith({
    String? name,
    String? notes,
    String? prepaidDetails,
    String? url,
  }) {
    return FuneralArrangement(
      funeralArrangementId: funeralArrangementId,
      estateId: estateId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      prepaidDetails: prepaidDetails ?? this.prepaidDetails,
      url: url ?? this.url,
      createdAt: createdAt,
    );
  }
}
