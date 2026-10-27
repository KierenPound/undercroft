const _unsetNotifyAccountDetailsField = Object();

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
      'sort_code': sortCode,
      'account_code': accountCode,
      'other_code': otherCode,
      'other_description': otherDescription,
    };
  }

  NotifyAccountDetails copyWith({
    Object? sortCode = _unsetNotifyAccountDetailsField,
    Object? accountCode = _unsetNotifyAccountDetailsField,
    Object? otherCode = _unsetNotifyAccountDetailsField,
    Object? otherDescription = _unsetNotifyAccountDetailsField,
  }) {
    return NotifyAccountDetails(
      notifyAccountDetailsId: notifyAccountDetailsId,
      whoToNotifyId: whoToNotifyId,
      sortCode: identical(sortCode, _unsetNotifyAccountDetailsField)
          ? this.sortCode
          : sortCode as String?,
      accountCode: identical(accountCode, _unsetNotifyAccountDetailsField)
          ? this.accountCode
          : accountCode as String?,
      otherCode: identical(otherCode, _unsetNotifyAccountDetailsField)
          ? this.otherCode
          : otherCode as String?,
      otherDescription:
          identical(otherDescription, _unsetNotifyAccountDetailsField)
              ? this.otherDescription
              : otherDescription as String?,
      createdAt: createdAt,
    );
  }

  bool get isEmpty =>
      (sortCode == null || sortCode!.isEmpty) &&
      (accountCode == null || accountCode!.isEmpty) &&
      (otherCode == null || otherCode!.isEmpty);
}
