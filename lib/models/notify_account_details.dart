class NotifyAccountDetails {
  final String notifyAccountDetailsId;
  final String whoToNotifyId;
  final String? sortCode;
  final String? accountCode;
  final String? otherCode;
  final String? otherDescription;
  final DateTime createdAt;

  const NotifyAccountDetails({
    required this.notifyAccountDetailsId,
    required this.whoToNotifyId,
    this.sortCode,
    this.accountCode,
    this.otherCode,
    this.otherDescription,
    required this.createdAt,
  });

  factory NotifyAccountDetails.fromJson(Map<String, dynamic> json) {
    return NotifyAccountDetails(
      notifyAccountDetailsId: json['notify_account_details_id'] as String,
      whoToNotifyId: json['who_to_notify_id'] as String,
      sortCode: json['sort_code'] as String?,
      accountCode: json['account_code'] as String?,
      otherCode: json['other_code'] as String?,
      otherDescription: json['other_description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'who_to_notify_id': whoToNotifyId,
      if (sortCode != null) 'sort_code': sortCode,
      if (accountCode != null) 'account_code': accountCode,
      if (otherCode != null) 'other_code': otherCode,
      if (otherDescription != null) 'other_description': otherDescription,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      if (sortCode != null) 'sort_code': sortCode,
      if (accountCode != null) 'account_code': accountCode,
      if (otherCode != null) 'other_code': otherCode,
      if (otherDescription != null) 'other_description': otherDescription,
    };
  }

  NotifyAccountDetails copyWith({
    String? sortCode,
    String? accountCode,
    String? otherCode,
    String? otherDescription,
  }) {
    return NotifyAccountDetails(
      notifyAccountDetailsId: notifyAccountDetailsId,
      whoToNotifyId: whoToNotifyId,
      sortCode: sortCode ?? this.sortCode,
      accountCode: accountCode ?? this.accountCode,
      otherCode: otherCode ?? this.otherCode,
      otherDescription: otherDescription ?? this.otherDescription,
      createdAt: createdAt,
    );
  }

  bool get isEmpty =>
      (sortCode == null || sortCode!.isEmpty) &&
      (accountCode == null || accountCode!.isEmpty) &&
      (otherCode == null || otherCode!.isEmpty);
}
