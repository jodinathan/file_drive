import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import '../enums/cloud_provider_type.dart';
import '../enums/oauth_scope.dart';
import '../models/oni_cloud_provider_config.dart';

/// InheritedWidget that provides cloud provider configurations following oni* architecture
///
/// This widget propagates cloud provider configurations down the widget tree,
/// allowing child widgets to access provider configurations without explicit
/// dependency injection.
class CloudProviderConfigWidget extends InheritedWidget {
  /// Map of provider configurations by provider type
  final Map<CloudProviderType, OniCloudProviderConfig> _configurations;
  
  /// Cache for enabled providers (computed once)
  final Set<CloudProviderType> _enabledProviders;

  CloudProviderConfigWidget({
    super.key,
    required Map<CloudProviderType, OniCloudProviderConfig> configurations,
    required super.child,
  }) : _configurations = Map.unmodifiable(configurations),
       _enabledProviders = configurations.entries
           .where((entry) => entry.value.enabled)
           .map((entry) => entry.key)
           .toSet();

  /// Gets the CloudProviderConfigWidget from the current context
  ///
  /// Throws [FlutterError] if no CloudProviderConfigWidget is found in the widget tree.
  static CloudProviderConfigWidget of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<CloudProviderConfigWidget>();
    if (widget == null) {
      throw FlutterError(
        'CloudProviderConfigWidget.of() called with a context that does not contain '
        'a CloudProviderConfigWidget.\n'
        'Make sure that CloudProviderConfigWidget is an ancestor of the widget that '
        'calls CloudProviderConfigWidget.of().',
      );
    }
    return widget;
  }

  /// Gets the CloudProviderConfigWidget from the current context, or null if not found
  static CloudProviderConfigWidget? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CloudProviderConfigWidget>();
  }

  /// Gets all provider configurations
  Map<CloudProviderType, OniCloudProviderConfig> get configurations => _configurations;

  /// Gets configuration for a specific provider
  ///
  /// Returns null if no configuration exists for the provider.
  OniCloudProviderConfig? getConfiguration(CloudProviderType providerType) {
    return _configurations[providerType];
  }

  /// Checks if a provider is configured and enabled
  bool isProviderConfigured(CloudProviderType providerType) {
    final config = _configurations[providerType];
    return config != null && config.enabled;
  }

  /// Gets all enabled provider types
  Set<CloudProviderType> get enabledProviders => Set.unmodifiable(_enabledProviders);

  /// Gets available scopes for a specific provider
  ///
  /// Returns empty set if provider is not configured.
  Set<OAuthScope> getAvailableScopes(CloudProviderType providerType) {
    final config = _configurations[providerType];
    return config?.scopes ?? {};
  }

  /// Gets OAuth client ID for a specific provider
  ///
  /// Returns null if provider is not configured.
  String? getClientId(CloudProviderType providerType) {
    return _configurations[providerType]?.clientId;
  }

  /// Gets OAuth client secret for a specific provider
  ///
  /// Returns null if provider is not configured or doesn't have a client secret.
  String? getClientSecret(CloudProviderType providerType) {
    return _configurations[providerType]?.clientSecret;
  }

  /// Gets custom OAuth endpoints for a specific provider
  ///
  /// Returns null if provider doesn't have custom endpoints.
  OAuthEndpoints? getCustomEndpoints(CloudProviderType providerType) {
    return _configurations[providerType]?.customEndpoints;
  }

  /// Gets additional configuration for a specific provider
  ///
  /// Returns empty map if provider is not configured.
  Map<String, dynamic> getAdditionalConfig(CloudProviderType providerType) {
    return _configurations[providerType]?.additionalConfig ?? {};
  }

  /// Validates all configurations
  ///
  /// Throws [ArgumentError] if any configuration is invalid.
  void validateConfigurations() {
    for (final config in _configurations.values) {
      config.validate();
    }
  }

  /// Creates a new CloudProviderConfigWidget with updated configuration
  CloudProviderConfigWidget copyWith({
    Map<CloudProviderType, OniCloudProviderConfig>? configurations,
    Widget? child,
  }) {
    return CloudProviderConfigWidget(
      configurations: configurations ?? _configurations,
      child: child ?? this.child,
    );
  }

  /// Adds or updates a provider configuration
  CloudProviderConfigWidget withProvider(
    CloudProviderType providerType,
    OniCloudProviderConfig config,
  ) {
    final newConfigurations = Map<CloudProviderType, OniCloudProviderConfig>.from(_configurations);
    newConfigurations[providerType] = config;
    
    return CloudProviderConfigWidget(
      configurations: newConfigurations,
      child: child,
    );
  }

  /// Removes a provider configuration
  CloudProviderConfigWidget withoutProvider(CloudProviderType providerType) {
    final newConfigurations = Map<CloudProviderType, OniCloudProviderConfig>.from(_configurations);
    newConfigurations.remove(providerType);
    
    return CloudProviderConfigWidget(
      configurations: newConfigurations,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(CloudProviderConfigWidget oldWidget) {
    // Only notify if the configurations actually changed
    if (_configurations.length != oldWidget._configurations.length) {
      return true;
    }
    
    for (final entry in _configurations.entries) {
      final oldConfig = oldWidget._configurations[entry.key];
      if (oldConfig != entry.value) {
        return true;
      }
    }
    
    return false;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Map<CloudProviderType, OniCloudProviderConfig>>(
      'configurations',
      _configurations,
    ));
    properties.add(DiagnosticsProperty<Set<CloudProviderType>>(
      'enabledProviders',
      _enabledProviders,
    ));
  }
}

/// Extension methods for BuildContext to access cloud provider configurations
extension CloudProviderConfigContext on BuildContext {
  /// Gets the CloudProviderConfigWidget from this context
  CloudProviderConfigWidget get cloudProviderConfig => CloudProviderConfigWidget.of(this);
  
  /// Gets the CloudProviderConfigWidget from this context, or null if not found
  CloudProviderConfigWidget? get cloudProviderConfigOrNull => CloudProviderConfigWidget.maybeOf(this);
  
  /// Checks if a provider is configured and enabled in this context
  bool isProviderConfigured(CloudProviderType providerType) {
    return cloudProviderConfigOrNull?.isProviderConfigured(providerType) ?? false;
  }
  
  /// Gets available scopes for a provider in this context
  Set<OAuthScope> getProviderScopes(CloudProviderType providerType) {
    return cloudProviderConfigOrNull?.getAvailableScopes(providerType) ?? {};
  }
}