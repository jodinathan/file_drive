import '../enums/cloud_provider_type.dart';
import '../models/base_provider_configuration.dart';
import '../models/oauth_provider_configuration.dart';
import '../models/ready_provider_configuration.dart';
import '../providers/base_cloud_provider.dart';
import '../providers/google_drive_provider.dart';
import '../providers/onedrive_provider.dart';
import '../providers/local_server_provider.dart';

/// Exception thrown by the CloudProviderFactory
class CloudProviderFactoryException implements Exception {
  /// Error message
  final String message;
  
  /// Error code (if applicable)
  final String? code;
  
  /// Original exception (if any)
  final dynamic originalException;

  const CloudProviderFactoryException(
    this.message, {
    this.code,
    this.originalException,
  });

  @override
  String toString() => 'CloudProviderFactoryException: $message';
}

/// Type-safe provider constructor function signature
/// 
/// This typedef defines the signature for provider constructors that can be
/// registered with the factory. It ensures type safety by requiring that
/// the configuration type [C] matches what the provider constructor expects.
typedef ProviderConstructor<C extends BaseProviderConfiguration> = BaseCloudProvider Function({
  required C configuration,
  dynamic account,
});

/// Registry entry that maps configuration types to provider constructors
/// 
/// This class encapsulates the relationship between a configuration type
/// and its corresponding provider constructor, maintaining type safety
/// throughout the factory system.
class ProviderRegistryEntry<C extends BaseProviderConfiguration> {
  /// The configuration type this entry handles
  final Type configurationType;
  
  /// The provider type this entry creates
  final CloudProviderType providerType;
  
  /// Constructor function for creating provider instances
  final ProviderConstructor<C> constructor;
  
  /// Display name for this provider registration
  final String displayName;
  
  /// Whether this registration is for a built-in provider
  final bool isBuiltIn;

  const ProviderRegistryEntry({
    required this.configurationType,
    required this.providerType,
    required this.constructor,
    required this.displayName,
    this.isBuiltIn = false,
  });

  @override
  String toString() => 'ProviderRegistryEntry($displayName: $configurationType -> $providerType)';
}

/// Factory for creating cloud storage providers with type safety and validation
/// 
/// This factory provides a centralized, type-safe way to create provider instances
/// from configurations. It supports both static registration of built-in providers
/// (OAuth providers like Google Drive, OneDrive, Dropbox) and dynamic registration
/// of custom providers via ReadyProviderConfiguration.
/// 
/// ## Key Features
/// - **Type Safety**: Compile-time type checking between configurations and providers
/// - **Static Registration**: Built-in OAuth providers automatically registered
/// - **Dynamic Registration**: Support for custom provider instances
/// - **Validation**: Comprehensive validation and error handling
/// - **Extensibility**: Easy to add new provider types
/// 
/// ## Usage Examples
/// 
/// ### Creating OAuth Provider
/// ```dart
/// final config = OAuthProviderConfiguration(
///   type: CloudProviderType.googleDrive,
///   displayName: 'My Google Drive',
///   // ... other configuration
/// );
/// 
/// final provider = CloudProviderFactory.createFromConfiguration(config);
/// ```
/// 
/// ### Registering Custom Provider
/// ```dart
/// final customProvider = MyCustomProvider(/* ... */);
/// final readyConfig = ReadyProviderConfiguration.fromProvider(
///   providerInstance: customProvider,
/// );
/// 
/// CloudProviderFactory.registerProviderInstance(readyConfig);
/// final provider = CloudProviderFactory.createFromConfiguration(readyConfig);
/// ```
/// 
/// ## Architecture
/// 
/// The factory uses a two-tier registration system:
/// 1. **Static Registry**: Built-in providers registered at class initialization
/// 2. **Instance Registry**: Custom provider instances registered at runtime
/// 
/// Type safety is enforced through:
/// - Generic type constraints on registration methods
/// - Runtime type validation during provider creation
/// - Compile-time type checking via typedef constraints
abstract class CloudProviderFactory {
  
