/// Enum representing the status of a cloud account integration
enum AccountStatus {
  /// Account is working correctly
  ok('ok'),
  
  /// Account lacks required permissions/scopes
  missingScopes('missing_scopes'),
  
  /// Account has been revoked by the user
  revoked('revoked'),
  
  /// Account has an error that needs attention
  error('error');

  const AccountStatus(this.value);
  
  /// String value for serialization
  final String value;
  
  /// Creates AccountStatus from string value
  static AccountStatus fromValue(String value) {
    return AccountStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AccountStatus.error,
    );
  }
  
  /// Whether this status indicates the account is usable
  bool get isUsable => this == AccountStatus.ok;
  
  /// Whether this status indicates the account needs reauthorization
  bool get needsReauth => this == AccountStatus.missingScopes || this == AccountStatus.revoked;
  
  /// Whether this status indicates an error state
  bool get hasError => this == AccountStatus.error || this == AccountStatus.revoked;
}