import 'account_status.dart';

/// Represents a cloud storage account integrated with the application
class CloudAccount {
  /// Unique identifier for this account within the app
  final String id;
  
  /// Provider type (e.g., 'google_drive', 'dropbox', 'onedrive')
  final String providerType;
  
  /// External ID from the cloud provider
  final String externalId;
  
  /// Access token for API calls
  final String accessToken;
  
  /// Refresh token for renewing access (may be null)
  final String? refreshToken;
  
  /// Token expiration time (may be null if token doesn't expire)
  final DateTime? expiresAt;
  
  /// User's display name
  final String name;
  
  /// User's email address
  final String email;
  
  /// URL to user's profile photo
  final String? photoUrl;
  
  /// Current status of this account integration
  final AccountStatus status;
  
  /// When this account was first integrated
  final DateTime createdAt;
  
  /// When this account was last updated
  final DateTime updatedAt;
  
  /// Additional metadata specific to the provider
  final Map<String, dynamic> metadata;

  const CloudAccount({
    required this.id,
    required this.providerType,
    required this.externalId,
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    required this.name,
    required this.email,
    this.photoUrl,
    this.status = AccountStatus.ok,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  /// Creates a copy of this CloudAccount with some fields replaced
  CloudAccount copyWith({
    String? id,
    String? providerType,
    String? externalId,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? name,
    String? email,
    String? photoUrl,
    AccountStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return CloudAccount(
      id: id ?? this.id,
      providerType: providerType ?? this.providerType,
      externalId: externalId ?? this.externalId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Whether this account's token is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether this account is usable for API calls
  bool get isUsable => status.isUsable && !isExpired;

  /// Whether this account needs reauthorization
  bool get needsReauth => status.needsReauth || isExpired;

  /// Updates the account status and timestamp
  CloudAccount updateStatus(AccountStatus newStatus) {
    return copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
  }

  /// Updates the tokens and expiration
  CloudAccount updateTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt,
      status: AccountStatus.ok,
      updatedAt: DateTime.now(),
    );
  }

  /// Converts this CloudAccount to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerType': providerType,
      'externalId': externalId,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toIso8601String(),
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Creates a CloudAccount from a JSON map
  factory CloudAccount.fromJson(Map<String, dynamic> json) {
    return CloudAccount(
      id: json['id'] as String,
      providerType: json['providerType'] as String,
      externalId: json['externalId'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      name: json['name'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
      status: AccountStatus.fromValue(json['status'] as String? ?? 'ok'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CloudAccount && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CloudAccount(id: $id, providerType: $providerType, email: $email, status: $status)';
  }
}