import '../models/file_entry.dart';
import '../enums/cloud_provider_type.dart';
import '../enums/oauth_scope.dart';
import '../models/provider_capabilities.dart';
import '../models/cloud_account.dart';
import '../models/base_provider_configuration.dart';

/// Progress information for upload operations
class UploadProgress {
  /// Number of bytes uploaded
  final int uploaded;
  
  /// Total size in bytes
  final int total;
  
  /// Name of the file being uploaded
  final String fileName;
  
  /// Upload speed in bytes per second
  final double speed;
  
  /// Estimated time remaining in seconds
  final Duration? estimatedTimeRemaining;
  
  /// Current status of the upload
  final UploadStatus status;
  
  /// Error message if upload failed
  final String? error;
  
  /// Upload start time
  final DateTime startTime;
  
  /// Last update time
  final DateTime lastUpdate;
  
  /// Progress percentage (0.0 to 1.0)
  double get progress => total > 0 ? uploaded / total : 0.0;
  
  /// Whether the upload is complete
  bool get isComplete => status == UploadStatus.completed;
  
  /// Whether the upload has failed
  bool get hasFailed => status == UploadStatus.error;
  
  /// Whether the upload is in progress
  bool get isUploading => status == UploadStatus.uploading;
  
  /// Whether the upload is paused
  bool get isPaused => status == UploadStatus.paused;
  
  /// Whether the upload was cancelled
  bool get isCancelled => status == UploadStatus.cancelled;
  
  /// Duration since upload started
  Duration get elapsedTime => lastUpdate.difference(startTime);
  
  /// Average upload speed since start
  double get averageSpeed {
    final elapsed = elapsedTime.inMilliseconds;
    return elapsed > 0 ? uploaded / (elapsed / 1000) : 0.0;
  }

  UploadProgress({
    required this.uploaded,
    required this.total,
    required this.fileName,
    this.speed = 0.0,
    this.estimatedTimeRemaining,
    this.status = UploadStatus.waiting,
    this.error,
    DateTime? startTime,
    DateTime? lastUpdate,
  }) : startTime = startTime ?? DateTime.now(),
       lastUpdate = lastUpdate ?? DateTime.now();

  /// Creates a new progress instance with updated values
  UploadProgress copyWith({
    int? uploaded,
    int? total,
    String? fileName,
    double? speed,
    Duration? estimatedTimeRemaining,
    UploadStatus? status,
    String? error,
    DateTime? startTime,
    DateTime? lastUpdate,
  }) {
    return UploadProgress(
      uploaded: uploaded ?? this.uploaded,
      total: total ?? this.total,
      fileName: fileName ?? this.fileName,
      speed: speed ?? this.speed,
      estimatedTimeRemaining: estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      status: status ?? this.status,
      error: error ?? this.error,
      startTime: startTime ?? this.startTime,
      lastUpdate: lastUpdate ?? DateTime.now(),
    );
  }

  /// Creates a progress instance for a starting upload
  factory UploadProgress.starting({
    required String fileName,
    required int total,
  }) {
    return UploadProgress(
      uploaded: 0,
      total: total,
      fileName: fileName,
      status: UploadStatus.waiting,
    );
  }

  /// Creates a progress instance for a completed upload
  factory UploadProgress.completed({
    required String fileName,
    required int total,
    required DateTime startTime,
  }) {
    return UploadProgress(
      uploaded: total,
      total: total,
      fileName: fileName,
      status: UploadStatus.completed,
      startTime: startTime,
    );
  }

  /// Creates a progress instance for a failed upload
  factory UploadProgress.error({
    required String fileName,
    required int total,
    required String error,
    required DateTime startTime,
    int uploaded = 0,
  }) {
    return UploadProgress(
      uploaded: uploaded,
      total: total,
      fileName: fileName,
      status: UploadStatus.error,
      error: error,
      startTime: startTime,
    );
  }

  /// Calculates estimated time remaining based on current speed
  Duration? calculateEstimatedTimeRemaining() {
    if (speed <= 0 || uploaded >= total) return null;
    
    final remainingBytes = total - uploaded;
    final estimatedSeconds = remainingBytes / speed;
    
    return Duration(seconds: estimatedSeconds.round());
  }