  /// Internal registry for static provider constructors
  /// Maps configuration types to their corresponding provider constructors
  static final Map<Type, ProviderRegistryEntry> _staticRegistry = <Type, ProviderRegistryEntry>{};
  
  /// Internal registry for instance-based providers (ReadyProviderConfiguration)
  /// Maps configuration IDs to their provider instances for quick lookup
  static final Map<String, ReadyProviderConfiguration> _instanceRegistry = <String, ReadyProviderConfiguration>{};
  
  /// Whether the static providers have been initialized
  static bool _staticProvidersInitialized = false;
  
  /// Private constructor to prevent instantiation
  CloudProviderFactory._();
  
  /// Creates a provider instance from the given configuration
  /// 
  /// This is the main entry point for the factory. It accepts any subtype of
  /// [BaseProviderConfiguration] and returns an appropriate provider instance.
  /// 
  /// The method performs the following steps:
  /// 1. Validates the input configuration
  /// 2. Determines the configuration type and looks up the appropriate constructor
  /// 3. Creates and returns the provider instance
  /// 4. Handles type-specific creation logic (OAuth vs Ready vs Local)
  /// 
  /// [config] - The provider configuration (must not be null)
  /// 
  /// Returns a configured provider instance ready for use
  /// 
  /// Throws [CloudProviderFactoryException] if:
  /// - Configuration is null or invalid
  /// - No provider is registered for the configuration type
  /// - Provider creation fails
  /// - Type safety validation fails
  static BaseCloudProvider createFromConfiguration(BaseProviderConfiguration config) {
    _ensureStaticProvidersInitialized();
    _validateConfiguration(config);
    
    // Handle ReadyProviderConfiguration specially
    if (config is ReadyProviderConfiguration) {
      return _createFromReadyConfiguration(config);
    }
    
    // Look up provider constructor from static registry
    final registryEntry = _staticRegistry[config.runtimeType];
    if (registryEntry == null) {
      throw CloudProviderFactoryException(
        'No provider registered for configuration type: ${config.runtimeType}',
        code: 'PROVIDER_NOT_REGISTERED',
      );
    }
    
    try {
      // Create provider instance using registered constructor
      return registryEntry.constructor(
        configuration: config,
        account: null, // Account will be set later via setCurrentAccount()
      );
    } catch (e) {
      throw CloudProviderFactoryException(
        'Failed to create provider for ${config.runtimeType}: $e',
        code: 'PROVIDER_CREATION_FAILED',
        originalException: e,
      );
    }
  }
  
  /// Registers a static provider constructor for OAuth and Local providers
  /// 
  /// This method is used internally to register built-in provider types
  /// and can be used by applications to register custom provider types
  /// that follow the standard constructor pattern.
  /// 
  /// [configurationType] - The Type of configuration this provider handles
  /// [providerType] - The CloudProviderType enum value
  /// [constructor] - Function that creates provider instances
  /// [displayName] - Human-readable name for this provider
  /// [isBuiltIn] - Whether this is a built-in provider (default: false)
  /// 
  /// Type safety is enforced by requiring the constructor parameter type
  /// to match the declared configuration type [C].
  /// 
  /// Throws [CloudProviderFactoryException] if:
  /// - Configuration type is already registered
  /// - Parameters are invalid
  static void registerStaticProvider<C extends BaseProviderConfiguration>({
    required Type configurationType,
    required CloudProviderType providerType,
    required ProviderConstructor<C> constructor,
    required String displayName,
    bool isBuiltIn = false,
  }) {
    _validateRegistrationParameters(
      configurationType: configurationType,
      providerType: providerType,
      displayName: displayName,
    );
    
    if (_staticRegistry.containsKey(configurationType)) {
      throw CloudProviderFactoryException(
        'Provider already registered for configuration type: $configurationType',
        code: 'PROVIDER_ALREADY_REGISTERED',
      );
    }
    
    final entry = ProviderRegistryEntry<C>(
      configurationType: configurationType,
      providerType: providerType,
      constructor: constructor,
      displayName: displayName,
      isBuiltIn: isBuiltIn,
    );
    
    _staticRegistry[configurationType] = entry;
  }
  
