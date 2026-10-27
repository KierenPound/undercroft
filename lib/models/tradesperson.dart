/// A trade the estate relies on — a gas engineer, electrician, drain
/// specialist and so on.
///
/// Listed on the Running the Houses page. Each entry carries a [name],
/// [email], [telephone], [url] and free-text [notes].
class Tradesperson {
  final String tradespersonId;
  final String estateId;
  final String name;
  final String email;
  final String telephone;
  final String url;
  final String notes;
  final DateTime createdAt;

  const Tradesperson({
    required this.tradespersonId,
    required this.estateId,
    required this.name,
    required this.email,
    required this.telephone,
    required this.url,
    required this.notes,
    required this.createdAt,
  });

  factory Tradesperson.fromJson(Map<String, dynamic> json) {
    return Tradesperson(
      tradespersonId: json['tradesperson_id'] as String,
      estateId: json['estate_id'] as String,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      telephone: (json['telephone'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'estate_id': estateId,
      'name': name,
      'email': email,
      'telephone': telephone,
      'url': url,
      'notes': notes,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'email': email,
      'telephone': telephone,
      'url': url,
      'notes': notes,
    };
  }

  Tradesperson copyWith({
    String? name,
    String? email,
    String? telephone,
    String? url,
    String? notes,
  }) {
    return Tradesperson(
      tradespersonId: tradespersonId,
      estateId: estateId,
      name: name ?? this.name,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  /// Initials used for the collapsed tile avatar, e.g. "Neil Fraser" → "NF".
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
