/// Base class for all cloud storage providers with file operations
library;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/oauth_types.dart';
import '../../models/cloud_item.dart';
import '../../models/cloud_file.dart';
import '../../models/cloud_folder.dart';
import '../../models/file_operations.dart';
import '../../models/search_models.dart';

/// Abstract base class for cloud storage providers
abstract class CloudProvider {
  // Authentication (already implemented in Etapa 1)
  Future<bool> authenticate();
  Future<void> logout();
  bool get isAuthenticated;
  Future<bool> validateAuth();
  Future<bool> refreshAuth();
  Future<Map<String, dynamic>?> getUserInfo();
  
  // File Operations (NEW in Etapa 2)
  /// Lists items in the specified folder (null for root)
  Future<List<CloudItem>> listItems(String? folderId);
  
  /// Creates a new folder in the specified parent (null for root)
  Future<CloudFolder> createFolder(String name, String? parentId);
  
  /// Uploads a file with progress streaming
  Stream<UploadProgress> uploadFile(FileUpload fileUpload);
  
  /// Downloads a file and returns its bytes
  Future<Uint8List> downloadFile(String fileId);
  
  /// Deletes an item (file or folder)
  Future<void> deleteItem(String itemId);
  
  /// Moves an item to a new parent folder
  Future<void> moveItem(String itemId, String newParentId);
  
  /// Renames an item
  Future<void> renameItem(String itemId, String newName);
  
  // Search and Filters
  /// Searches for items using the provided query
  Future<List<CloudItem>> searchItems(SearchQuery query);
  
  /// Gets a specific item by its ID
  Future<CloudItem?> getItemById(String itemId);
  
  /// Gets folder hierarchy path for breadcrumb navigation
  Future<List<CloudFolder>> getFolderPath(String? folderId);
  
  // Provider Metadata
  String get providerName;
  String get providerIcon;
  Color get providerColor;
  ProviderStatus get status;
  Stream<ProviderStatus> get statusStream;
  ProviderCapabilities get capabilities;
  
  // Lifecycle
  void dispose();
}

/// Provider connection status
enum ProviderStatus {
  /// Not connected to the provider
  disconnected,
  
  /// Currently connecting/authenticating
  connecting,
  
  /// Successfully connected and authenticated
  connected,
  
  /// Connection error occurred
  error,
  
  /// Token expired, needs refresh
  tokenExpired;
  
  /// Whether the provider is in a connected state
  bool get isConnected => this == ProviderStatus.connected;
  
  /// Whether the provider is currently connecting
  bool get isConnecting => this == ProviderStatus.connecting;
  
  /// Whether there's an error state
  bool get hasError => this == ProviderStatus.error;
  
  /// Whether authentication is needed
  bool get needsAuth => this == ProviderStatus.disconnected || 
                       this == ProviderStatus.tokenExpired;
}

/// Provider capabilities - extended for Etapa 2
class ProviderCapabilities {
  final bool supportsUpload;
  final bool supportsDownload;
  final bool supportsDelete;
  final bool supportsRename;
  final bool supportsMove;
  final bool supportsCreateFolder;
  final bool supportsSearch;
  final bool supportsThumbnails;
  final bool supportsPreview;
  final bool supportsSharing;
  final bool supportsVersioning;
  final List<String> supportedFileTypes;
  final int maxFileSize;
  final int maxFilesPerUpload;
  
  const ProviderCapabilities({
    this.supportsUpload = true,
    this.supportsDownload = true,
    this.supportsDelete = true,
    this.supportsRename = true,
    this.supportsMove = true,
    this.supportsCreateFolder = true,
    this.supportsSearch = false,
    this.supportsThumbnails = true,
    this.supportsPreview = false,
    this.supportsSharing = false,
    this.supportsVersioning = false,
    this.supportedFileTypes = const [],
    this.maxFileSize = 100 * 1024 * 1024, // 100MB
    this.maxFilesPerUpload = 10,
  });
  
  /// Default capabilities for most providers
  factory ProviderCapabilities.standard() {
    return const ProviderCapabilities();
  }
  
  /// Full capabilities for advanced providers
  factory ProviderCapabilities.full() {
    return const ProviderCapabilities(
      supportsSearch: true,
      supportsThumbnails: true,
      supportsPreview: true,
      supportsSharing: true,
      supportsVersioning: true,
      maxFileSize: 1024 * 1024 * 1024, // 1GB
      maxFilesPerUpload: 50,
    );
  }
  
  /// Returns true if the provider supports all basic operations
  bool get isFullyFunctional => 
      supportsUpload && 
      supportsDownload && 
      supportsDelete && 
      supportsCreateFolder;
  
  /// Returns true if the file size is within limits
  bool canUploadFile(int fileSize) => fileSize <= maxFileSize;
  
  /// Returns true if the file type is supported
  bool supportsFileType(String mimeType) => 
      supportedFileTypes.isEmpty || supportedFileTypes.contains(mimeType);
}

/// Base implementation for cloud providers
abstract class BaseCloudProvider extends CloudProvider {
  ProviderStatus _status = ProviderStatus.disconnected;
  final StreamController<ProviderStatus> _statusController = 
      StreamController<ProviderStatus>.broadcast();
  
  @override
  ProviderStatus get status => _status;
  
  @override
  Stream<ProviderStatus> get statusStream => _statusController.stream;
  
  /// Update provider status
  @protected
  void updateStatus(ProviderStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }
  
  @override
  bool get isAuthenticated => _status == ProviderStatus.connected;
  
  @override
  Future<Map<String, dynamic>?> getUserInfo() async {
    if (!isAuthenticated) return null;
    return await fetchUserInfo();
  }
  
  @override
  Future<bool> validateAuth() async {
    if (!isAuthenticated) return false;
    
    try {
      updateStatus(ProviderStatus.connecting);
      final isValid = await performAuthValidation();
      updateStatus(isValid ? ProviderStatus.connected : ProviderStatus.error);
      return isValid;
    } catch (e) {
      updateStatus(ProviderStatus.error);
      return false;
    }
  }
  
  @override
  Future<bool> refreshAuth() async {
    try {
      updateStatus(ProviderStatus.connecting);
      final success = await performAuthRefresh();
      updateStatus(success ? ProviderStatus.connected : ProviderStatus.error);
      return success;
    } catch (e) {
      updateStatus(ProviderStatus.error);
      return false;
    }
  }
  
  @override
  void dispose() {
    _statusController.close();
  }
  
  /// Subclasses should implement these methods for authentication
  @protected
  Future<Map<String, dynamic>?> fetchUserInfo();
  
  @protected
  Future<bool> performAuthValidation();
  
  @protected
  Future<bool> performAuthRefresh();
}