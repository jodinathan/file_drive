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
  
  const AuthResult({
    required this.success,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.error,
    this.metadata = const {},
  });
  
  /// Create successful auth result
  factory AuthResult.success({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    Map<String, dynamic> metadata = const {},
  }) {
    return AuthResult(
      success: true,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      metadata: metadata,
    );
  }
  
  /// Create failed auth result
  factory AuthResult.failure(String error) {
    return AuthResult(
      success: false,
      error: error,
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