  /// Updates progress with new uploaded bytes and calculates speed
  UploadProgress updateProgress(int newUploaded) {
    final now = DateTime.now();
    final timeDiff = now.difference(lastUpdate).inMilliseconds / 1000;
    final bytesDiff = newUploaded - uploaded;
    
    final newSpeed = timeDiff > 0 ? bytesDiff / timeDiff : speed;
    final estimatedTime = newSpeed > 0 ? 
        Duration(seconds: ((total - newUploaded) / newSpeed).round()) : null;

    return copyWith(
      uploaded: newUploaded,
      speed: newSpeed,
      estimatedTimeRemaining: estimatedTime,
      lastUpdate: now,
      status: newUploaded >= total ? UploadStatus.completed : UploadStatus.uploading,
    );
  }

  @override
  String toString() => 'UploadProgress($fileName: ${(progress * 100).toStringAsFixed(1)}%, '
                      'Speed: ${_formatBytes(speed)}/s, Status: $status)';

  static String _formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Status of an upload operation
enum UploadStatus {
  /// Upload is waiting to start
  waiting,
  
  /// Upload is currently in progress
  uploading,
  
  /// Upload has been paused by user
  paused,
  
  /// Upload completed successfully
  completed,
  
  /// Upload failed with an error
  error,
  
  /// Upload was cancelled by user
  cancelled,
  
  /// Upload is being retried after failure
  retrying;

  /// Whether the upload is in a terminal state (completed, error, cancelled)
  bool get isTerminal => this == completed || this == error || this == cancelled;
  
  /// Whether the upload can be resumed
  bool get canResume => this == paused || this == error;
  
  /// Whether the upload can be cancelled
  bool get canCancel => this == waiting || this == uploading || this == paused || this == retrying;
  
  /// Whether the upload can be retried
  bool get canRetry => this == error || this == cancelled;
}

/// Result of an upload operation
class UploadResult {
  /// The uploaded file entry
  final FileEntry? fileEntry;
  
  /// Error message if upload failed
  final String? error;
  
  /// Whether the upload was successful
  bool get isSuccess => error == null && fileEntry != null;

  const UploadResult({
    this.fileEntry,
    this.error,
  });

  /// Creates a successful upload result
  factory UploadResult.success(FileEntry fileEntry) {
    return UploadResult(fileEntry: fileEntry);
  }

  /// Creates a failed upload result
  factory UploadResult.error(String error) {
    return UploadResult(error: error);
  }
}

/// Information about a user profile
class UserProfile {
  /// User's display name
  final String name;
  
  /// User's email address
  final String email;
  
  /// URL to user's profile photo
  final String? photoUrl;
  
  /// User's unique ID from the provider
  final String id;
  
  /// Additional profile data from the provider
  final Map<String, dynamic> metadata;

  const UserProfile({
    required this.name,
    required this.email,
    this.photoUrl,
    required this.id,
    this.metadata = const {},
  });
}

/// Exception thrown by cloud providers
class CloudProviderException implements Exception {
  /// Error message
  final String message;
  
  /// Error code (if available)
  final String? code;
  
  /// HTTP status code (if applicable)
  final int? statusCode;
  
  /// Original exception (if any)
  final dynamic originalException;

  const CloudProviderException(
    this.message, {
    this.code,
    this.statusCode,
    this.originalException,
  });

  @override
  String toString() => 'CloudProviderException: $message';
}


/// Abstract base class for cloud storage providers
/// 
/// This class provides a unified interface for cloud storage operations with
/// constructor-based configuration and comprehensive resource management.
/// 
/// ## Resource Management Guidelines
/// 
/// All concrete implementations must follow these resource management patterns:
/// 
/// ### HTTP Client Management
/// - Use a single HTTP client instance per provider instance
/// - Close HTTP client in dispose() method
/// - Handle connection pooling appropriately
/// - Implement proper timeout handling (recommended: 30s for uploads, 10s for other operations)
/// 
/// ### Memory Management
/// - Use streaming for large file operations to avoid memory bloat
/// - Limit concurrent operations to prevent resource exhaustion
/// - Clean up temporary resources in all code paths
/// - Implement backpressure for upload/download streams
/// 
/// ### Error Handling & Cleanup
/// - Always clean up resources in finally blocks or using try-with-resources pattern
/// - Handle network timeouts gracefully with proper user messaging
/// - Cancel ongoing operations when dispose() is called
/// - Log resource cleanup failures but don't throw from dispose()
/// 
/// ### Authentication State
/// - Validate authentication before each API call
/// - Handle token expiration with automatic refresh where possible
/// - Clear sensitive data (tokens) during disposal
/// - Support account switching without resource leaks
/// 
/// ### Platform Compatibility
/// - Ensure Flutter Web compatibility with Uri-based networking
/// - Handle CORS requirements for web environments
/// - Use platform-appropriate networking patterns
/// 
/// ## Constructor-Based Configuration
/// 
/// This class uses constructor injection for configuration instead of initialize() patterns.
/// All configuration must be provided during construction and validated immediately.
/// 
/// ## Disposal Pattern
/// 
/// Implementations must properly override dispose() to clean up resources:
/// ```dart
/// @override
/// void dispose() {
///   _httpClient?.close();
///   _activeStreams.forEach((stream) => stream.cancel());
///   super.dispose(); // Always call super.dispose()
/// }
/// ```
abstract class BaseCloudProvider {
  
