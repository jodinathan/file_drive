/// Configuration for OAuth2 authentication
class OAuthConfig {
  /// URL generator function for starting OAuth flow
  /// Should return URL like: http://server.com/auth/google?state=<state>
  final String Function(String state) generateAuthUrl;
  
  /// URL generator function for retrieving tokens
  /// Should return URL like: http://server.com/auth/tokens/<state>
  final String Function(String state) generateTokenUrl;
  
  /// Custom URL scheme for mobile/desktop (e.g., 'com.yourapp://oauth')
  /// For web, this should be an https URL
  final String redirectScheme;
  
  /// Provider type identifier (e.g., 'google_drive')
  final String providerType;

  const OAuthConfig({
    required this.generateAuthUrl,
    required this.generateTokenUrl,
    required this.redirectScheme,
    required this.providerType,
  });
}

/// Result of OAuth authentication
class OAuthResult {
  /// Whether authentication was successful
  final bool isSuccess;
  
  /// Access token (if successful)
  final String? accessToken;
  
  /// Refresh token (if available)
  final String? refreshToken;
  
  /// Token expiration time (if available)
  final DateTime? expiresAt;
  
  /// Error message (if failed)
  final String? error;
  
  /// Whether the user cancelled the authentication
  final bool wasCancelled;
  
  /// Additional data returned from the OAuth server
  final Map<String, dynamic> additionalData;

  const OAuthResult({
    required this.isSuccess,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.error,
    this.wasCancelled = false,
    this.additionalData = const {},
  });

  /// Creates a successful OAuth result
  factory OAuthResult.success({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    Map<String, dynamic> additionalData = const {},
  }) {
    return OAuthResult(
      isSuccess: true,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      additionalData: additionalData,
    );
  }

  /// Creates a failed OAuth result
  factory OAuthResult.error(String error) {
    return OAuthResult(
      isSuccess: false,
      error: error,
    );
  }

  /// Creates a cancelled OAuth result
  factory OAuthResult.cancelled() {
    return const OAuthResult(
      isSuccess: false,
      wasCancelled: true,
      error: 'Authentication was cancelled by the user',
    );
  }
}