/// OAuth related types for cloud provider authentication
library;

/// Parameters required for OAuth URL generation
class OAuthParams {
  final String clientId;
  final String redirectUri;
  final List<String> scopes;
  final String? state;
  final String? codeChallenge;
  final String? codeChallengeMethod;
  
  const OAuthParams({
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    this.state,
    this.codeChallenge,
    this.codeChallengeMethod,
  });
  
  /// Convert to query parameters map
  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': scopes.join(' '),
      'response_type': 'code',
    };
    
    if (state != null) params['state'] = state!;
    if (codeChallenge != null) params['code_challenge'] = codeChallenge!;
    if (codeChallengeMethod != null) {
      params['code_challenge_method'] = codeChallengeMethod!;
    }
    
    return params;
  }
  
  @override
  String toString() => 'OAuthParams(clientId: $clientId, scopes: $scopes)';
}

/// OAuth callback response from authorization server
class OAuthCallback {
  final String? code;
  final String? error;
  final String? errorDescription;
  final String? state;
  
  const OAuthCallback({
    this.code,
    this.error,
    this.errorDescription,
    this.state,
  });
  
  /// Whether the OAuth flow was successful
  bool get isSuccess => code != null && error == null;
  
  /// Whether there was an error in the OAuth flow
  bool get hasError => error != null;
  
  /// Get error message for display
  String get errorMessage {
    if (error == null) return '';
    if (errorDescription != null) return '$error: $errorDescription';
    return error!;
  }
  
  /// Create from query parameters
  factory OAuthCallback.fromQueryParams(Map<String, String> params) {
    return OAuthCallback(
      code: params['code'],
      error: params['error'],
      errorDescription: params['error_description'],
      state: params['state'],
    );
  }
  
  @override
  String toString() => 'OAuthCallback(success: $isSuccess, error: $error)';
}

/// Result of authentication process
class AuthResult {
  final bool success;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? error;
  final Map<String, dynamic> metadata;
  final bool hasPermissionIssues;
  final bool needsReauth;
  
  // User info to be cached locally
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? userPicture;
  final DateTime? userInfoUpdatedAt;
  
  const AuthResult({
    required this.success,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.error,
    this.metadata = const {},
    this.hasPermissionIssues = false,
    this.needsReauth = false,
    this.userId,
    this.userName,
    this.userEmail,
    this.userPicture,
    this.userInfoUpdatedAt,
  });
  
  /// Create successful auth result
  factory AuthResult.success({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    Map<String, dynamic> metadata = const {},
    bool hasPermissionIssues = false,
    bool needsReauth = false,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPicture,
  }) {
    return AuthResult(
      success: true,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      metadata: metadata,
      hasPermissionIssues: hasPermissionIssues,
      needsReauth: needsReauth,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPicture: userPicture,
      userInfoUpdatedAt: DateTime.now(),
    );
  }
  
  /// Create failed auth result
  factory AuthResult.failure(String error, {
    bool hasPermissionIssues = false,
    bool needsReauth = false,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPicture,
  }) {
    return AuthResult(
      success: false,
      error: error,
      hasPermissionIssues: hasPermissionIssues,
      needsReauth: needsReauth,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPicture: userPicture,
      userInfoUpdatedAt: userName != null ? DateTime.now() : null,
    );
  }
  
  /// Create result with permission issues
  factory AuthResult.permissionIssue({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    Map<String, dynamic> metadata = const {},
    String? error,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPicture,
  }) {
    return AuthResult(
      success: false,  // Permission issues mean auth was not fully successful
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      metadata: metadata,
      error: error,
      hasPermissionIssues: true,
      needsReauth: true,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPicture: userPicture,
      userInfoUpdatedAt: userName != null ? DateTime.now() : null,
    );
  }
  
  /// Create copy with updated user info
  AuthResult copyWithUserInfo({
    String? userId,
    String? userName,
    String? userEmail,
    String? userPicture,
  }) {
    return AuthResult(
      success: success,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      error: error,
      metadata: metadata,
      hasPermissionIssues: hasPermissionIssues,
      needsReauth: needsReauth,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPicture: userPicture ?? this.userPicture,
      userInfoUpdatedAt: DateTime.now(),
    );
  }
  
  /// Whether the token is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
  
  /// Time until token expires
  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }
  
  @override
  String toString() => 'AuthResult(success: $success, hasToken: ${accessToken != null})';
}


