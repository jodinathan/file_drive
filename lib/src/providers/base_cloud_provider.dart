import '../models/file_entry.dart';
import '../models/provider_capabilities.dart';
import '../models/cloud_account.dart';

/// Progress information for upload operations
class UploadProgress {
  /// Number of bytes uploaded
  final int uploaded;
  
  /// Total size in bytes
  final int total;
  
  /// Progress percentage (0.0 to 1.0)
  double get progress => total > 0 ? uploaded / total : 0.0;
  
  /// Whether the upload is complete
  bool get isComplete => uploaded >= total;

  const UploadProgress({
    required this.uploaded,
    required this.total,
  });

  @override
  String toString() => 'UploadProgress(${(progress * 100).toStringAsFixed(1)}%)';
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
abstract class BaseCloudProvider {
  /// Unique identifier for this provider type
  String get providerType;
  
  /// Display name for this provider
  String get displayName;
  
  /// Path to the provider's logo asset
  String get logoAssetPath;
  
  /// Gets the capabilities of this provider
  ProviderCapabilities getCapabilities();
  
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
  
  /// Gets the user profile information
  Future<UserProfile> getUserProfile();
  
  /// Refreshes the authentication token
  /// 
  /// [account] - The account to refresh
  /// Returns updated account with new tokens
  Future<CloudAccount> refreshAuth(CloudAccount account);
  
  /// Initializes the provider with an account
  /// This method should be called before using other methods
  void initialize(CloudAccount account);
  
  /// Gets the current account being used by this provider
  CloudAccount? get currentAccount;
  
  /// Disposes of resources used by this provider
  /// Should be called when the provider is no longer needed
  void dispose() {
    // Default implementation does nothing
    // Subclasses can override to clean up resources
  }
}