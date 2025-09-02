import 'package:flutter/material.dart';

import '../enums/cloud_provider_type.dart';
import '../enums/oauth_scope.dart';
import '../models/provider_capabilities.dart';
import '../models/base_provider_configuration.dart';
import '../providers/base_cloud_provider.dart';

/// Unified configuration for cloud storage providers
///
/// This class replaces the fragmented configuration approach with a single,
/// flexible configuration structure that supports multiple providers without
/// client secrets in the app code.
class ProviderConfiguration extends BaseProviderConfiguration {
  
  /// Converts ProviderCapabilities to Set<ProviderCapability>
  static Set<ProviderCapability> _convertCapabilities(ProviderCapabilities capabilities) {
    final result = <ProviderCapability>{};
    
    if (capabilities.canUpload) result.add(ProviderCapability.upload);
    if (capabilities.canCreateFolders) result.add(ProviderCapability.createFolders);
    if (capabilities.canDelete) result.add(ProviderCapability.delete);
    if (capabilities.canPermanentDelete) result.add(ProviderCapability.permanentDelete);
    if (capabilities.canSearch) result.add(ProviderCapability.search);
    if (capabilities.canChunkedUpload) result.add(ProviderCapability.chunkedUpload);
    if (capabilities.hasThumbnails) result.add(ProviderCapability.thumbnails);
    if (capabilities.canShare) result.add(ProviderCapability.share);
    if (capabilities.canMove) result.add(ProviderCapability.move);
    if (capabilities.canCopy) result.add(ProviderCapability.copy);
    if (capabilities.canRename) result.add(ProviderCapability.rename);
    
    return result;
  }

  /// Path to the provider's logo asset (alternative to logoWidget)
  final String? logoAssetPath;

  /// Function to generate OAuth authorization URL
  /// This function receives the OAuth state parameter and should return
  /// a complete authorization URL (typically from a server endpoint)
  final String Function(String state) generateAuthUrl;

  /// Function to generate OAuth token exchange URL
  /// This function receives the OAuth state parameter and should return
  /// a complete token URL (typically from a server endpoint)
  final String Function(String state) generateTokenUrl;

  /// OAuth redirect scheme used for handling auth callbacks
  /// Should match the scheme configured in your app's URL handling
  final String redirectScheme;

  /// Set of OAuth scopes required by this provider configuration
  final Set<OAuthScope> requiredScopes;

  /// Original capabilities supported by this provider
  final ProviderCapabilities providerCapabilities;

  /// Whether this provider requires account management
  /// If true, the provider will support multiple accounts and account switching
  final bool requiresAccountManagement;

  /// Optional factory function to create custom provider instances
  /// If not provided, the default provider for the type will be used
  final BaseCloudProvider Function()? createProvider;

  /// Additional provider-specific configuration
  final Map<String, dynamic> additionalConfig;

  ProviderConfiguration({
    required CloudProviderType type,
    required String displayName,
    Widget? logoWidget,
    this.logoAssetPath,
    required this.generateAuthUrl,
    required this.generateTokenUrl,
    required this.redirectScheme,
    required this.requiredScopes,
    required this.providerCapabilities,
    this.requiresAccountManagement = true,
    this.createProvider,
    this.additionalConfig = const {},
    bool enabled = true,
    String? configurationId,
  }) : assert(
         logoWidget != null ||
             logoAssetPath != null ||
             type == CloudProviderType.custom,
         'Either logoWidget or logoAssetPath must be provided (or use custom type)',
       ),
       assert(redirectScheme.isNotEmpty, 'redirectScheme cannot be empty'),
       assert(
         requiredScopes.isNotEmpty || type == CloudProviderType.localServer,
         'At least one OAuth scope must be specified (except for local server)',
       ),
       super(
         type: type,
         displayName: displayName,
         logoWidget: logoWidget,
         capabilities: _convertCapabilities(providerCapabilities),
         enabled: enabled,
         configurationId: configurationId,
       );

