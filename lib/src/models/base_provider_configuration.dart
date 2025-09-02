import 'package:flutter/material.dart';

import '../enums/cloud_provider_type.dart';

/// Enum representing individual provider capabilities
/// Replaces the ProviderCapabilities class model with a more flexible approach
enum ProviderCapability {
  upload,
  createFolders,
  delete,
  permanentDelete,
  search,
  chunkedUpload,
  thumbnails,
  share,
  move,
  copy,
  rename,
}

/// Abstract base class for all provider configurations
/// 
/// This class establishes the foundation for immutable, constructor-based
/// provider configurations that replace the nullable configuration patterns.
/// All provider configurations must extend this class and implement validation.
abstract class BaseProviderConfiguration {
  /// The cloud provider type this configuration represents
  final CloudProviderType type;

  /// Human-readable display name for this provider
  final String displayName;

  /// Optional custom widget for displaying the provider logo
  final Widget? logoWidget;

  /// Set of capabilities supported by this provider
  final Set<ProviderCapability> capabilities;

  /// Whether this provider configuration is enabled
  final bool enabled;

  /// Unique identifier for this configuration (useful for multi-tenant scenarios)
  final String? configurationId;

  /// Creates a base provider configuration with validation
  /// 
  /// All concrete implementations must call this constructor and provide
  /// the required parameters. The constructor will automatically validate
  /// the configuration and throw [ArgumentError] if invalid.
  const BaseProviderConfiguration({
    required this.type,
    required this.displayName,
    this.logoWidget,
    required this.capabilities,
    this.enabled = true,
    this.configurationId,
  });

  /// Validates this configuration
  /// 
  /// This method is called automatically during construction and should be
  /// overridden by concrete implementations to add provider-specific validation.
  /// Throws [ArgumentError] if the configuration is invalid.
  void validate() {
    if (displayName.isEmpty) {
      throw ArgumentError('Display name cannot be empty');
    }

    if (capabilities.isEmpty) {
      throw ArgumentError('At least one capability must be specified');
    }
  }

  /// Creates a copy of this configuration with updated values
  /// 
  /// This method must be implemented by concrete classes to support
  /// the copyWith pattern while maintaining type safety.
  BaseProviderConfiguration copyWith({
    CloudProviderType? type,
    String? displayName,
    Widget? logoWidget,
    Set<ProviderCapability>? capabilities,
    bool? enabled,
    String? configurationId,
  });

  /// Converts this configuration to a JSON map
  /// 
  /// Note: Widget properties are not serialized and must be reconstructed
  /// when deserializing from JSON.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'displayName': displayName,
      'capabilities': capabilities.map((c) => c.name).toList(),
      'enabled': enabled,
      'configurationId': configurationId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is BaseProviderConfiguration &&
        other.type == type &&
        other.displayName == displayName &&
        other.capabilities.length == capabilities.length &&
        other.capabilities.every(capabilities.contains) &&
        other.enabled == enabled &&
        other.configurationId == configurationId;
    // Note: logoWidget is excluded from equality comparison as Widget
    // instances cannot be reliably compared for equality
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      displayName,
      Object.hashAll(capabilities),
      enabled,
      configurationId,
      // Note: logoWidget is excluded from hash calculation
      // to maintain consistency with equality comparison
    );
  }

  @override
  String toString() {
    return '${runtimeType}('
        'type: $type, '
        'displayName: $displayName, '
        'capabilities: ${capabilities.map((c) => c.name).join(', ')}, '
        'enabled: $enabled'
        ')';
  }
}