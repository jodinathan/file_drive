import '../models/file_entry.dart';
import '../enums/cloud_provider_type.dart';
import '../enums/oauth_scope.dart';
import '../models/provider_capabilities.dart';
import '../models/cloud_account.dart';

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

// TODO: Import ProviderConfiguration when Phase 1.1 is complete
// import '../models/provider_configuration.dart';

/// Abstract base class for cloud storage providers
abstract class BaseCloudProvider {
  /// Current provider configuration
  dynamic _configuration; // Will be ProviderConfiguration when Phase 1.1 is complete
  
  /// Current account being used by this provider
  CloudAccount? _currentAccount;
  
  /// Cloud provider type for this provider
  CloudProviderType get providerType;
  
  /// Display name for this provider
  String get displayName;
  
  /// Path to the provider's logo asset (can be null for icon-only providers)
  String? get logoAssetPath => null;
  
  /// Whether this provider requires account management
  bool get requiresAccountManagement => false;
  
  /// Gets the capabilities of this provider
  ProviderCapabilities getCapabilities();
  
  /// Gets the OAuth scopes required by this provider
  Set<OAuthScope> get requiredScopes;
  
  /// Unique identifier for this provider type (deprecated)
  @Deprecated('Use providerType enum directly instead of string identifier')
  String get providerTypeString => providerType.name;
  
  /// Gets the current account being used by this provider
  CloudAccount? get currentAccount => _currentAccount;
  
  /// Lists files and folders in the specified folder
  /// 
  /// [folderId] - ID of the folder to list (null for root)
  /// [pageToken] - Token for pagination (null for first page)
  /// [pageSize] - Number of items per page (default: 50)
  Future<FileListPage> listFolder({
    String? folderId,
    String? pageToken,
    int pageSize = 50,
  });
  
  /// Creates a new folder
  /// 
  /// [name] - Name of the folder to create
  /// [parentId] - ID of the parent folder (null for root)
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  });
  
  /// Deletes a file or folder
  /// 
  /// [entryId] - ID of the file or folder to delete
  /// [permanent] - Whether to delete permanently (bypass trash)
  Future<void> deleteEntry({
    required String entryId,
    bool permanent = false,
  });
  
  /// Downloads a file
  /// 
  /// [fileId] - ID of the file to download
  /// Returns a stream of bytes
  Stream<List<int>> downloadFile({
    required String fileId,
  });
  
  /// Uploads a file
  /// 
  /// [fileName] - Name of the file
  /// [fileBytes] - Stream of file bytes
  /// [parentId] - ID of the parent folder (null for root)
  /// [mimeType] - MIME type of the file
  /// Returns a stream of upload progress
  Stream<UploadProgress> uploadFile({
    required String fileName,
    required Stream<List<int>> fileBytes,
    String? parentId,
    String? mimeType,
  });
  
  /// Searches for files and folders by name
  /// 
  /// [query] - Search query
  /// [pageToken] - Token for pagination (null for first page)
  /// [pageSize] - Number of items per page (default: 50)
  Future<FileListPage> searchByName({
    required String query,
    String? pageToken,
    int pageSize = 50,
  });
  
  /// Initializes the provider with configuration and optional account
  /// This method should be called before using other provider methods
  /// 
  /// [configuration] - Provider configuration (will be ProviderConfiguration when Phase 1.1 is complete)
  /// [account] - Optional cloud account for authenticated operations
  void initialize({
    required dynamic configuration, // Will be ProviderConfiguration when Phase 1.1 is complete
    CloudAccount? account,
  }) {
    _configuration = configuration;
    _currentAccount = account;
  }
  
  /// Gets the user profile information
  /// This method requires authentication
  Future<UserProfile> getUserProfile();
  
  /// Refreshes the authentication token
  /// 
  /// [account] - The account to refresh
  /// Returns updated account with new tokens
  Future<CloudAccount> refreshAuth(CloudAccount account);
  
  /// Ensures the provider is authenticated
  /// Throws CloudProviderException if not authenticated
  void ensureAuthenticated() {
    if (_currentAccount?.accessToken == null) {
      throw CloudProviderException('Provider not authenticated');
    }
  }
  
  /// Disposes of resources used by this provider
  /// Should be called when the provider is no longer needed
  void dispose() {
    // Default implementation does nothing
    // Subclasses can override to clean up resources
  }
}