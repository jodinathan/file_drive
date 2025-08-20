import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import '../../lib/src/models/provider_configuration.dart';
import '../../lib/src/enums/cloud_provider_type.dart';
import '../../lib/src/enums/oauth_scope.dart';
import '../../lib/src/models/provider_capabilities.dart';

void main() {
  group('ProviderConfiguration', () {
    test('should create Google Drive configuration using factory method', () {
      final config = ProviderConfigurationFactories.googleDrive(
        generateAuthUrl: (state) => 'https://example.com/auth?state=$state',
        generateTokenUrl: (state) => 'https://example.com/token?state=$state',
        redirectScheme: 'myapp://oauth',
      );

      expect(config.type, CloudProviderType.googleDrive);
      expect(config.displayName, 'Google Drive');
      expect(config.redirectScheme, 'myapp://oauth');
      expect(config.requiredScopes.contains(OAuthScope.readFiles), true);
      expect(config.capabilities.canUpload, true);
      expect(config.capabilities.canSearch, true);
      expect(config.requiresAccountManagement, true);
    });

    test('should create custom provider configuration', () {
      final customCapabilities = ProviderCapabilities(
        canUpload: true,
        canCreateFolders: false,
        canSearch: true,
      );

      final config = ProviderConfigurationFactories.custom(
        displayName: 'My Custom Provider',
        generateAuthUrl: (state) => 'https://custom.com/auth?state=$state',
        generateTokenUrl: (state) => 'https://custom.com/token?state=$state',
        redirectScheme: 'custom://oauth',
        requiredScopes: {OAuthScope.readFiles},
        capabilities: customCapabilities,
        logoWidget: const Icon(Icons.cloud),
      );

      expect(config.type, CloudProviderType.custom);
      expect(config.displayName, 'My Custom Provider');
      expect(config.logoWidget, isA<Icon>());
      expect(config.capabilities.canCreateFolders, false);
      expect(config.capabilities.canSearch, true);
    });

    test('should create local server configuration', () {
      final config = ProviderConfigurationFactories.localServer(
        generateAuthUrl: (state) => 'http://localhost:8080/auth?state=$state',
        generateTokenUrl: (state) => 'http://localhost:8080/token?state=$state',
        redirectScheme: 'localapp://oauth',
      );

      expect(config.type, CloudProviderType.localServer);
      expect(config.displayName, 'Local Development Server');
      expect(config.requiresAccountManagement, false);
      expect(config.capabilities.canSearch, false); // Default for local server
    });

    test('should validate configuration correctly', () {
      final config = ProviderConfiguration(
        type: CloudProviderType.googleDrive,
        displayName: 'Test Provider',
        logoAssetPath: 'assets/test.svg',
        generateAuthUrl: (state) => 'https://example.com/auth?state=$state',
        generateTokenUrl: (state) => 'https://example.com/token?state=$state',
        redirectScheme: 'test://oauth',
        requiredScopes: {OAuthScope.readFiles},
        capabilities: const ProviderCapabilities(),
      );

      expect(() => config.validate(), returnsNormally);
    });

    test('should fail validation for invalid redirect scheme', () {
      final config = ProviderConfiguration(
        type: CloudProviderType.googleDrive,
        displayName: 'Test Provider',
        logoAssetPath: 'assets/test.svg',
        generateAuthUrl: (state) => 'https://example.com/auth?state=$state',
        generateTokenUrl: (state) => 'https://example.com/token?state=$state',
        redirectScheme: 'invalid-scheme', // Missing ://
        requiredScopes: {OAuthScope.readFiles},
        capabilities: const ProviderCapabilities(),
      );

      expect(() => config.validate(), throwsArgumentError);
    });

    test('should fail validation for empty display name', () {
      final config = ProviderConfiguration(
        type: CloudProviderType.googleDrive,
        displayName: '', // Empty display name
        logoAssetPath: 'assets/test.svg',
        generateAuthUrl: (state) => 'https://example.com/auth?state=$state',
        generateTokenUrl: (state) => 'https://example.com/token?state=$state',
        redirectScheme: 'test://oauth',
        requiredScopes: {OAuthScope.readFiles},
        capabilities: const ProviderCapabilities(),
      );

      expect(() => config.validate(), throwsArgumentError);
    });

    test('should serialize to JSON correctly', () {
      final config = ProviderConfiguration(
        type: CloudProviderType.googleDrive,
        displayName: 'Test Provider',
        logoAssetPath: 'assets/test.svg',
        generateAuthUrl: (state) => 'https://example.com/auth?state=$state',
        generateTokenUrl: (state) => 'https://example.com/token?state=$state',
        redirectScheme: 'test://oauth',
        requiredScopes: {OAuthScope.readFiles, OAuthScope.writeFiles},
        capabilities: const ProviderCapabilities(canUpload: true),
        configurationId: 'test-config-1',
      );

      final json = config.toJson();

      expect(json['type'], 'googleDrive');
      expect(json['displayName'], 'Test Provider');
      expect(json['logoAssetPath'], 'assets/test.svg');
      expect(json['redirectScheme'], 'test://oauth');
      expect(json['requiredScopes'], containsAll(['readFiles', 'writeFiles']));
      expect(json['configurationId'], 'test-config-1');
      expect(json['capabilities'], isA<Map<String, dynamic>>());
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'type': 'googleDrive',
        'displayName': 'Test Provider',
        'logoAssetPath': 'assets/test.svg',
        'redirectScheme': 'test://oauth',
        'requiredScopes': ['readFiles', 'writeFiles'],
        'capabilities': {
          'canUpload': true,
          'canCreateFolders': true,
          'canDelete': false,
          'maxPageSize': 50,
        },
        'requiresAccountManagement': true,
        'configurationId': 'test-config-1',
        'enabled': true,
        'additionalConfig': {},
      };

      final config = ProviderConfiguration.fromJson(
        json,
        generateAuthUrl: (state) => 'https://example.com/auth?state=$state',
        generateTokenUrl: (state) => 'https://example.com/token?state=$state',
      );

      expect(config.type, CloudProviderType.googleDrive);
      expect(config.displayName, 'Test Provider');
      expect(config.logoAssetPath, 'assets/test.svg');
      expect(config.redirectScheme, 'test://oauth');
      expect(config.requiredScopes.length, 2);
      expect(config.requiredScopes.contains(OAuthScope.readFiles), true);
      expect(config.requiredScopes.contains(OAuthScope.writeFiles), true);
      expect(config.configurationId, 'test-config-1');
      expect(config.capabilities.canUpload, true);
      expect(config.capabilities.canDelete, false);
    });

    test('should create copy with updated values', () {
      final original = ProviderConfiguration(
        type: CloudProviderType.googleDrive,
        displayName: 'Original Provider',
        logoAssetPath: 'assets/original.svg',
        generateAuthUrl: (state) => 'https://example.com/auth?state=$state',
        generateTokenUrl: (state) => 'https://example.com/token?state=$state',
        redirectScheme: 'original://oauth',
        requiredScopes: {OAuthScope.readFiles},
        capabilities: const ProviderCapabilities(),
        enabled: true,
      );

      final updated = original.copyWith(
        displayName: 'Updated Provider',
        enabled: false,
      );

      expect(updated.displayName, 'Updated Provider');
      expect(updated.enabled, false);
      expect(updated.type, original.type); // Should remain unchanged
      expect(updated.logoAssetPath, original.logoAssetPath); // Should remain unchanged
    });

    test('should handle equality comparison correctly', () {
      // Use the same function references for both configs
      String authUrlGenerator(String state) => 'https://example.com/auth?state=$state';
      String tokenUrlGenerator(String state) => 'https://example.com/token?state=$state';
      
      final config1 = ProviderConfiguration(
        type: CloudProviderType.googleDrive,
        displayName: 'Test Provider',
        logoAssetPath: 'assets/test.svg',
        generateAuthUrl: authUrlGenerator,
        generateTokenUrl: tokenUrlGenerator,
        redirectScheme: 'test://oauth',
        requiredScopes: {OAuthScope.readFiles},
        capabilities: const ProviderCapabilities(),
      );

      final config2 = ProviderConfiguration(
        type: CloudProviderType.googleDrive,
        displayName: 'Test Provider',
        logoAssetPath: 'assets/test.svg',
        generateAuthUrl: authUrlGenerator, // Same function reference
        generateTokenUrl: tokenUrlGenerator, // Same function reference
        redirectScheme: 'test://oauth',
        requiredScopes: {OAuthScope.readFiles},
        capabilities: const ProviderCapabilities(),
      );

      final config3 = config1.copyWith(displayName: 'Different Provider');

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1.hashCode, isNot(equals(config3.hashCode)));
    });
  });
}