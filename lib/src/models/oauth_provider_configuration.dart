import 'package:flutter/material.dart';

import '../enums/cloud_provider_type.dart';
import 'base_provider_configuration.dart';

/// Configuration for OAuth-based cloud storage providers
/// 
/// This class extends BaseProviderConfiguration to provide OAuth-specific
/// authentication parameters and validation. It supports providers like
/// Google Drive, OneDrive, Dropbox, and custom OAuth implementations.
class OAuthProviderConfiguration extends BaseProviderConfiguration {
  /// Function to generate OAuth authorization URL
  /// 
  /// This function receives the OAuth state parameter and should return
  /// a complete authorization URL (typically from a server endpoint).
  /// The state parameter is used for CSRF protection and request correlation.
  final Uri Function(String state) authUrlGenerator;

  /// Function to generate OAuth token exchange URL
  /// 
  /// This function receives the OAuth state parameter and should return
  /// a complete token exchange URL (typically from a server endpoint).
  /// This endpoint should handle the authorization code to token exchange.
  final Uri Function(String state) tokenUrlGenerator;

  /// OAuth redirect scheme used for handling auth callbacks
  /// 
  /// Should match the scheme configured in your app's URL handling
  /// (e.g., 'myapp://oauth', 'com.example.app://auth')
  final String redirectScheme;

  /// List of OAuth scopes required by this provider configuration
  /// 
  /// These scopes define what permissions the application requests
  /// from the OAuth provider (e.g., read files, write files, etc.)
  final List<String> scopes;

  /// Whether this provider requires account management features
  /// 
  /// If true, the provider will support multiple accounts, account switching,
  /// and account lifecycle management. Most OAuth providers require this.
  final bool requiresAccountManagement;

  /// Additional provider-specific configuration parameters
  /// 
  /// This map can contain provider-specific settings like API versions,
  /// custom endpoints, feature flags, etc.
  final Map<String, dynamic> additionalConfig;

  /// Creates an OAuth provider configuration with validation
  /// 
  /// All parameters are validated during construction. OAuth-specific
  /// validation includes URL generation testing and scope validation.
  const OAuthProviderConfiguration({
    required super.type,
    required super.displayName,
    super.logoWidget,
    required super.capabilities,
    super.enabled = true,
    super.configurationId,
    required this.authUrlGenerator,
    required this.tokenUrlGenerator,
    required this.redirectScheme,
    required this.scopes,
    this.requiresAccountManagement = true,
    this.additionalConfig = const {},
  });

  @override
  void validate() {
    // Call base validation first
    super.validate();

    // OAuth-specific validation
    if (redirectScheme.isEmpty) {
      throw ArgumentError('OAuth redirect scheme cannot be empty');
    }

    if (!redirectScheme.contains('://')) {
      throw ArgumentError('Invalid redirect scheme format: $redirectScheme');
    }

    if (scopes.isEmpty) {
      throw ArgumentError('At least one OAuth scope must be specified');
    }

    // Test URL generation functions with a sample state
    try {
      const sampleState = 'validation_test_state';
      final authUrl = authUrlGenerator(sampleState);
      final tokenUrl = tokenUrlGenerator(sampleState);

      if (!authUrl.hasScheme || authUrl.host.isEmpty) {
        throw ArgumentError('authUrlGenerator must return a valid absolute URL');
      }

      if (!tokenUrl.hasScheme || tokenUrl.host.isEmpty) {
        throw ArgumentError('tokenUrlGenerator must return a valid absolute URL');
      }
    } catch (e) {
      throw ArgumentError('OAuth URL generation validation failed: $e');
    }
  }

  @override
  OAuthProviderConfiguration copyWith({
    CloudProviderType? type,
    String? displayName,
    Widget? logoWidget,
    Set<ProviderCapability>? capabilities,
    bool? enabled,
    String? configurationId,
    Uri Function(String state)? authUrlGenerator,
    Uri Function(String state)? tokenUrlGenerator,
    String? redirectScheme,
    List<String>? scopes,
    bool? requiresAccountManagement,
    Map<String, dynamic>? additionalConfig,
  }) {
    return OAuthProviderConfiguration(
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      logoWidget: logoWidget ?? this.logoWidget,
      capabilities: capabilities ?? this.capabilities,
      enabled: enabled ?? this.enabled,
      configurationId: configurationId ?? this.configurationId,
      authUrlGenerator: authUrlGenerator ?? this.authUrlGenerator,
      tokenUrlGenerator: tokenUrlGenerator ?? this.tokenUrlGenerator,
      redirectScheme: redirectScheme ?? this.redirectScheme,
      scopes: scopes ?? this.scopes,
      requiresAccountManagement:
          requiresAccountManagement ?? this.requiresAccountManagement,
      additionalConfig: additionalConfig ?? this.additionalConfig,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson.addAll({
      'redirectScheme': redirectScheme,
      'scopes': scopes,
      'requiresAccountManagement': requiresAccountManagement,
      'additionalConfig': additionalConfig,
    });
    return baseJson;
  }

  /// Creates an OAuth configuration from a JSON map
  /// 
  /// Note: This factory cannot restore function properties (authUrlGenerator, tokenUrlGenerator)
  /// You must provide these functions separately when deserializing.
  factory OAuthProviderConfiguration.fromJson(
    Map<String, dynamic> json, {
    required Uri Function(String state) authUrlGenerator,
    required Uri Function(String state) tokenUrlGenerator,
    Widget? logoWidget,
  }) {
    final typeString = json['type'] as String;
    final type = CloudProviderType.values.firstWhere(
      (t) => t.name == typeString,
      orElse: () => throw ArgumentError('Invalid provider type: $typeString'),
    );

    final capabilityStrings = List<String>.from(json['capabilities'] as List);
    final capabilities = capabilityStrings.map((capString) {
      return ProviderCapability.values.firstWhere(
        (cap) => cap.name == capString,
        orElse: () => throw ArgumentError('Invalid capability: $capString'),
      );
    }).toSet();

    final scopes = List<String>.from(json['scopes'] as List);

    return OAuthProviderConfiguration(
      type: type,
      displayName: json['displayName'] as String,
      logoWidget: logoWidget,
      capabilities: capabilities,
      enabled: json['enabled'] as bool? ?? true,
      configurationId: json['configurationId'] as String?,
      authUrlGenerator: authUrlGenerator,
      tokenUrlGenerator: tokenUrlGenerator,
      redirectScheme: json['redirectScheme'] as String,
      scopes: scopes,
      requiresAccountManagement:
          json['requiresAccountManagement'] as bool? ?? true,
      additionalConfig: Map<String, dynamic>.from(
        json['additionalConfig'] as Map? ?? {},
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is OAuthProviderConfiguration &&
        super == other &&
        other.redirectScheme == redirectScheme &&
        other.scopes.length == scopes.length &&
        other.scopes.every(scopes.contains) &&
        other.requiresAccountManagement == requiresAccountManagement;
    // Note: Function properties (authUrlGenerator, tokenUrlGenerator) are excluded
    // from equality comparison as they cannot be reliably compared
  }

  @override
  int get hashCode {
    return Object.hash(
      super.hashCode,
      redirectScheme,
      Object.hashAll(scopes),
      requiresAccountManagement,
      // Note: Function properties are excluded from hash calculation
    );
  }
}