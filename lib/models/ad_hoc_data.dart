/// A free-form, user-defined record for anything not already covered by a
/// dedicated section (e.g. how to operate the robot lawnmower).
///
/// Each record carries a [title], optional [email] and [url], and free-text
/// [notes].
class AdHocData {
  final String adHocDataId;
  final String estateId;
  final String title;
  final String email;
  final String url;
  final String notes;
  final DateTime createdAt;

  const AdHocData({
    required this.adHocDataId,
    required this.estateId,
    required this.title,
    required this.email,
    required this.url,
    required this.notes,
    required this.createdAt,
  });

  factory AdHocData.fromJson(Map<String, dynamic> json) {
    return AdHocData(
      adHocDataId: json['ad_hoc_data_id'] as String,
      estateId: json['estate_id'] as String,
      title: (json['title'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'estate_id': estateId,
      'title': title,
      'email': email,
      'url': url,
      'notes': notes,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'email': email,
      'url': url,
      'notes': notes,
    };
  }

  AdHocData copyWith({
    String? title,
    String? email,
    String? url,
    String? notes,
  }) {
    return AdHocData(
      adHocDataId: adHocDataId,
      estateId: estateId,
      title: title ?? this.title,
      email: email ?? this.email,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