  /// Creates a copy of this configuration with updated values
  @override
  BaseProviderConfiguration copyWith({
    CloudProviderType? type,
    String? displayName,
    Widget? logoWidget,
    Set<ProviderCapability>? capabilities,
    bool? enabled,
    String? configurationId,
  }) {
    // For ProviderConfiguration, we need to convert the capabilities back
    ProviderCapabilities? newProviderCapabilities;
    if (capabilities != null) {
      // Convert Set<ProviderCapability> back to ProviderCapabilities
      newProviderCapabilities = ProviderCapabilities(
        canUpload: capabilities.contains(ProviderCapability.upload),
        canCreateFolders: capabilities.contains(ProviderCapability.createFolders),
        canDelete: capabilities.contains(ProviderCapability.delete),
        canPermanentDelete: capabilities.contains(ProviderCapability.permanentDelete),
        canSearch: capabilities.contains(ProviderCapability.search),
        canChunkedUpload: capabilities.contains(ProviderCapability.chunkedUpload),
        hasThumbnails: capabilities.contains(ProviderCapability.thumbnails),
        canShare: capabilities.contains(ProviderCapability.share),
        canMove: capabilities.contains(ProviderCapability.move),
        canCopy: capabilities.contains(ProviderCapability.copy),
        canRename: capabilities.contains(ProviderCapability.rename),
      );
    }
    
    return ProviderConfiguration(
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      logoWidget: logoWidget ?? this.logoWidget,
      logoAssetPath: logoAssetPath,
      generateAuthUrl: generateAuthUrl,
      generateTokenUrl: generateTokenUrl,
      redirectScheme: redirectScheme,
      requiredScopes: requiredScopes,
      providerCapabilities: newProviderCapabilities ?? providerCapabilities,
      requiresAccountManagement: requiresAccountManagement,
      createProvider: createProvider,
      additionalConfig: additionalConfig,
      enabled: enabled ?? this.enabled,
      configurationId: configurationId ?? this.configurationId,
    );
  }

  /// Validates this configuration
  ///
  /// Throws [ArgumentError] if the configuration is invalid.
  @override
  void validate() {
    if (displayName.isEmpty) {
      throw ArgumentError('Display name cannot be empty');
    }

    if (requiredScopes.isEmpty && type != CloudProviderType.localServer) {
      throw ArgumentError('At least one OAuth scope must be specified (except for local server)');
    }

    if (redirectScheme.isEmpty) {
      throw ArgumentError('Redirect scheme cannot be empty');
    }

    if (!redirectScheme.contains('://')) {
      throw ArgumentError('Invalid redirect scheme format: $redirectScheme');
    }

    // Validate logo requirements
    if (logoWidget == null &&
        logoAssetPath == null &&
        type != CloudProviderType.custom) {
      throw ArgumentError(
        'Either logoWidget or logoAssetPath must be provided (or use custom type)',
      );
    }

    // Test URL generation functions with a sample state
    try {
      final sampleState = 'test_state_123';
      final authUrl = generateAuthUrl(sampleState);
      final tokenUrl = generateTokenUrl(sampleState);

      if (Uri.tryParse(authUrl) == null) {
        throw ArgumentError('generateAuthUrl must return a valid URL');
      }

      if (Uri.tryParse(tokenUrl) == null) {
        throw ArgumentError('generateTokenUrl must return a valid URL');
      }
    } catch (e) {
      throw ArgumentError('URL generation functions failed validation: $e');
    }
  }

  /// Converts this configuration to a JSON map
  /// Note: Widget and function properties are not serialized
  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'displayName': displayName,
      'logoAssetPath': logoAssetPath,
      'redirectScheme': redirectScheme,
      'requiredScopes': requiredScopes.map((s) => s.name).toList(),
      'capabilities': providerCapabilities.toJson(),
      'requiresAccountManagement': requiresAccountManagement,
      'additionalConfig': additionalConfig,
      'enabled': enabled,
      'configurationId': configurationId,
    };
  }

  /// Creates a configuration from a JSON map
  /// Note: This factory cannot restore Widget or function properties
  /// You must provide generateAuthUrl and generateTokenUrl separately
  factory ProviderConfiguration.fromJson(
    Map<String, dynamic> json, {
    required String Function(String state) generateAuthUrl,
    required String Function(String state) generateTokenUrl,
    Widget? logoWidget,
  }) {
    final typeString = json['type'] as String;
    final type = CloudProviderType.values.firstWhere(
      (t) => t.name == typeString,
      orElse: () => throw ArgumentError('Invalid provider type: $typeString'),
    );

    final scopeStrings = List<String>.from(json['requiredScopes'] as List);
    final scopes = scopeStrings.map((scopeString) {
      return OAuthScope.values.firstWhere(
        (scope) => scope.name == scopeString,
        orElse: () => throw ArgumentError('Invalid scope: $scopeString'),
      );
    }).toSet();

    return ProviderConfiguration(
      type: type,
      displayName: json['displayName'] as String,
      logoWidget: logoWidget,
      logoAssetPath: json['logoAssetPath'] as String?,
      generateAuthUrl: generateAuthUrl,
      generateTokenUrl: generateTokenUrl,
      redirectScheme: json['redirectScheme'] as String,
      requiredScopes: scopes,
      providerCapabilities: ProviderCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>,
      ),
      requiresAccountManagement:
          json['requiresAccountManagement'] as bool? ?? true,
      additionalConfig: Map<String, dynamic>.from(
        json['additionalConfig'] as Map? ?? {},
      ),
      enabled: json['enabled'] as bool? ?? true,
      configurationId: json['configurationId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProviderConfiguration &&
        other.type == type &&
        other.displayName == displayName &&
        other.logoAssetPath == logoAssetPath &&
        other.redirectScheme == redirectScheme &&
        other.requiredScopes.length == requiredScopes.length &&
        other.requiredScopes.every(requiredScopes.contains) &&
        other.capabilities == capabilities &&
        other.requiresAccountManagement == requiresAccountManagement &&
        other.enabled == enabled &&
        other.configurationId == configurationId;
    // Note: Functions (generateAuthUrl, generateTokenUrl, createProvider) and
    // Widgets (logoWidget) are not included in equality comparison
    // as they cannot be reliably compared for equality
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      displayName,
      logoAssetPath,
      redirectScheme,
      Object.hashAll(requiredScopes),
      capabilities,
      requiresAccountManagement,
      enabled,
      configurationId,
      // Note: Functions and Widgets are excluded from hash calculation
      // to maintain consistency with equality comparison
    );
  }

  @override
  String toString() {
    return 'ProviderConfiguration('
        'type: $type, '
        'displayName: $displayName, '
        'scopes: ${requiredScopes.map((s) => s.name).join(', ')}, '
        'enabled: $enabled'
        ')';
  }
}