  /// Registers a provider instance for use with ReadyProviderConfiguration
  /// 
  /// This method allows registration of pre-instantiated provider instances,
  /// which is useful for dependency injection patterns or complex providers
  /// that require custom initialization logic.
  /// 
  /// [config] - ReadyProviderConfiguration wrapping the provider instance
  /// 
  /// The configuration is stored in the instance registry using its
  /// configurationId for quick lookup during provider creation.
  /// 
  /// Throws [CloudProviderFactoryException] if:
  /// - Configuration is invalid
  /// - Configuration ID is already registered
  /// - Provider instance is null or invalid
  static void registerProviderInstance(ReadyProviderConfiguration config) {
    _validateReadyConfiguration(config);
    
    final configId = config.configurationId;
    if (configId == null || configId.isEmpty) {
      throw CloudProviderFactoryException(
        'ReadyProviderConfiguration must have a non-empty configurationId for registration',
        code: 'MISSING_CONFIGURATION_ID',
      );
    }
    
    if (_instanceRegistry.containsKey(configId)) {
      throw CloudProviderFactoryException(
        'Provider instance already registered with ID: $configId',
        code: 'INSTANCE_ALREADY_REGISTERED',
      );
    }
    
    _instanceRegistry[configId] = config;
  }
  
  /// Unregisters a provider instance by configuration ID
  /// 
  /// [configurationId] - The ID of the configuration to unregister
  /// 
  /// Returns true if a provider was removed, false if not found
  static bool unregisterProviderInstance(String configurationId) {
    return _instanceRegistry.remove(configurationId) != null;
  }
  
  /// Gets information about all registered static providers
  /// 
  /// Returns a list of registry entries for all statically registered providers.
  /// This is useful for debugging, introspection, and dynamic UI generation.
  static List<ProviderRegistryEntry> getRegisteredStaticProviders() {
    _ensureStaticProvidersInitialized();
    return _staticRegistry.values.toList();
  }
  
  /// Gets information about all registered provider instances
  /// 
  /// Returns a list of ReadyProviderConfiguration objects for all registered
  /// provider instances. This is useful for debugging and management.
  static List<ReadyProviderConfiguration> getRegisteredInstances() {
    return _instanceRegistry.values.toList();
  }
  
  /// Checks if a provider is registered for the given configuration type
  /// 
  /// [configurationType] - The configuration type to check
  /// 
  /// Returns true if a provider is registered for this type
  static bool isProviderRegistered(Type configurationType) {
    _ensureStaticProvidersInitialized();
    return _staticRegistry.containsKey(configurationType) ||
           configurationType == ReadyProviderConfiguration;
  }
  
  /// Checks if a provider instance is registered with the given ID
  /// 
  /// [configurationId] - The configuration ID to check
  /// 
  /// Returns true if a provider instance is registered with this ID
  static bool isInstanceRegistered(String configurationId) {
    return _instanceRegistry.containsKey(configurationId);
  }
  
  /// Clears all registered provider instances (for testing)
  /// 
  /// This method clears the instance registry but preserves static registrations.
  /// It's primarily intended for testing scenarios where clean state is needed.
  static void clearInstanceRegistry() {
    _instanceRegistry.clear();
  }
  
  /// Resets all registrations (for testing)
  /// 
  /// This method clears both static and instance registries and resets
  /// the initialization flag. It's primarily intended for testing scenarios.
  /// 
  /// **Warning**: This will clear all built-in provider registrations
  /// and require re-initialization.
  static void resetAllRegistrations() {
    _staticRegistry.clear();
    _instanceRegistry.clear();
    _staticProvidersInitialized = false;
  }
  
