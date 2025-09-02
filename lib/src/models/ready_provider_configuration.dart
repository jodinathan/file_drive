import 'package:flutter/material.dart';

import '../enums/cloud_provider_type.dart';
import '../providers/base_cloud_provider.dart';
import 'base_provider_configuration.dart';

/// Configuration wrapper for pre-instantiated cloud storage providers
/// 
/// This class extends BaseProviderConfiguration to wrap existing provider
/// instances, enabling dependency injection and custom provider registration
/// patterns. Useful for complex providers that require custom initialization
/// or when providers are managed by external systems.
class ReadyProviderConfiguration extends BaseProviderConfiguration {
  /// The pre-instantiated provider instance
  /// 
  /// This provider must be fully configured and ready to use.
  /// The wrapper extracts common configuration properties from the instance.
  final BaseCloudProvider providerInstance;

  /// Whether this provider requires account management features
  /// 
  /// If true, the provider will support multiple accounts and account switching.
  /// This value is typically extracted from the provider instance during creation.
  final bool requiresAccountManagement;

  /// Additional configuration metadata
  /// 
  /// This map can contain metadata about the provider instance,
  /// configuration source, or other relevant information.
  final Map<String, dynamic> additionalConfig;

  /// Creates a ready provider configuration by wrapping an existing provider
  /// 
  /// The configuration properties are extracted from the provider instance
  /// where possible, with explicit overrides supported for customization.
  const ReadyProviderConfiguration({
    required super.type,
    required super.displayName,
    super.logoWidget,
    required super.capabilities,
    super.enabled = true,
    super.configurationId,
    required this.providerInstance,
    this.requiresAccountManagement = true,
    this.additionalConfig = const {},
  });

  /// Factory constructor that creates configuration from a provider instance
  /// 
  /// This factory extracts as much configuration as possible from the provider
  /// instance itself, requiring minimal explicit configuration.
  factory ReadyProviderConfiguration.fromProvider({
    required BaseCloudProvider providerInstance,
    String? displayName,
    Widget? logoWidget,
    Set<ProviderCapability>? capabilities,
    bool enabled = true,
    String? configurationId,
    Map<String, dynamic> additionalConfig = const {},
  }) {
    return ReadyProviderConfiguration(
      type: providerInstance.providerType,
      displayName: displayName ?? providerInstance.providerType.displayName,
      logoWidget: logoWidget,
      capabilities: capabilities ?? _extractCapabilitiesFromProvider(providerInstance),
      enabled: enabled,
      configurationId: configurationId,
      providerInstance: providerInstance,
      requiresAccountManagement: providerInstance.requiresAccountManagement,
      additionalConfig: additionalConfig,
    );
  }

  @override
  void validate() {
    // Call base validation first
    super.validate();

    // Ready provider-specific validation
    if (providerInstance.providerType != type) {
      throw ArgumentError(
        'Provider instance type (${providerInstance.providerType}) '
        'must match configuration type ($type)'
      );
    }

    // Verify the provider instance is in a valid state
    try {
      // Basic provider validation - ensure it has required properties
      // These calls should not throw exceptions for a properly configured provider
      // Provider type is non-nullable enum, so no null check needed
      providerInstance.providerType;
    } catch (e) {
      throw ArgumentError('Provider instance is not properly configured: $e');
    }
  }

  @override
  ReadyProviderConfiguration copyWith({
    CloudProviderType? type,
    String? displayName,
    Widget? logoWidget,
    Set<ProviderCapability>? capabilities,
    bool? enabled,
    String? configurationId,
    BaseCloudProvider? providerInstance,
    bool? requiresAccountManagement,
    Map<String, dynamic>? additionalConfig,
  }) {
    return ReadyProviderConfiguration(
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      logoWidget: logoWidget ?? this.logoWidget,
      capabilities: capabilities ?? this.capabilities,
      enabled: enabled ?? this.enabled,
      configurationId: configurationId ?? this.configurationId,
      providerInstance: providerInstance ?? this.providerInstance,
      requiresAccountManagement:
          requiresAccountManagement ?? this.requiresAccountManagement,
      additionalConfig: additionalConfig ?? this.additionalConfig,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson.addAll({
      'requiresAccountManagement': requiresAccountManagement,
      'additionalConfig': additionalConfig,
      'providerInstanceType': providerInstance.runtimeType.toString(),
    });
    return baseJson;
  }

  /// Creates a ready provider configuration from JSON
  /// 
  /// Note: This factory cannot restore the provider instance from JSON.
  /// You must provide the provider instance separately when deserializing.
  factory ReadyProviderConfiguration.fromJson(
    Map<String, dynamic> json, {
    required BaseCloudProvider providerInstance,
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

    return ReadyProviderConfiguration(
      type: type,
      displayName: json['displayName'] as String,
      logoWidget: logoWidget,
      capabilities: capabilities,
      enabled: json['enabled'] as bool? ?? true,
      configurationId: json['configurationId'] as String?,
      providerInstance: providerInstance,
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
    
    return other is ReadyProviderConfiguration &&
        super == other &&
        other.providerInstance == providerInstance &&
        other.requiresAccountManagement == requiresAccountManagement &&
        _mapsEqual(other.additionalConfig, additionalConfig);
  }

  @override
  int get hashCode {
    return Object.hash(
      super.hashCode,
      providerInstance,
      requiresAccountManagement,
      Object.hashAll(additionalConfig.entries),
    );
  }

  /// Helper method to compare maps for equality
  bool _mapsEqual<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Helper method to extract capabilities from a provider instance
  /// 
  /// This method attempts to determine provider capabilities based on
  /// the provider type and any available metadata.
  static Set<ProviderCapability> _extractCapabilitiesFromProvider(
    BaseCloudProvider provider,
  ) {
    // Default capabilities based on provider type
    switch (provider.providerType) {
      case CloudProviderType.googleDrive:
        return {
          ProviderCapability.upload,
          ProviderCapability.createFolders,
          ProviderCapability.delete,
          ProviderCapability.search,
          ProviderCapability.thumbnails,
          ProviderCapability.share,
          ProviderCapability.move,
          ProviderCapability.copy,
          ProviderCapability.rename,
        };
      
      case CloudProviderType.localServer:
        return {
          ProviderCapability.upload,
          ProviderCapability.createFolders,
          ProviderCapability.delete,
          ProviderCapability.move,
          ProviderCapability.copy,
          ProviderCapability.rename,
        };
      
      case CloudProviderType.oneDrive:
      case CloudProviderType.dropbox:
        return {
          ProviderCapability.upload,
          ProviderCapability.createFolders,
          ProviderCapability.delete,
          ProviderCapability.search,
          ProviderCapability.move,
          ProviderCapability.copy,
          ProviderCapability.rename,
        };
      
      case CloudProviderType.custom:
        // For custom providers, assume basic capabilities
        return {
          ProviderCapability.upload,
          ProviderCapability.createFolders,
        };
    }
  }
}