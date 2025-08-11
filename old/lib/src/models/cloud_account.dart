library;

import 'package:flutter/material.dart';

enum AccountStatus {
  active,
  inactive,
  needsReauth,
  loading,
  error,
}

class CloudAccount {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final AccountStatus status;
  final bool isActive;
  final DateTime? lastUpdated;

  CloudAccount({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.status = AccountStatus.active,
    this.isActive = false,
    this.lastUpdated,
  });

  factory CloudAccount.fromJson(Map<String, dynamic> json) {
    return CloudAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
      status: AccountStatus.values.firstWhere(
        (e) => e.toString() == 'AccountStatus.${json['status']}',
        orElse: () => AccountStatus.inactive,
      ),
      isActive: json['isActive'] as bool? ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'status': status.toString().split('.').last,
      'isActive': isActive,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }
}