  // Private helper methods
  
  /// Ensures static providers are initialized
  /// 
  /// This method registers all built-in providers with the factory.
  /// It runs only once per application lifetime and registers:
  /// - Google Drive (OAuth provider)
  /// - Local Server (for testing and development)
  /// 
  /// Note: OneDrive and Dropbox are defined in CloudProviderType enum
  /// but don't have concrete implementations yet, so they're not registered.
  static void _ensureStaticProvidersInitialized() {
    if (_staticProvidersInitialized) return;
    
    try {
      // Register Google Drive OAuth provider
      registerStaticProvider<OAuthProviderConfiguration>(
        configurationType: OAuthProviderConfiguration,
        providerType: CloudProviderType.googleDrive,
        constructor: ({required configuration, account}) => GoogleDriveProvider(
          oauthConfiguration: configuration as OAuthProviderConfiguration,
          account: account,
        ),
        displayName: 'Google Drive',
        isBuiltIn: true,
      );
      
      // Note: Dropbox provider is not yet implemented
      // It can be added here when concrete implementation is available
      
      // Register Local Server provider
      registerStaticProvider<LocalServerProviderConfig>(
        configurationType: LocalServerProviderConfig,
        providerType: CloudProviderType.localServer,
        constructor: ({required configuration, account}) => LocalServerProvider(
          configuration: configuration,
          account: account,
        ),
        displayName: 'Local Server',
        isBuiltIn: true,
      );
      
      // NOTE: OneDrive OAuth provider temporarily disabled due to 
      // type conflict with GoogleDrive (both use OAuthProviderConfiguration)
      // TODO: Create specific configuration types for each OAuth provider
      // registerStaticProvider<OAuthProviderConfiguration>(
      //   configurationType: OAuthProviderConfiguration,
      //   providerType: CloudProviderType.oneDrive,
      //   constructor: ({required configuration, account}) => OneDriveProvider(
      //     oauthConfiguration: configuration,
      //     account: account,
      //   ),
      //   displayName: 'OneDrive',
      //   isBuiltIn: true,
      // );
      
      // Note: Dropbox provider will be implemented in a separate task
      
    } catch (e) {
      // If registration fails, reset the flag so it can be retried
      _staticProvidersInitialized = false;
      throw CloudProviderFactoryException(
        'Failed to initialize static providers: $e',
        code: 'STATIC_INITIALIZATION_FAILED',
        originalException: e,
      );
    }
    
    _staticProvidersInitialized = true;
  }
  
  /// Creates provider from ReadyProviderConfiguration
  /// 
  /// This method handles instance-based provider creation by extracting
  /// pre-instantiated provider instances from ReadyProviderConfiguration.
  /// 
  /// The method supports two scenarios:
  /// 1. **Registered instances**: If the configuration has a configurationId,
  ///    it attempts to look up the configuration in the instance registry
  /// 2. **Direct instances**: If not found in registry or no configurationId,
  ///    it uses the provider instance directly from the passed configuration
  /// 
  /// This dual approach supports both dependency injection patterns
  /// (pre-registered instances) and direct usage patterns.
  static BaseCloudProvider _createFromReadyConfiguration(ReadyProviderConfiguration config) {
    // Validate the configuration first
    _validateReadyConfiguration(config);
    
    // Extract provider instance, with registry lookup if configuration has an ID
    BaseCloudProvider providerInstance;
    
    final configId = config.configurationId;
    if (configId != null && configId.isNotEmpty) {
      // Try to find registered configuration in instance registry
      final registeredConfig = _instanceRegistry[configId];
      if (registeredConfig != null) {
        // Use the provider instance from the registered configuration
        // This supports the dependency injection pattern where providers
        // are pre-registered with the factory
        providerInstance = registeredConfig.providerInstance;
      } else {
        // Configuration ID provided but not found in registry
        // Fall back to using the provider instance from the passed configuration
        // This allows for configurations with IDs that aren't pre-registered
        providerInstance = config.providerInstance;
      }
    } else {
      // No configuration ID provided, use the provider instance directly
      // This supports direct usage without pre-registration
      providerInstance = config.providerInstance;
    }
    
    // Provider instance should be non-null due to Dart's null safety,
    // but we perform additional validation to ensure it's ready for use
    
    // Verify provider instance is not disposed
    try {
      providerInstance.ensureNotDisposed();
    } catch (e) {
      throw CloudProviderFactoryException(
        'ReadyProviderConfiguration contains a disposed provider instance: $e',
        code: 'DISPOSED_PROVIDER_INSTANCE',
        originalException: e,
      );
    }
    
    // Additional validation: ensure provider type consistency
    if (providerInstance.providerType != config.type) {
      throw CloudProviderFactoryException(
        'Provider instance type (${providerInstance.providerType}) does not match '
        'configuration type (${config.type})',
        code: 'PROVIDER_TYPE_MISMATCH',
      );
    }
    
    // Return the provider instance ready for use
    // Note: Account management is handled separately via setCurrentAccount()
    return providerInstance;
  }
  
