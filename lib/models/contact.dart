/// A single person to notify — a family member, friend, GP or solicitor.
///
/// Listed above the organisation entries on the Who to Notify page. Each
/// contact carries a [name], [telephone] and [email].
class Contact {
  final String contactId;
  final String estateId;
  final String name;
  final String telephone;
  final String email;
  final DateTime createdAt;

  const Contact({
    required this.contactId,
    required this.estateId,
    required this.name,
    required this.telephone,
    required this.email,
    required this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      contactId: json['contact_id'] as String,
      estateId: json['estate_id'] as String,
      name: (json['name'] as String?) ?? '',
      telephone: (json['telephone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'estate_id': estateId,
      'name': name,
      'telephone': telephone,
      'email': email,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'telephone': telephone,
      'email': email,
    };
  }

  Contact copyWith({
    String? name,
    String? telephone,
    String? email,
  }) {
    return Contact(
      contactId: contactId,
      estateId: estateId,
      name: name ?? this.name,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      createdAt: createdAt,
    );
  }

  /// Initials used for the collapsed tile avatar, e.g. "Jane Doe" → "JD".
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
