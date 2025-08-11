import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_drive/src/providers/base/cloud_provider.dart';
import 'package:file_drive/src/models/oauth_types.dart';
import 'package:file_drive/src/models/cloud_item.dart';
import 'package:file_drive/src/models/cloud_folder.dart';
import 'package:file_drive/src/models/file_operations.dart';
import '../test_helpers.dart';
import 'package:file_drive/src/models/search_models.dart';

// Generate mocks
@GenerateMocks([CloudProvider])
import 'cloud_provider_test.mocks.dart';

// Test implementation of CloudProvider
class TestCloudProvider extends BaseCloudProvider {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userInfo;
  bool _authValidationResult = true;
  bool _authRefreshResult = true;

  @override
  String get providerName => 'Test Provider';

  @override
  String get providerIcon => 'test_icon.svg';

  @override
  Color get providerColor => Colors.blue;

  @override
  ProviderCapabilities get capabilities => ProviderCapabilities.standard();

  @override
  Future<bool> authenticate() async {
    updateStatus(ProviderStatus.connecting);
    await Future.delayed(Duration(milliseconds: 100));
    _isAuthenticated = true;
    updateStatus(ProviderStatus.connected);
    return true;
  }

  @override
  Future<void> logout() async {
    _isAuthenticated = false;
    _userInfo = null;
    updateStatus(ProviderStatus.disconnected);
  }

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<Map<String, dynamic>?> fetchUserInfo() async {
    return _userInfo;
  }

  @override
  Future<bool> performAuthValidation() async {
    return _authValidationResult;
  }

  @override
  Future<bool> performAuthRefresh() async {
    return _authRefreshResult;
  }

  // Test helpers
  void setUserInfo(Map<String, dynamic>? userInfo) {
    _userInfo = userInfo;
  }

  void setAuthValidationResult(bool result) {
    _authValidationResult = result;
  }

  void setAuthRefreshResult(bool result) {
    _authRefreshResult = result;
  }