  /// Validates a configuration object
  /// 
  /// Performs comprehensive validation of any BaseProviderConfiguration,
  /// including type-specific validation for OAuth and Local configurations.
  static void _validateConfiguration(BaseProviderConfiguration config) {
    // First perform the built-in validation from the configuration class
    try {
      config.validate();
    } catch (e) {
      throw CloudProviderFactoryException(
        'Configuration validation failed: $e',
        code: 'INVALID_CONFIGURATION',
        originalException: e,
      );
    }
    
    // Perform additional comprehensive validation based on configuration type
    if (config is OAuthProviderConfiguration) {
      _validateOAuthConfiguration(config);
    } else if (config is LocalServerProviderConfig) {
      _validateLocalServerConfiguration(config);
    }
    
    // Validate common properties for all configurations
    _validateCommonConfigurationProperties(config);
  }
  
  /// Validates OAuth-specific configuration properties
  static void _validateOAuthConfiguration(OAuthProviderConfiguration config) {
    // Validate redirect scheme format
    if (!config.redirectScheme.contains('://')) {
      throw CloudProviderFactoryException(
        'OAuth redirect scheme must be a valid URI scheme (e.g., "myapp://oauth")',
        code: 'INVALID_OAUTH_REDIRECT_SCHEME',
      );
    }
    
    // Validate OAuth scopes
    if (config.scopes.isEmpty) {
      throw CloudProviderFactoryException(
        'OAuth configuration must specify at least one scope',
        code: 'NO_OAUTH_SCOPES',
      );
    }
    
    // Check for duplicate scopes
    final uniqueScopes = config.scopes.toSet();
    if (uniqueScopes.length != config.scopes.length) {
      throw CloudProviderFactoryException(
        'OAuth configuration contains duplicate scopes',
        code: 'DUPLICATE_OAUTH_SCOPES',
      );
    }
    
    // Validate scope values are reasonable (not empty strings)
    for (final scope in config.scopes) {
      if (scope.trim().isEmpty) {
        throw CloudProviderFactoryException(
          'OAuth scopes cannot be empty strings',
          code: 'EMPTY_OAUTH_SCOPE',
        );
      }
    }
    
    // Test URL generation functions with validation
    try {
      final testState = 'validation_test_12345';
      final authUrl = config.authUrlGenerator(testState);
      final tokenUrl = config.tokenUrlGenerator(testState);
      
      // Validate generated URLs are well-formed
      if (!authUrl.hasScheme || authUrl.host.isEmpty) {
        throw CloudProviderFactoryException(
          'OAuth authUrlGenerator must return a valid absolute URL with scheme and host',
          code: 'INVALID_OAUTH_AUTH_URL',
        );
      }
      
      if (!tokenUrl.hasScheme || tokenUrl.host.isEmpty) {
        throw CloudProviderFactoryException(
          'OAuth tokenUrlGenerator must return a valid absolute URL with scheme and host',
          code: 'INVALID_OAUTH_TOKEN_URL',
        );
      }
      
      // Check that URLs are different (they should serve different purposes)
      if (authUrl.toString() == tokenUrl.toString()) {
        throw CloudProviderFactoryException(
          'OAuth auth URL and token URL should be different endpoints',
          code: 'IDENTICAL_OAUTH_URLS',
        );
      }
      
    } catch (e) {
      if (e is CloudProviderFactoryException) rethrow;
      throw CloudProviderFactoryException(
        'OAuth URL generation validation failed: $e',
        code: 'OAUTH_URL_GENERATION_ERROR',
        originalException: e,
      );
    }
  }
  
