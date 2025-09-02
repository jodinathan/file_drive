import 'package:flutter/material.dart';

import '../enums/cloud_provider_type.dart';
import 'base_provider_configuration.dart';

/// Configuration for local server-based cloud storage providers
/// 
/// This class extends BaseProviderConfiguration for providers that communicate
/// directly with local or custom servers without OAuth authentication.
/// Typically used for development, testing, or custom enterprise solutions.
class LocalProviderConfiguration extends BaseProviderConfiguration {
  /// Base URI for the local server
  /// 
  /// This should be the root URL of your local server
  /// (e.g., 'http://localhost:8080', 'https://api.mycompany.com')
  final Uri baseUri;

  /// Optional HTTP headers to include with all requests
  /// 
  /// These headers are added to every HTTP request made to the server.
  /// Common use cases include API keys, custom authentication headers,
  /// or content type specifications.
  final Map<String, String>? headers;

  /// Timeout duration for HTTP requests
  /// 
  /// Specifies how long to wait for server responses before timing out.
  /// Defaults to 30 seconds if not specified.
  final Duration timeout;

  /// Additional provider-specific configuration parameters
  /// 
  /// This map can contain server-specific settings like API versions,
  /// custom endpoints, feature flags, etc.
  final Map<String, dynamic> additionalConfig;

  /// Creates a local provider configuration with validation
  /// 
  /// All parameters are validated during construction. Local server validation
  /// includes URI format checking and timeout reasonableness.
  const LocalProviderConfiguration({
    required super.type,
    required super.displayName,
    super.logoWidget,
    required super.capabilities,
    super.enabled = true,
    super.configurationId,
    required this.baseUri,
    this.headers,
    this.timeout = const Duration(seconds: 30),
    this.additionalConfig = const {},
  });

  @override
  void validate() {
    // Call base validation first
    super.validate();

    // Local server-specific validation
    if (!baseUri.hasScheme) {
      throw ArgumentError('Base URI must have a valid scheme (http/https)');
    }

    if (baseUri.host.isEmpty) {
      throw ArgumentError('Base URI must have a valid host');
    }

    if (!['http', 'https'].contains(baseUri.scheme.toLowerCase())) {
      throw ArgumentError('Base URI must use http or https scheme');
    }

    if (timeout.inMilliseconds <= 0) {
      throw ArgumentError('Timeout must be positive');
    }

    if (timeout.inMinutes > 10) {
      throw ArgumentError('Timeout should not exceed 10 minutes');
    }

    // Validate headers if provided
    if (headers != null) {
      for (final entry in headers!.entries) {
        if (entry.key.isEmpty) {
          throw ArgumentError('Header names cannot be empty');
        }
        // Headers values can be empty (for some edge cases)
      }
    }
  }

  /// Builds a complete URI for a given endpoint path
  /// 
  /// Combines the base URI with the provided path to create a complete
  /// URI for making HTTP requests to the server.
  Uri buildUri(String path) {
    // Ensure path starts with '/' for proper URI resolution
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUri.resolve(normalizedPath);
  }

  /// Gets HTTP headers for requests, including any configured custom headers
  /// 
  /// Returns a map of headers that should be included with HTTP requests.
  /// Includes both the configured custom headers and any default headers.
  Map<String, String> getRequestHeaders({
    Map<String, String>? additionalHeaders,
  }) {
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add configured headers
    if (headers != null) {
      requestHeaders.addAll(headers!);
    }

    // Add any additional headers provided for this specific request
    if (additionalHeaders != null) {
      requestHeaders.addAll(additionalHeaders);
    }

    return requestHeaders;
  }

  @override
  LocalProviderConfiguration copyWith({
    CloudProviderType? type,
    String? displayName,
    Widget? logoWidget,
    Set<ProviderCapability>? capabilities,
    bool? enabled,
    String? configurationId,
    Uri? baseUri,
    Map<String, String>? headers,
    Duration? timeout,
    Map<String, dynamic>? additionalConfig,
  }) {
    return LocalProviderConfiguration(
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      logoWidget: logoWidget ?? this.logoWidget,
      capabilities: capabilities ?? this.capabilities,
      enabled: enabled ?? this.enabled,
      configurationId: configurationId ?? this.configurationId,
      baseUri: baseUri ?? this.baseUri,
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      additionalConfig: additionalConfig ?? this.additionalConfig,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson.addAll({
      'baseUri': baseUri.toString(),
      'headers': headers,
      'timeout': timeout.inMilliseconds,
      'additionalConfig': additionalConfig,
    });
    return baseJson;
  }

  /// Creates a local provider configuration from a JSON map
  factory LocalProviderConfiguration.fromJson(
    Map<String, dynamic> json, {
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

    final baseUri = Uri.parse(json['baseUri'] as String);
    final timeoutMs = json['timeout'] as int? ?? 30000;
    final headers = json['headers'] != null
        ? Map<String, String>.from(json['headers'] as Map)
        : null;

    return LocalProviderConfiguration(
      type: type,
      displayName: json['displayName'] as String,
      logoWidget: logoWidget,
      capabilities: capabilities,
      enabled: json['enabled'] as bool? ?? true,
      configurationId: json['configurationId'] as String?,
      baseUri: baseUri,
      headers: headers,
      timeout: Duration(milliseconds: timeoutMs),
      additionalConfig: Map<String, dynamic>.from(
        json['additionalConfig'] as Map? ?? {},
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is LocalProviderConfiguration &&
        super == other &&
        other.baseUri == baseUri &&
        other.timeout == timeout &&
        _mapsEqual(other.headers, headers) &&
        _mapsEqual(other.additionalConfig, additionalConfig);
  }

  @override
  int get hashCode {
    return Object.hash(
      super.hashCode,
      baseUri,
      timeout,
      Object.hashAll(headers?.entries ?? []),
      Object.hashAll(additionalConfig.entries),
    );
  }

  /// Helper method to compare maps for equality
  bool _mapsEqual<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}