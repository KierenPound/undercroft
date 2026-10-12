import 'package:flutter/material.dart';

class WhoToNotify {
  final String whoToNotifyId;
  final String estateId;
  final String companyName;
  final String? contactNumber;
  final String? weblink;
  final String? supplementaryNotes;
  final DateTime createdAt;

  const WhoToNotify({
    required this.whoToNotifyId,
    required this.estateId,
    required this.companyName,
    this.contactNumber,
    this.weblink,
    this.supplementaryNotes,
    required this.createdAt,
  });

  factory WhoToNotify.fromJson(Map<String, dynamic> json) {
    return WhoToNotify(
      whoToNotifyId: json['who_to_notify_id'] as String,
      estateId: json['estate_id'] as String,
      companyName: json['company_name'] as String,
      contactNumber: json['contact_number'] as String?,
      weblink: json['weblink'] as String?,
      supplementaryNotes: json['supplementary_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'estate_id': estateId,
      'company_name': companyName,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (weblink != null) 'weblink': weblink,
      if (supplementaryNotes != null) 'supplementary_notes': supplementaryNotes,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'company_name': companyName,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (weblink != null) 'weblink': weblink,
      if (supplementaryNotes != null) 'supplementary_notes': supplementaryNotes,
    };
  }

  WhoToNotify copyWith({
    String? companyName,
    String? contactNumber,
    String? weblink,
    String? supplementaryNotes,
  }) {
    return WhoToNotify(
      whoToNotifyId: whoToNotifyId,
      estateId: estateId,
      companyName: companyName ?? this.companyName,
      contactNumber: contactNumber ?? this.contactNumber,
      weblink: weblink ?? this.weblink,
      supplementaryNotes: supplementaryNotes ?? this.supplementaryNotes,
      createdAt: createdAt,
    );
  }

  IconData get icon {
    final lower = companyName.toLowerCase();
    if (lower.contains('bank') ||
        lower.contains('tsb') ||
        lower.contains('starling')) {
      return Icons.account_balance;
    }
    if (lower.contains('energy') || lower.contains('octopus')) {
      return Icons.bolt;
    }
    if (lower.contains('pension') ||
        lower.contains('sipp') ||
        lower.contains('lifesight')) {
      return Icons.pie_chart;
    }
    if (lower.contains('premium') ||
        lower.contains('ns&i') ||
        lower.contains('savings')) {
      return Icons.savings;
    }
    if (lower.contains('sky') ||
        lower.contains('broadband') ||
        lower.contains('tv')) {
      return Icons.tv;
    }
    if (lower.contains('ledger') || lower.contains('life')) {
      return Icons.auto_awesome;
    }
    return Icons.business;
  }
}