  /// Configuration for this provider
  final BaseProviderConfiguration configuration;
  
  /// Current account being used by this provider
  CloudAccount? _currentAccount;
  
  /// Whether this provider has been disposed
  bool _isDisposed = false;
  
  /// Creates a new provider with the given configuration
  BaseCloudProvider({
    required this.configuration,
    CloudAccount? account,
  }) : _currentAccount = account {
    configuration.validate();
  }
  
  /// Cloud provider type for this provider
  CloudProviderType get providerType => configuration.type;
  
  /// Display name for this provider
  String get displayName => configuration.displayName;
  
  /// Path to the provider's logo asset (can be null for icon-only providers)
  String? get logoAssetPath => null;
  
  /// Whether this provider requires account management
  bool get requiresAccountManagement => false;
  
  /// Gets the capabilities of this provider
  ProviderCapabilities getCapabilities();
  
  /// Gets the OAuth scopes required by this provider
  Set<OAuthScope> get requiredScopes;
  
  /// Sets the current account for this provider
  /// 
  /// This replaces the initialize pattern for account management.
  /// The account contains authentication tokens and user information
  /// needed for provider operations.
  /// 
  /// [account] - The account to set (null to clear authentication)
  /// 
  /// Authentication Patterns:
  /// - OAuth providers: account should contain access and refresh tokens
  /// - API key providers: account should contain the API key in appropriate field
  /// - Anonymous providers: account can be null if no authentication required
  /// 
  /// Throws [CloudProviderException] if provider is disposed
  /// Throws [ArgumentError] if account is required but invalid for this provider type
  void setCurrentAccount(CloudAccount? account) {
    ensureNotDisposed();
    
    // Validate account if this provider requires account management
    if (requiresAccountManagement && account != null) {
      _validateAccountForProvider(account);
    }
    
    _currentAccount = account;
  }
  
  /// Gets the current account being used by this provider
  CloudAccount? get currentAccount => _currentAccount;
  
  /// Whether this provider is currently authenticated
  /// 
  /// This is a convenience method that checks if authentication is available
  /// without throwing exceptions (unlike ensureAuthenticated).
  /// 
  /// Returns true if:
  /// - Provider doesn't require authentication (anonymous), OR
  /// - Provider has a valid account with non-expired tokens
  bool get isAuthenticated {
    try {
      ensureAuthenticated();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Whether the current account needs token refresh
  /// 
  /// Returns true if we have an account but tokens are expired or will expire soon
  bool get needsTokenRefresh {
    if (_currentAccount == null || !requiresAccountManagement) {
      return false;
    }
    
    return _currentAccount!.needsReauth;
  }
  
  /// Clears the current authentication
  /// 
  /// This removes the current account and clears any cached authentication state.
  /// Call this when logging out or switching accounts.
  /// 
  /// Throws [CloudProviderException] if provider is disposed
  void clearAuthentication() {
    ensureNotDisposed();
    _currentAccount = null;
  }
  
  /// Lists files and folders in the specified folder
  /// 
  /// [folderId] - ID of the folder to list (null for root)
  /// [pageToken] - Token for pagination (null for first page)
  /// [pageSize] - Number of items per page (must be > 0 and <= capabilities.maxPageSize)
  /// 
  /// Resource Management:
  /// - Implementations must ensure HTTP clients are properly managed
  /// - Network connections should be closed after use
  /// - Pagination state should be cleaned up when no longer needed
  /// 
  /// Throws [CloudProviderException] if provider is disposed, not configured, or not authenticated
  /// Throws [ArgumentError] if pageSize is invalid for this provider's capabilities
  Future<FileListPage> listFolder({
    String? folderId,
    String? pageToken,
    int pageSize = 50,
  });
  
  /// Creates a new folder
  /// 
  /// [name] - Name of the folder to create (must not be empty)
  /// [parentId] - ID of the parent folder (null for root)
  /// 
  /// Resource Management:
  /// - HTTP connections should be closed after folder creation
  /// - Network timeouts should be handled gracefully
  /// - Implementation should support operation cancellation
  /// - Memory usage should be minimal for metadata operations
  /// 
  /// Throws [CloudProviderException] if provider is disposed, not configured, or not authenticated
  /// Throws [ArgumentError] if name is empty or invalid
  /// Throws [CloudProviderException] if provider doesn't support folder creation
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  });
  