  /// Validates Local Server configuration properties
  static void _validateLocalServerConfiguration(LocalServerProviderConfig config) {
    // Validate server URL format
    try {
      final serverUri = Uri.parse(config.serverUrl);
      
      if (!serverUri.hasScheme) {
        throw CloudProviderFactoryException(
          'Local server URL must include a scheme (http:// or https://)',
          code: 'MISSING_SERVER_URL_SCHEME',
        );
      }
      
      if (serverUri.host.isEmpty) {
        throw CloudProviderFactoryException(
          'Local server URL must include a host',
          code: 'MISSING_SERVER_URL_HOST',
        );
      }
      
      // Validate scheme is appropriate for local server
      if (!['http', 'https'].contains(serverUri.scheme.toLowerCase())) {
        throw CloudProviderFactoryException(
          'Local server URL must use http:// or https:// scheme',
          code: 'INVALID_SERVER_URL_SCHEME',
        );
      }
      
    } on FormatException catch (e) {
      throw CloudProviderFactoryException(
        'Local server URL is malformed: ${e.message}',
        code: 'MALFORMED_SERVER_URL',
        originalException: e,
      );
    } on CloudProviderFactoryException {
      rethrow;
    }
    
    // Validate test token is reasonable
    if (config.testToken.trim().isEmpty) {
      throw CloudProviderFactoryException(
        'Local server test token cannot be empty',
        code: 'EMPTY_TEST_TOKEN',
      );
    }
    
    if (config.testToken.length < 8) {
      throw CloudProviderFactoryException(
        'Local server test token should be at least 8 characters for security',
        code: 'WEAK_TEST_TOKEN',
      );
    }
  }
  
