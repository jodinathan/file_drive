/// Base class for all cloud storage providers
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/oauth_types.dart';

/// Abstract base class for cloud storage providers
abstract class CloudProvider {
  /// Authenticate with the provider
  Future<bool> authenticate();
  
  /// Logout from the provider
  Future<void> logout();
  
  /// Check if currently authenticated
  bool get isAuthenticated;
  
  /// Get the provider name
  String get providerName;
  
  /// Get the provider icon path or widget
  String get providerIcon;
  
  /// Get the provider brand color
  Color get providerColor;
  
  /// Get current connection status
  ProviderStatus get status;
  
  /// Stream of status changes
  Stream<ProviderStatus> get statusStream;
  
  /// Get user information (if available)
  Future<Map<String, dynamic>?> getUserInfo();
  
  /// Validate current authentication
  Future<bool> validateAuth();
  
  /// Refresh authentication if needed
  Future<bool> refreshAuth();
  
  /// Get provider capabilities
  ProviderCapabilities get capabilities;
  
  /// Dispose resources
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

/// Provider capabilities
class ProviderCapabilities {
  final bool supportsUpload;
  final bool supportsDownload;
  final bool supportsDelete;
  final bool supportsRename;
  final bool supportsCreateFolder;
  final bool supportsSearch;
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
    this.supportsCreateFolder = true,
    this.supportsSearch = false,
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
      supportsSharing: true,
      supportsVersioning: true,
      maxFileSize: 1024 * 1024 * 1024, // 1GB
      maxFilesPerUpload: 50,
    );
  }
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
  
  /// Subclasses should implement these methods
  @protected
  Future<Map<String, dynamic>?> fetchUserInfo();
  
  @protected
  Future<bool> performAuthValidation();
  
  @protected
  Future<bool> performAuthRefresh();
}