  /// Deletes a file or folder
  /// 
  /// [entryId] - ID of the file or folder to delete (must not be empty)
  /// [permanent] - Whether to delete permanently (bypass trash)
  /// 
  /// Resource Management:
  /// - HTTP connections should be closed after deletion operation
  /// - Network timeouts should be handled gracefully
  /// - Operation should be cancellable to prevent partial deletions
  /// - Memory usage should be minimal for deletion metadata
  /// - Cleanup should handle both successful and failed deletion attempts
  /// 
  /// Throws [CloudProviderException] if provider is disposed, not configured, or not authenticated
  /// Throws [ArgumentError] if entryId is empty or invalid
  /// Throws [CloudProviderException] if provider doesn't support deletion
  Future<void> deleteEntry({
    required String entryId,
    bool permanent = false,
  });
  
  /// Downloads a file
  /// 
  /// [fileId] - ID of the file to download (must not be empty)
  /// Returns a stream of bytes
  /// 
  /// Flutter Web Compatibility:
  /// - Implementations must use Uri objects for HTTP requests, not String URLs
  /// - HTTP clients should be compatible with browser networking constraints
  /// - Stream handling must work with both Dart VM and dart2js compilation
  /// - CORS headers may need to be handled for cross-origin requests
  /// 
  /// Resource Management:
  /// - HTTP connections should be properly closed after download
  /// - Streaming data should be chunked appropriately for memory efficiency
  /// - Network timeouts should be handled gracefully
  /// 
  /// Throws [CloudProviderException] if provider is disposed, not configured, or not authenticated
  /// Throws [ArgumentError] if fileId is empty or invalid
  /// Throws [CloudProviderException] if file doesn't exist or can't be downloaded
  Stream<List<int>> downloadFile({
    required String fileId,
  });
  
  /// Uploads a file
  /// 
  /// [fileName] - Name of the file (must not be empty)
  /// [fileBytes] - Stream of file bytes (must not be empty)
  /// [parentId] - ID of the parent folder (null for root)
  /// [mimeType] - MIME type of the file (auto-detected if null)
  /// Returns a stream of upload progress
  /// 
  /// Flutter Web Compatibility:
  /// - Implementations must use Uri objects for HTTP requests, not String URLs
  /// - HTTP clients should support multipart uploads for browser compatibility
  /// - Stream-based uploads must work with both Dart VM and dart2js
  /// - File size limits may apply in browser environments
  /// - Progress reporting should handle browser upload limitations
  /// 
  /// Resource Management:
  /// - HTTP connections should remain open for upload duration
  /// - Upload streams should be cancellable and resumable where supported
  /// - Memory usage should be controlled for large file uploads
  /// - Network errors should trigger proper cleanup
  /// 
  /// Throws [CloudProviderException] if provider is disposed, not configured, or not authenticated
  /// Throws [ArgumentError] if fileName is empty or fileBytes is invalid
  /// Throws [CloudProviderException] if provider doesn't support uploads
  Stream<UploadProgress> uploadFile({
    required String fileName,
    required Stream<List<int>> fileBytes,
    String? parentId,
    String? mimeType,
  });
  