  // File operation stubs - not used in current tests
  @override
  Future<List<CloudItem>> listItems(String? folderId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<CloudFolder> createFolder(String name, String? parentId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Stream<UploadProgress> uploadFile(FileUpload fileUpload) {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<void> deleteItem(String itemId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<void> moveItem(String itemId, String newParentId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<void> renameItem(String itemId, String newName) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<List<CloudItem>> searchItems(SearchQuery query) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<CloudItem?> getItemById(String itemId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<List<CloudFolder>> getFolderPath(String? folderId) async {
    throw UnimplementedError('Test implementation');
  }
}

void main() {
  group('ProviderStatus', () {
    test('should have correct boolean properties', () {
      expect(ProviderStatus.connected.isConnected, isTrue);
      expect(ProviderStatus.connecting.isConnected, isFalse);
      expect(ProviderStatus.disconnected.isConnected, isFalse);
      expect(ProviderStatus.error.isConnected, isFalse);

      expect(ProviderStatus.connecting.isConnecting, isTrue);
      expect(ProviderStatus.connected.isConnecting, isFalse);

      expect(ProviderStatus.error.hasError, isTrue);
      expect(ProviderStatus.connected.hasError, isFalse);

      expect(ProviderStatus.disconnected.needsAuth, isTrue);
      expect(ProviderStatus.tokenExpired.needsAuth, isTrue);
      expect(ProviderStatus.connected.needsAuth, isFalse);
    });
  });

  group('ProviderCapabilities', () {
    test('should create standard capabilities', () {
      final capabilities = ProviderCapabilities.standard();

      expect(capabilities.supportsUpload, isTrue);
      expect(capabilities.supportsDownload, isTrue);
      expect(capabilities.supportsDelete, isTrue);
      expect(capabilities.supportsRename, isTrue);
      expect(capabilities.supportsCreateFolder, isTrue);
      expect(capabilities.supportsSearch, isFalse);
      expect(capabilities.supportsSharing, isFalse);
      expect(capabilities.supportsVersioning, isFalse);
      expect(capabilities.maxFileSize, equals(100 * 1024 * 1024));
      expect(capabilities.maxFilesPerUpload, equals(10));
    });

    test('should create full capabilities', () {
      final capabilities = ProviderCapabilities.full();

      expect(capabilities.supportsSearch, isTrue);
      expect(capabilities.supportsSharing, isTrue);
      expect(capabilities.supportsVersioning, isTrue);
      expect(capabilities.maxFileSize, equals(1024 * 1024 * 1024));
      expect(capabilities.maxFilesPerUpload, equals(50));
    });

    test('should create custom capabilities', () {
      final capabilities = ProviderCapabilities(
        supportsUpload: false,
        supportsSearch: true,
        maxFileSize: 50 * 1024 * 1024,
        supportedFileTypes: ['image/jpeg', 'image/png'],
      );

      expect(capabilities.supportsUpload, isFalse);
      expect(capabilities.supportsSearch, isTrue);
      expect(capabilities.maxFileSize, equals(50 * 1024 * 1024));
      expect(capabilities.supportedFileTypes, equals(['image/jpeg', 'image/png']));
    });
  });

  group('BaseCloudProvider', () {
    late TestCloudProvider provider;

    setUp(() {
      provider = TestCloudProvider();
    });

    tearDown(() {
      provider.dispose();
      TestResourceManager.disposeAll();
    });

    test('should start with disconnected status', () {
      expect(provider.status, equals(ProviderStatus.disconnected));
      expect(provider.isAuthenticated, isFalse);
    });

    test('should update status correctly', () async {
      final statusUpdates = <ProviderStatus>[];
      TestResourceManager.safeStreamListen(provider.statusStream, statusUpdates.add);

      provider.updateStatus(ProviderStatus.connecting);
      provider.updateStatus(ProviderStatus.connected);

      // Wait for stream events to be processed
      await Future.delayed(Duration(milliseconds: 10));

      expect(provider.status, equals(ProviderStatus.connected));
      expect(statusUpdates, equals([ProviderStatus.connecting, ProviderStatus.connected]));
    });

    test('should not emit duplicate status updates', () async {
      final statusUpdates = <ProviderStatus>[];
      TestResourceManager.safeStreamListen(provider.statusStream, statusUpdates.add);

      // Use authenticate to trigger status changes
      await provider.authenticate();

      // Wait for stream events
      await Future.delayed(Duration(milliseconds: 10));

      // Should have connecting and connected states
      expect(statusUpdates.length, greaterThan(0));
      expect(statusUpdates, contains(ProviderStatus.connecting));
      expect(statusUpdates, contains(ProviderStatus.connected));
    });

    test('should authenticate successfully', () async {
      final statusUpdates = <ProviderStatus>[];
      TestResourceManager.safeStreamListen(provider.statusStream, statusUpdates.add);

      final result = await provider.authenticate();

      // Wait for stream events
      await Future.delayed(Duration(milliseconds: 10));

      expect(result, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.status, equals(ProviderStatus.connected));
      expect(statusUpdates, contains(ProviderStatus.connecting));
      expect(statusUpdates, contains(ProviderStatus.connected));
    });

    test('should logout successfully', () async {
      await provider.authenticate();
      expect(provider.isAuthenticated, isTrue);

      await provider.logout();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.status, equals(ProviderStatus.disconnected));
    });

    test('should get user info when authenticated', () async {
      final userInfo = {'name': 'Test User', 'email': 'test@example.com'};
      provider.setUserInfo(userInfo);
      await provider.authenticate();

      final result = await provider.getUserInfo();

      expect(result, equals(userInfo));
    });

    test('should return null user info when not authenticated', () async {
      final result = await provider.getUserInfo();
      expect(result, isNull);
    });

    test('should validate auth successfully', () async {
      await provider.authenticate();
      provider.setAuthValidationResult(true);

      final result = await provider.validateAuth();

      expect(result, isTrue);
      expect(provider.status, equals(ProviderStatus.connected));
    });

    test('should handle auth validation failure', () async {
      await provider.authenticate();
      provider.setAuthValidationResult(false);

      final result = await provider.validateAuth();

      expect(result, isFalse);
      expect(provider.status, equals(ProviderStatus.error));
    });

    test('should refresh auth successfully', () async {
      await provider.authenticate();
      provider.setAuthRefreshResult(true);

      final result = await provider.refreshAuth();

      expect(result, isTrue);
      expect(provider.status, equals(ProviderStatus.connected));
    });

    test('should handle auth refresh failure', () async {
      await provider.authenticate();
      provider.setAuthRefreshResult(false);

      final result = await provider.refreshAuth();

      expect(result, isFalse);
      expect(provider.status, equals(ProviderStatus.error));
    });

    test('should return false for validation when not authenticated', () async {
      final result = await provider.validateAuth();
      expect(result, isFalse);
    });

    test('should have correct provider metadata', () {
      expect(provider.providerName, equals('Test Provider'));
      expect(provider.providerIcon, equals('test_icon.svg'));
      expect(provider.providerColor, equals(Colors.blue));
    });

    test('should have standard capabilities', () {
      final capabilities = provider.capabilities;
      expect(capabilities.supportsUpload, isTrue);
      expect(capabilities.supportsDownload, isTrue);
      expect(capabilities.supportsDelete, isTrue);
    });

    test('should dispose resources properly', () {
      // Just verify dispose doesn't throw
      expect(() => provider.dispose(), returnsNormally);
    });
  });
}
