import '../enums/cloud_provider_type.dart';
import '../enums/oauth_scope.dart';
import '../enums/provider_scope_mapper.dart';

/// Configuration for OAuth2 authentication with generic provider support
class OAuthConfig {
  /// Cloud provider type for this OAuth configuration
  final CloudProviderType providerType;
  
  /// Set of OAuth scopes required for this configuration
  final Set<OAuthScope> requiredScopes;
  
  /// URL generator function for starting OAuth flow
  /// Should return URL like: http://server.com/auth/google?state=<state>
  final String Function(String state) generateAuthUrl;
  
  /// URL generator function for retrieving tokens
  /// Should return URL like: http://server.com/auth/tokens/<state>
  final String Function(String state) generateTokenUrl;
  
  /// Custom URL scheme for mobile/desktop (e.g., 'com.yourapp://oauth')
  /// For web, this should be an https URL
  final String redirectScheme;
  
  /// Configuration identifier for multi-tenant scenarios
  final String? configurationId;

  const OAuthConfig({
    required this.providerType,
    required this.requiredScopes,
    required this.generateAuthUrl,
    required this.generateTokenUrl,
    required this.redirectScheme,
    this.configurationId,
  });

  /// Creates an OAuthConfig from provider configuration
  factory OAuthConfig.fromProviderConfig({
    required CloudProviderType providerType,
    required Set<OAuthScope> requiredScopes,
    required String baseUrl,
    required String redirectScheme,
    String? configurationId,
  }) {
    // Validate that provider supports all required scopes
    ProviderScopeMapper.validateScopes(requiredScopes, providerType);
    
    return OAuthConfig(
      providerType: providerType,
      requiredScopes: requiredScopes,
      redirectScheme: redirectScheme,
      configurationId: configurationId,
      generateAuthUrl: (state) => '$baseUrl/auth/${providerType.name}?state=$state',
      generateTokenUrl: (state) => '$baseUrl/auth/tokens/$state',
    );
  }

  /// Gets the provider-specific scope strings for this configuration
  List<String> get providerScopes {
    return ProviderScopeMapper.mapScopesToProvider(requiredScopes, providerType);
  }


  /// Creates a copy of this configuration with updated values
  OAuthConfig copyWith({
    CloudProviderType? providerType,
    Set<OAuthScope>? requiredScopes,
    String Function(String state)? generateAuthUrl,
    String Function(String state)? generateTokenUrl,
    String? redirectScheme,
    String? configurationId,
  }) {
    return OAuthConfig(
      providerType: providerType ?? this.providerType,
      requiredScopes: requiredScopes ?? this.requiredScopes,
      generateAuthUrl: generateAuthUrl ?? this.generateAuthUrl,
      generateTokenUrl: generateTokenUrl ?? this.generateTokenUrl,
      redirectScheme: redirectScheme ?? this.redirectScheme,
      configurationId: configurationId ?? this.configurationId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is OAuthConfig &&
        other.providerType == providerType &&
        other.requiredScopes.length == requiredScopes.length &&
        other.requiredScopes.every(requiredScopes.contains) &&
        other.redirectScheme == redirectScheme &&
        other.configurationId == configurationId;
  }

  @override
  int get hashCode {
    return Object.hash(
      providerType,
      requiredScopes,
      redirectScheme,
      configurationId,
    );
  }

  @override
  String toString() {
    return 'OAuthConfig('
        'providerType: $providerType, '
        'requiredScopes: ${requiredScopes.map((s) => s.name).join(', ')}, '
        'redirectScheme: $redirectScheme'
        ')';
  }
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