  /// Searches for files and folders by name
  /// 
  /// [query] - Search query (must not be empty)
  /// [pageToken] - Token for pagination (null for first page)
  /// [pageSize] - Number of items per page (must be > 0 and <= capabilities.maxPageSize)
  /// 
  /// Flutter Web Compatibility:
  /// - HTTP requests must use Uri objects for proper browser compatibility
  /// - Search API calls should handle CORS requirements
  /// - Query encoding should work correctly in browser environments
  /// - Response parsing must be compatible with dart2js compilation
  /// 
  /// Throws [CloudProviderException] if provider is disposed, not configured, or not authenticated
  /// Throws [ArgumentError] if query is empty or pageSize is invalid
  /// Throws [CloudProviderException] if provider doesn't support search
  Future<FileListPage> searchByName({
    required String query,
    String? pageToken,
    int pageSize = 50,
  });
  
  /// Gets the user profile information
  /// This method requires authentication and account management
  /// 
  /// Flutter Web Compatibility:
  /// - HTTP requests must use Uri objects and handle CORS properly
  /// - Authentication headers must work in browser environments
  /// - Profile data parsing should be dart2js compatible
  /// 
  /// Throws [CloudProviderException] if provider is disposed, not configured, or not authenticated
  /// Throws [CloudProviderException] if provider doesn't support user profiles
  Future<UserProfile> getUserProfile();
  
  /// Refreshes the authentication token
  /// 
  /// [account] - The account to refresh (must not be null and must have refresh token)
  /// Returns updated account with new tokens
  /// 
  /// Flutter Web Compatibility:
  /// - Token refresh requests must use Uri objects
  /// - OAuth refresh flows must work within browser security constraints
  /// - Secure token storage should consider browser limitations
  /// 
  /// Throws [CloudProviderException] if provider is disposed or refresh fails
  /// Throws [ArgumentError] if account is null or missing refresh token
  Future<CloudAccount> refreshAuth(CloudAccount account);
  
  /// Ensures the provider is authenticated and ready for operations
  /// 
  /// This method validates that the provider has the necessary authentication
  /// credentials based on its configuration and requirements.
  /// 
  /// Authentication Validation:
  /// - For API key providers: validates API key presence in configuration or account
  /// - For anonymous providers: always passes if no account management required
  /// - Checks that provider is not disposed
  /// - OAuth-specific validation is handled by OAuthCloudProvider
  /// 
  /// Throws [CloudProviderException] if provider is disposed or not authenticated
  void ensureAuthenticated() {
    ensureNotDisposed();
    
    if (!requiresAccountManagement) {
      return; // Anonymous providers don't need authentication
    }
    
    if (_currentAccount == null) {
      throw CloudProviderException(
        'Provider requires authentication but no account is set. '
        'Call setCurrentAccount() with a valid account first.'
      );
    }
    
    // Additional authentication validation can be added by concrete implementations
    _validateAuthenticationState();
  }
  
  /// Ensures the provider has not been disposed
  /// Throws CloudProviderException if already disposed
  void ensureNotDisposed() {
    if (_isDisposed) {
      throw CloudProviderException('Provider has been disposed and cannot be used');
    }
  }
  
  /// Whether this provider has been disposed
  bool get isDisposed => _isDisposed;
  
  /// Validates that the provided account is compatible with this provider
  /// 
  /// This method can be overridden by concrete implementations to add
  /// provider-specific account validation (e.g., checking for required
  /// token types, API key formats, etc.)
  /// 
  /// OAuth-specific account validation is handled by OAuthCloudProvider.
  /// 
  /// [account] - The account to validate
  /// Throws [ArgumentError] if account is invalid for this provider
  void _validateAccountForProvider(CloudAccount account) {
    // Base implementation performs basic validation
    // OAuth-specific validation is handled by OAuthCloudProvider
    
    // Concrete implementations can override this method to add
    // provider-specific validation (API key format, custom requirements, etc.)
  }
  
  /// Validates the current authentication state
  /// 
  /// This method can be overridden by concrete implementations to add
  /// provider-specific authentication state validation beyond the basic
  /// token validation performed by ensureAuthenticated().
  /// 
  /// Examples of additional validation:
  /// - API key format validation
  /// - Scope verification for OAuth tokens
  /// - Custom authentication requirements
  /// 
  /// Throws [CloudProviderException] if authentication state is invalid
  void _validateAuthenticationState() {
    // Base implementation does nothing - concrete implementations
    // can override to add provider-specific authentication validation
  }
  
