import '../enums/cloud_provider_type.dart';
import '../enums/oauth_scope.dart';

/// Configuration model for cloud providers following oni* architecture patterns
///
/// This model encapsulates all necessary configuration for a cloud storage provider,
/// including OAuth credentials, scopes, and custom endpoints.
class OniCloudProviderConfig {
  /// The cloud provider type this configuration is for
  final CloudProviderType providerType;
  
  /// OAuth client ID for this provider
  final String clientId;
  
  /// OAuth client secret for this provider
  final String? clientSecret;
  
  /// Set of OAuth scopes required by this configuration
  final Set<OAuthScope> scopes;
  
  /// Custom OAuth endpoints (optional)
  final OAuthEndpoints? customEndpoints;
  
  /// Additional provider-specific configuration
  final Map<String, dynamic> additionalConfig;
  
  /// Whether this configuration is enabled
  final bool enabled;
  
  /// Configuration identifier for multi-tenant scenarios
  final String? configurationId;

  const OniCloudProviderConfig({
    required this.providerType,
    required this.clientId,
    this.clientSecret,
    required this.scopes,
    this.customEndpoints,
    this.additionalConfig = const {},
    this.enabled = true,
    this.configurationId,
  });

  /// Creates a copy of this configuration with updated values
  OniCloudProviderConfig copyWith({
    CloudProviderType? providerType,
    String? clientId,
    String? clientSecret,
    Set<OAuthScope>? scopes,
    OAuthEndpoints? customEndpoints,
    Map<String, dynamic>? additionalConfig,
    bool? enabled,
    String? configurationId,
  }) {
    return OniCloudProviderConfig(
      providerType: providerType ?? this.providerType,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      scopes: scopes ?? this.scopes,
      customEndpoints: customEndpoints ?? this.customEndpoints,
      additionalConfig: additionalConfig ?? this.additionalConfig,
      enabled: enabled ?? this.enabled,
      configurationId: configurationId ?? this.configurationId,
    );
  }

  /// Validates this configuration
  ///
  /// Throws [ArgumentError] if the configuration is invalid.
  void validate() {
    if (clientId.isEmpty) {
      throw ArgumentError('Client ID cannot be empty');
    }
    
    if (scopes.isEmpty) {
      throw ArgumentError('At least one OAuth scope must be specified');
    }
    
    // Provider-specific validation
    switch (providerType) {
      case CloudProviderType.googleDrive:
      case CloudProviderType.oneDrive:
      case CloudProviderType.dropbox:
        if (clientSecret == null || clientSecret!.isEmpty) {
          throw ArgumentError('Client secret is required for ${providerType.displayName}');
        }
        break;
      case CloudProviderType.custom:
        if (customEndpoints == null) {
          throw ArgumentError('Custom endpoints are required for custom providers');
        }
        break;
      case CloudProviderType.localServer:
        // Local server doesn't require OAuth validation
        break;
    }
  }

  /// Converts this configuration to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'providerType': providerType.name,
      'clientId': clientId,
      'clientSecret': clientSecret,
      'scopes': scopes.map((s) => s.name).toList(),
      'customEndpoints': customEndpoints?.toJson(),
      'additionalConfig': additionalConfig,
      'enabled': enabled,
      'configurationId': configurationId,
    };
  }

  /// Creates a configuration from a JSON map
  factory OniCloudProviderConfig.fromJson(Map<String, dynamic> json) {
    final providerTypeString = json['providerType'] as String;
    final providerType = CloudProviderType.values.firstWhere(
      (type) => type.name == providerTypeString,
      orElse: () => throw ArgumentError('Invalid provider type: $providerTypeString'),
    );
    
    final scopeStrings = List<String>.from(json['scopes'] as List);
    final scopes = scopeStrings.map((scopeString) {
      return OAuthScope.values.firstWhere(
        (scope) => scope.name == scopeString,
        orElse: () => throw ArgumentError('Invalid scope: $scopeString'),
      );
    }).toSet();

    return OniCloudProviderConfig(
      providerType: providerType,
      clientId: json['clientId'] as String,
      clientSecret: json['clientSecret'] as String?,
      scopes: scopes,
      customEndpoints: json['customEndpoints'] != null
          ? OAuthEndpoints.fromJson(json['customEndpoints'] as Map<String, dynamic>)
          : null,
      additionalConfig: Map<String, dynamic>.from(json['additionalConfig'] as Map? ?? {}),
      enabled: json['enabled'] as bool? ?? true,
      configurationId: json['configurationId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is OniCloudProviderConfig &&
        other.providerType == providerType &&
        other.clientId == clientId &&
        other.clientSecret == clientSecret &&
        other.scopes.length == scopes.length &&
        other.scopes.every(scopes.contains) &&
        other.customEndpoints == customEndpoints &&
        other.enabled == enabled &&
        other.configurationId == configurationId;
  }

  @override
  int get hashCode {
    return Object.hash(
      providerType,
      clientId,
      clientSecret,
      scopes,
      customEndpoints,
      enabled,
      configurationId,
    );
  }

  @override
  String toString() {
    return 'OniCloudProviderConfig('
        'providerType: $providerType, '
        'clientId: $clientId, '
        'scopes: ${scopes.map((s) => s.name).join(', ')}, '
        'enabled: $enabled'
        ')';
  }
}

/// Custom OAuth endpoints for providers that don't use standard endpoints
class OAuthEndpoints {
  /// Authorization endpoint URL
  final String authorizationUrl;
  
  /// Token endpoint URL
  final String tokenUrl;
  
  /// User info endpoint URL (optional)
  final String? userInfoUrl;
  
  /// Revoke token endpoint URL (optional)
  final String? revokeUrl;

  const OAuthEndpoints({
    required this.authorizationUrl,
    required this.tokenUrl,
    this.userInfoUrl,
    this.revokeUrl,
  });

  /// Converts endpoints to JSON
  Map<String, dynamic> toJson() {
    return {
      'authorizationUrl': authorizationUrl,
      'tokenUrl': tokenUrl,
      'userInfoUrl': userInfoUrl,
      'revokeUrl': revokeUrl,
    };
  }

  /// Creates endpoints from JSON
  factory OAuthEndpoints.fromJson(Map<String, dynamic> json) {
    return OAuthEndpoints(
      authorizationUrl: json['authorizationUrl'] as String,
      tokenUrl: json['tokenUrl'] as String,
      userInfoUrl: json['userInfoUrl'] as String?,
      revokeUrl: json['revokeUrl'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is OAuthEndpoints &&
        other.authorizationUrl == authorizationUrl &&
        other.tokenUrl == tokenUrl &&
        other.userInfoUrl == userInfoUrl &&
        other.revokeUrl == revokeUrl;
  }

  @override
  int get hashCode {
    return Object.hash(authorizationUrl, tokenUrl, userInfoUrl, revokeUrl);
  }

  @override
  String toString() {
    return 'OAuthEndpoints(authorizationUrl: $authorizationUrl, tokenUrl: $tokenUrl)';
  }
}