  /// Validates common configuration properties for all provider types
  static void _validateCommonConfigurationProperties(BaseProviderConfiguration config) {
    // Validate display name
    if (config.displayName.trim().isEmpty) {
      throw CloudProviderFactoryException(
        'Configuration display name cannot be empty or whitespace-only',
        code: 'INVALID_DISPLAY_NAME',
      );
    }
    
    if (config.displayName.length > 100) {
      throw CloudProviderFactoryException(
        'Configuration display name cannot exceed 100 characters (got ${config.displayName.length})',
        code: 'DISPLAY_NAME_TOO_LONG',
      );
    }
    
    // Validate capabilities
    _validateCapabilitiesForProviderType(config.capabilities, config.type, config.displayName);
    
    // Validate configuration ID if provided
    final configId = config.configurationId;
    if (configId != null) {
      if (configId.trim().isEmpty) {
        throw CloudProviderFactoryException(
          'Configuration ID cannot be empty or whitespace-only',
          code: 'INVALID_CONFIGURATION_ID',
        );
      }
      
      if (configId.length > 255) {
        throw CloudProviderFactoryException(
          'Configuration ID cannot exceed 255 characters (got ${configId.length})',
          code: 'CONFIGURATION_ID_TOO_LONG',
        );
      }
      
      // Validate configurationId format for safe usage as identifier
      if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(configId)) {
        throw CloudProviderFactoryException(
          'Configuration ID must contain only alphanumeric characters, dots, underscores, and hyphens',
          code: 'INVALID_CONFIGURATION_ID_FORMAT',
        );
      }
    }
  }
  
  /// Validates ReadyProviderConfiguration
  /// 
  /// This method performs specific validation for ReadyProviderConfiguration
  /// in addition to the base configuration validation. It ensures the
  /// provider instance is valid and ready for use.
  static void _validateReadyConfiguration(ReadyProviderConfiguration config) {
    // Perform base configuration validation
    _validateConfiguration(config);
    
    // Provider instance is guaranteed to be non-null by Dart's null safety
    
    // Validate provider instance type consistency
    if (config.providerInstance.providerType != config.type) {
      throw CloudProviderFactoryException(
        'Provider instance type (${config.providerInstance.providerType}) '
        'does not match configuration type (${config.type})',
        code: 'PROVIDER_TYPE_MISMATCH',
      );
    }
    
    // Validate configurationId format if provided
    final configId = config.configurationId;
    if (configId != null) {
      if (configId.trim().isEmpty) {
        throw CloudProviderFactoryException(
          'Configuration ID cannot be empty or contain only whitespace',
          code: 'INVALID_CONFIGURATION_ID',
        );
      }
      
      if (configId.length > 255) {
        throw CloudProviderFactoryException(
          'Configuration ID cannot exceed 255 characters (got ${configId.length})',
          code: 'CONFIGURATION_ID_TOO_LONG',
        );
      }
      
      // Validate configurationId contains only safe characters for identification
      if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(configId)) {
        throw CloudProviderFactoryException(
          'Configuration ID must contain only alphanumeric characters, dots, underscores, and hyphens',
          code: 'INVALID_CONFIGURATION_ID_FORMAT',
        );
      }
    }
    
    // Validate provider instance is not disposed
    try {
      config.providerInstance.ensureNotDisposed();
    } catch (e) {
      throw CloudProviderFactoryException(
        'ReadyProviderConfiguration contains a disposed provider instance: $e',
        code: 'DISPOSED_PROVIDER_INSTANCE',
        originalException: e,
      );
    }
    
    // Validate display name consistency with provider instance
    if (config.displayName.isEmpty || config.displayName.trim().isEmpty) {
      throw CloudProviderFactoryException(
        'ReadyProviderConfiguration must have a non-empty display name',
        code: 'INVALID_DISPLAY_NAME',
      );
    }
    
    // Validate capabilities are appropriate for the provider type
    _validateCapabilitiesForProviderType(config.capabilities, config.type, config.displayName);
  }
  
  /// Validates registration parameters
  /// 
  /// Performs comprehensive validation of provider registration parameters
  /// to ensure they are valid and consistent before registration.
  static void _validateRegistrationParameters({
    required Type configurationType,
    required CloudProviderType providerType,
    required String displayName,
  }) {
    // Validate display name
    if (displayName.isEmpty || displayName.trim().isEmpty) {
      throw CloudProviderFactoryException(
        'Display name cannot be empty or contain only whitespace',
        code: 'INVALID_DISPLAY_NAME',
      );
    }
    
    if (displayName.length > 100) {
      throw CloudProviderFactoryException(
        'Display name cannot exceed 100 characters (got ${displayName.length})',
        code: 'DISPLAY_NAME_TOO_LONG',
      );
    }
    
    // Validate configuration type consistency with provider type
    _validateConfigurationTypeConsistency(configurationType, providerType);
    
    // Check for duplicate registrations
    if (_staticRegistry.containsKey(configurationType)) {
      final existingEntry = _staticRegistry[configurationType]!;
      throw CloudProviderFactoryException(
        'Provider already registered for configuration type $configurationType. '
        'Existing registration: ${existingEntry.displayName} (${existingEntry.providerType})',
        code: 'DUPLICATE_PROVIDER_REGISTRATION',
      );
    }
    
    // Validate provider type is supported
    if (!_isValidProviderType(providerType)) {
      throw CloudProviderFactoryException(
        'Unsupported provider type: $providerType',
        code: 'UNSUPPORTED_PROVIDER_TYPE',
      );
    }
  }
  
  /// Validates that configuration type is consistent with provider type
  static void _validateConfigurationTypeConsistency(Type configurationType, CloudProviderType providerType) {
    // Define expected configuration types for each provider type
    final expectedConfigTypes = <CloudProviderType, Set<Type>>{
      CloudProviderType.googleDrive: {OAuthProviderConfiguration},
      CloudProviderType.oneDrive: {OAuthProviderConfiguration},
      CloudProviderType.dropbox: {OAuthProviderConfiguration},
      CloudProviderType.localServer: {LocalServerProviderConfig},
      CloudProviderType.custom: {ReadyProviderConfiguration, OAuthProviderConfiguration},
    };
    
    final allowedTypes = expectedConfigTypes[providerType];
    if (allowedTypes != null && !allowedTypes.contains(configurationType)) {
      throw CloudProviderFactoryException(
        'Configuration type $configurationType is not compatible with provider type $providerType. '
        'Expected one of: ${allowedTypes.map((t) => t.toString()).join(', ')}',
        code: 'CONFIGURATION_TYPE_MISMATCH',
      );
    }
  }
  
  /// Validates if provider type is supported
  static bool _isValidProviderType(CloudProviderType providerType) {
    // All enum values are considered valid, but we could add additional checks here
    // for example, checking if implementations exist for the provider type
    return CloudProviderType.values.contains(providerType);
  }
  
  /// Validates that capabilities are appropriate for the given provider type
  static void _validateCapabilitiesForProviderType(
    Set<ProviderCapability> capabilities,
    CloudProviderType providerType,
    String displayName,
  ) {
    if (capabilities.isEmpty) {
      throw CloudProviderFactoryException(
        'Provider configuration "$displayName" must specify at least one capability',
        code: 'NO_CAPABILITIES_SPECIFIED',
      );
    }
    
    // Define expected capabilities for each provider type
    final expectedCapabilities = <CloudProviderType, Set<ProviderCapability>>{
      CloudProviderType.googleDrive: {
        ProviderCapability.upload,
        ProviderCapability.createFolders,
        ProviderCapability.delete,
        ProviderCapability.search,
        ProviderCapability.thumbnails,
        ProviderCapability.share,
        ProviderCapability.move,
        ProviderCapability.copy,
        ProviderCapability.rename,
      },
      CloudProviderType.localServer: {
        ProviderCapability.upload,
        ProviderCapability.createFolders,
        ProviderCapability.delete,
        ProviderCapability.search,
        ProviderCapability.move,
        ProviderCapability.copy,
        ProviderCapability.rename,
      },
      CloudProviderType.oneDrive: {
        ProviderCapability.upload,
        ProviderCapability.createFolders,
        ProviderCapability.delete,
        ProviderCapability.search,
        ProviderCapability.move,
        ProviderCapability.copy,
        ProviderCapability.rename,
      },
      CloudProviderType.dropbox: {
        ProviderCapability.upload,
        ProviderCapability.createFolders,
        ProviderCapability.delete,
        ProviderCapability.search,
        ProviderCapability.move,
        ProviderCapability.copy,
        ProviderCapability.rename,
      },
    };
    
    final expected = expectedCapabilities[providerType];
    if (expected != null) {
      // Check for any capabilities that are not supported by this provider type
      final unsupported = capabilities.difference(expected);
      if (unsupported.isNotEmpty) {
        throw CloudProviderFactoryException(
          'Provider "$displayName" of type $providerType does not support capabilities: '
          '${unsupported.map((c) => c.name).join(', ')}. '
          'Supported capabilities: ${expected.map((c) => c.name).join(', ')}',
          code: 'UNSUPPORTED_CAPABILITIES',
        );
      }
    }
    
    // For custom providers, we're more lenient with capabilities validation
    // since they may have custom implementations
  }
}