  /// Validates that a capability is supported by this provider
  /// 
  /// [capability] - The capability to check
  /// Throws [CloudProviderException] if capability is not supported
  void ensureCapability(ProviderCapability capability) {
    final capabilities = getCapabilities();
    switch (capability) {
      case ProviderCapability.upload:
        if (!capabilities.canUpload) {
          throw CloudProviderException('Provider does not support file uploads');
        }
        break;
      case ProviderCapability.createFolders:
        if (!capabilities.canCreateFolders) {
          throw CloudProviderException('Provider does not support folder creation');
        }
        break;
      case ProviderCapability.delete:
        if (!capabilities.canDelete) {
          throw CloudProviderException('Provider does not support file deletion');
        }
        break;
      case ProviderCapability.search:
        if (!capabilities.canSearch) {
          throw CloudProviderException('Provider does not support search');
        }
        break;
      default:
        // For other capabilities, just continue without validation
        break;
    }
  }
  
  /// Validates page size against provider capabilities
  /// 
  /// [pageSize] - The requested page size
  /// Throws [ArgumentError] if pageSize is invalid
  void validatePageSize(int pageSize) {
    if (pageSize <= 0) {
      throw ArgumentError('Page size must be greater than 0');
    }
    
    final capabilities = getCapabilities();
    if (pageSize > capabilities.maxPageSize) {
      throw ArgumentError(
        'Page size ($pageSize) exceeds maximum allowed (${capabilities.maxPageSize})'
      );
    }
  }
  
  /// Validates that a string parameter is not empty
  /// 
  /// [value] - The string value to validate
  /// [parameterName] - Name of the parameter for error messages
  /// Throws [ArgumentError] if value is empty
  void validateNotEmpty(String? value, String parameterName) {
    if (value == null || value.trim().isEmpty) {
      throw ArgumentError('$parameterName cannot be empty');
    }
  }
  
  /// Validates that the provider is ready for operations
  /// 
  /// This method combines all common validation checks that should be
  /// performed before any provider operation:
  /// - Ensures provider is not disposed
  /// - Ensures provider is authenticated (if required)
  /// - Can be extended by concrete implementations for additional validation
  /// 
  /// This method should be called at the beginning of all abstract method implementations
  /// to ensure consistent resource state validation across all operations.
  /// 
  /// Throws [CloudProviderException] if provider is not ready for operations
  void ensureOperationReady() {
    ensureNotDisposed();
    ensureAuthenticated();
    
    // Concrete implementations can override this method to add additional
    // operation readiness checks (network connectivity, rate limiting, etc.)
  }
  
  /// Disposes of resources used by this provider
  /// 
  /// This method should be called when the provider is no longer needed
  /// to ensure proper cleanup of HTTP clients, streams, and other resources.
  /// 
  /// The base implementation marks the provider as disposed and clears the current account.
  /// Concrete implementations MUST override this method and call super.dispose() to:
  /// 
  /// ### Required Cleanup Actions:
  /// - Close HTTP clients and connection pools
  /// - Cancel active streams and subscriptions  
  /// - Clear authentication tokens and sensitive data
  /// - Release file handles and temporary resources
  /// - Dispose of any background timers or workers
  /// - Cancel pending network operations
  /// 
  /// ### Implementation Pattern:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   try {
  ///     // Cancel active operations first
  ///     _activeOperations.forEach((op) => op.cancel());
  ///     
  ///     // Close network resources
  ///     _httpClient?.close();
  ///     
  ///     // Clean up streams
  ///     _streamControllers.forEach((controller) => controller.close());
  ///     
  ///     // Clear sensitive data
  ///     _apiKeys?.clear();
  ///   } catch (e) {
  ///     // Log but don't throw from dispose
  ///     print('Warning: Error during provider disposal: $e');
  ///   } finally {
  ///     super.dispose(); // Always call super
  ///   }
  /// }
  /// ```
  /// 
  /// After calling dispose(), the provider should not be used for any operations.
  /// All method calls after disposal will throw [CloudProviderException].
  /// 
  /// ### Error Handling:
  /// Implementations should catch and log disposal errors rather than throwing them,
  /// as dispose() is often called during cleanup phases where exceptions cannot be handled.
  void dispose() {
    if (_isDisposed) return; // Already disposed
    
    try {
      // Clear sensitive authentication data
      _currentAccount = null;
    } finally {
      // Always mark as disposed, even if cleanup fails
      _isDisposed = true;
    }
  }
}