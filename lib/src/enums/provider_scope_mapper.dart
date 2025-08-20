import 'cloud_provider_type.dart';
import 'oauth_scope.dart';

/// Maps generic OAuth scopes to provider-specific scope strings
///
/// This class provides a centralized, extensible way to map generic
/// [OAuthScope] values to the specific scope strings required by
/// different cloud storage providers.
class ProviderScopeMapper {
  /// Private constructor to prevent instantiation
  const ProviderScopeMapper._();
  
  /// Mapping of provider types to their scope mappings
  static const Map<CloudProviderType, Map<OAuthScope, String>> _scopeMappings = {
    CloudProviderType.googleDrive: {
      OAuthScope.readFiles: 'https://www.googleapis.com/auth/drive.readonly',
      OAuthScope.writeFiles: 'https://www.googleapis.com/auth/drive.file',
      OAuthScope.createFolders: 'https://www.googleapis.com/auth/drive.file',
      OAuthScope.deleteFiles: 'https://www.googleapis.com/auth/drive.file',
      OAuthScope.shareFiles: 'https://www.googleapis.com/auth/drive.file',
      OAuthScope.readProfile: 'https://www.googleapis.com/auth/userinfo.profile',
      OAuthScope.readMetadata: 'https://www.googleapis.com/auth/drive.metadata.readonly',
      OAuthScope.moveFiles: 'https://www.googleapis.com/auth/drive.file',
      OAuthScope.copyFiles: 'https://www.googleapis.com/auth/drive.file',
      OAuthScope.renameFiles: 'https://www.googleapis.com/auth/drive.file',
    },
    
    CloudProviderType.oneDrive: {
      OAuthScope.readFiles: 'Files.Read',
      OAuthScope.writeFiles: 'Files.ReadWrite',
      OAuthScope.createFolders: 'Files.ReadWrite',
      OAuthScope.deleteFiles: 'Files.ReadWrite',
      OAuthScope.shareFiles: 'Files.ReadWrite.All',
      OAuthScope.readProfile: 'User.Read',
      OAuthScope.readMetadata: 'Files.Read',
      OAuthScope.moveFiles: 'Files.ReadWrite',
      OAuthScope.copyFiles: 'Files.ReadWrite',
      OAuthScope.renameFiles: 'Files.ReadWrite',
    },
    
    CloudProviderType.dropbox: {
      OAuthScope.readFiles: 'files.content.read',
      OAuthScope.writeFiles: 'files.content.write',
      OAuthScope.createFolders: 'files.content.write',
      OAuthScope.deleteFiles: 'files.content.write',
      OAuthScope.shareFiles: 'sharing.write',
      OAuthScope.readProfile: 'account_info.read',
      OAuthScope.readMetadata: 'files.metadata.read',
      OAuthScope.moveFiles: 'files.content.write',
      OAuthScope.copyFiles: 'files.content.write',
      OAuthScope.renameFiles: 'files.content.write',
    },
    
    // Custom and LocalServer providers don't use OAuth scopes
    CloudProviderType.custom: {},
    CloudProviderType.localServer: {},
  };
  
  /// Maps a set of generic OAuth scopes to provider-specific scope strings
  ///
  /// Returns a list of unique scope strings required by the specified provider
  /// to satisfy the requested generic scopes.
  ///
  /// Example:
  /// ```dart
  /// final scopes = ProviderScopeMapper.mapScopesToProvider(
  ///   {OAuthScope.readFiles, OAuthScope.writeFiles},
  ///   CloudProviderType.googleDrive,
  /// );
  /// // Returns: ['https://www.googleapis.com/auth/drive.file']
  /// ```
  static List<String> mapScopesToProvider(
    Set<OAuthScope> scopes,
    CloudProviderType providerType,
  ) {
    final providerMappings = _scopeMappings[providerType];
    if (providerMappings == null || providerMappings.isEmpty) {
      return [];
    }
    
    final mappedScopes = <String>{};
    for (final scope in scopes) {
      final providerScope = providerMappings[scope];
      if (providerScope != null) {
        mappedScopes.add(providerScope);
      }
    }
    
    return mappedScopes.toList();
  }
  
  /// Gets all supported scopes for a specific provider
  ///
  /// Returns the set of generic OAuth scopes that the specified provider
  /// supports through its OAuth implementation.
  static Set<OAuthScope> getSupportedScopes(CloudProviderType providerType) {
    final providerMappings = _scopeMappings[providerType];
    if (providerMappings == null) {
      return {};
    }
    return providerMappings.keys.toSet();
  }
  
  /// Checks if a provider supports a specific scope
  ///
  /// Returns true if the provider has a mapping for the specified scope.
  static bool supportsScope(CloudProviderType providerType, OAuthScope scope) {
    final providerMappings = _scopeMappings[providerType];
    return providerMappings?.containsKey(scope) ?? false;
  }
  
  /// Gets the provider-specific scope string for a generic scope
  ///
  /// Returns null if the provider doesn't support the specified scope.
  static String? getProviderScope(
    CloudProviderType providerType,
    OAuthScope scope,
  ) {
    return _scopeMappings[providerType]?[scope];
  }
  
  /// Validates that a provider supports all requested scopes
  ///
  /// Throws [UnsupportedError] if any of the requested scopes are not
  /// supported by the specified provider.
  static void validateScopes(
    Set<OAuthScope> scopes,
    CloudProviderType providerType,
  ) {
    final supportedScopes = getSupportedScopes(providerType);
    final unsupportedScopes = scopes.difference(supportedScopes);
    
    if (unsupportedScopes.isNotEmpty) {
      throw UnsupportedError(
        'Provider ${providerType.displayName} does not support scopes: '
        '${unsupportedScopes.map((s) => s.name).join(', ')}',
      );
    }
  }
}