/// Convenience factory methods for common provider configurations
extension ProviderConfigurationFactories on ProviderConfiguration {
  /// Creates a Google Drive provider configuration
  static ProviderConfiguration googleDrive({
    required String Function(String state) generateAuthUrl,
    required String Function(String state) generateTokenUrl,
    required String redirectScheme,
    Set<OAuthScope> requiredScopes = OAuthScope.required,
    String displayName = 'Google Drive',
    String? logoAssetPath = 'assets/logos/googleDrive.svg',
    Map<String, dynamic> additionalConfig = const {},
    bool enabled = true,
    String? configurationId,
  }) {
    return ProviderConfiguration(
      type: CloudProviderType.googleDrive,
      displayName: displayName,
      logoAssetPath: logoAssetPath,
      generateAuthUrl: generateAuthUrl,
      generateTokenUrl: generateTokenUrl,
      redirectScheme: redirectScheme,
      requiredScopes: requiredScopes,
      providerCapabilities: const ProviderCapabilities(
        canUpload: true,
        canCreateFolders: true,
        canDelete: true,
        canSearch: true,
        hasThumbnails: true,
        canShare: true,
        canMove: true,
        canCopy: true,
        canRename: true,
        maxPageSize: 100,
      ),
      requiresAccountManagement: true,
      additionalConfig: additionalConfig,
      enabled: enabled,
      configurationId: configurationId,
    );
  }

  /// Creates a custom provider configuration
  static ProviderConfiguration custom({
    required String displayName,
    required String Function(String state) generateAuthUrl,
    required String Function(String state) generateTokenUrl,
    required String redirectScheme,
    required Set<OAuthScope> requiredScopes,
    required ProviderCapabilities capabilities,
    Widget? logoWidget,
    String? logoAssetPath,
    BaseCloudProvider Function()? createProvider,
    bool requiresAccountManagement = true,
    Map<String, dynamic> additionalConfig = const {},
    bool enabled = true,
    String? configurationId,
  }) {
    return ProviderConfiguration(
      type: CloudProviderType.custom,
      displayName: displayName,
      logoWidget: logoWidget,
      logoAssetPath: logoAssetPath,
      generateAuthUrl: generateAuthUrl,
      generateTokenUrl: generateTokenUrl,
      redirectScheme: redirectScheme,
      requiredScopes: requiredScopes,
      providerCapabilities: capabilities,
      requiresAccountManagement: requiresAccountManagement,
      createProvider: createProvider,
      additionalConfig: additionalConfig,
      enabled: enabled,
      configurationId: configurationId,
    );
  }

  /// Creates a local server provider configuration (for development/testing)
  static ProviderConfiguration localServer({
    String displayName = 'Local Development Server',
    Widget? logoWidget,
    Map<String, dynamic> additionalConfig = const {},
    bool enabled = true,
    String? configurationId,
  }) {
    return ProviderConfiguration(
      type: CloudProviderType.localServer,
      displayName: displayName,
      logoWidget:
          logoWidget ??
          const Icon(Icons.storage), // Default icon for local server
      generateAuthUrl: (s) =>
          throw 'Unexpected generateAuthUrl call for local server',
      generateTokenUrl: (s) =>
          throw 'Unexpected generateTokenUrl call for local server',
      redirectScheme: 'UNKNOWN',
      requiredScopes: {},
      providerCapabilities: const ProviderCapabilities(
        canUpload: true,
        canCreateFolders: true,
        canDelete: true,
        canSearch: false, // Local server might not support search initially
        hasThumbnails: false,
        canShare: false,
        canMove: true,
        canCopy: true,
        canRename: true,
        maxPageSize: 50,
      ),
      requiresAccountManagement:
          false, // Local server doesn't need multiple accounts
      additionalConfig: additionalConfig,
      enabled: enabled,
      configurationId: configurationId,
    );
  }
}
