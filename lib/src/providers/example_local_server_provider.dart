import 'dart:async';
import 'dart:convert';

import '../enums/cloud_provider_type.dart';
import '../models/local_provider_configuration.dart';
import '../models/provider_capabilities.dart';
import '../models/file_entry.dart';
import 'base_cloud_provider.dart';
import 'local_cloud_provider.dart';
import '../utils/app_logger.dart';

/// Example implementation of a LocalCloudProvider
/// 
/// This class demonstrates how to extend LocalCloudProvider to create
/// a concrete provider implementation for a local server without OAuth authentication.
/// It serves as a reference implementation showing the proper usage patterns.
/// 
/// ## Usage Example
/// 
/// ```dart
/// // 1. Create configuration for your local server
/// final config = LocalProviderConfiguration(
///   type: CloudProviderType.localServer,
///   displayName: 'My Local Server',
///   baseUri: Uri.parse('http://localhost:3000'),
///   capabilities: {
///     ProviderCapability.upload,
///     ProviderCapability.createFolders,
///     ProviderCapability.delete,
///     ProviderCapability.search,
///   },
///   headers: {
///     'Authorization': 'Bearer your-api-token',
///     'X-API-Version': '1.0',
///   },
///   timeout: Duration(seconds: 30),
/// );
/// 
/// // 2. Create provider instance
/// final provider = ExampleLocalServerProvider(configuration: config);
/// 
/// // 3. Use the provider for file operations
/// try {
///   // List files in root folder
///   final files = await provider.listFolder();
///   print('Found ${files.entries.length} files');
/// 
///   // Create a new folder
///   final newFolder = await provider.createFolder(name: 'My Folder');
///   print('Created folder: ${newFolder.name}');
/// 
///   // Upload a file
///   final fileBytes = utf8.encode('Hello, World!');
///   final uploadStream = provider.uploadFile(
///     fileName: 'test.txt',
///     fileBytes: Stream.value(fileBytes),
///     parentId: newFolder.id,
///   );
///   
///   await for (final progress in uploadStream) {
///     print('Upload progress: ${(progress.progress * 100).toStringAsFixed(1)}%');
///   }
/// } finally {
///   provider.dispose();
/// }
/// ```
/// 
/// ## Server API Contract
/// 
/// Your local server must implement these REST endpoints:
/// 
/// ### GET /api/files
/// List files and folders
/// - Query parameters: `folderId`, `pageToken`, `pageSize`
/// - Response: `{"files": [...], "nextPageToken": "...", "hasMore": false}`
/// 
/// ### POST /api/folders
/// Create a new folder
/// - Body: `{"name": "folder name", "parentId": "parent folder id", "isFolder": true}`
/// - Response: File entry JSON object
/// 
/// ### DELETE /api/files/{id}
/// Delete a file or folder
/// - Query parameters: `permanent` (optional boolean)
/// - Response: 204 No Content
/// 
/// ### GET /api/files/{id}/download
/// Download a file
/// - Response: File content as byte stream
/// 
/// ### POST /api/upload
/// Upload a file
/// - Query parameters: `fileName`, `parentId`, `mimeType`
/// - Body: Base64-encoded file content
/// - Headers: `Content-Type: application/octet-stream`, `Content-Transfer-Encoding: base64`
/// - Response: 201 Created
/// 
/// ### GET /api/search
/// Search files by name
/// - Query parameters: `query`, `pageToken`, `pageSize`
/// - Response: `{"files": [...], "nextPageToken": "...", "hasMore": false}`
/// 
/// ## File Entry JSON Format
/// 
/// ```json
/// {
///   "id": "unique-file-id",
///   "name": "filename.txt",
///   "isFolder": false,
///   "size": 1024,
///   "mimeType": "text/plain",
///   "createdAt": "2023-01-01T00:00:00Z",
///   "modifiedAt": "2023-01-01T12:00:00Z",
///   "parents": ["parent-folder-id"],
///   "thumbnailUrl": "http://localhost:3000/thumbnails/file-id.jpg",
///   "hasThumbnail": true,
///   "downloadUrl": "http://localhost:3000/api/files/file-id/download",
///   "canDownload": true,
///   "canDelete": true,
///   "canShare": false,
///   "metadata": {
///     "custom": "properties"
///   }
/// }
/// ```
/// 
/// ## Flutter Web Compatibility
/// 
/// This implementation is fully compatible with Flutter Web environments:
/// - Uses Uri-based networking through LocalCloudProvider helpers
/// - HTTP client operations use the standard `http` package which works in browsers
/// - File uploads use base64 encoding which is web-safe
/// - Streaming downloads work with browser networking constraints
/// - CORS-friendly headers are included for cross-origin requests
/// - All networking goes through LocalCloudProvider's web-compatible helper methods
/// 
/// ### CORS Configuration
/// 
/// For web deployment, ensure your server has proper CORS headers:
/// 
/// ```
/// Access-Control-Allow-Origin: *
/// Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
/// Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Content-Transfer-Encoding
/// ```
/// 
/// ## Error Handling
/// 
/// The provider throws `CloudProviderException` for various error conditions:
/// - `TIMEOUT`: Request exceeded configured timeout
/// - `NETWORK_ERROR`: Network connectivity issues
/// - `REQUEST_FAILED`: Server returned error status
/// - `PARSE_ERROR`: Invalid JSON response format
/// 
/// ## Performance Considerations
/// 
/// - **Large Files**: Files over 50MB may hit memory constraints in web environments
/// - **Chunked Upload**: Consider implementing chunked upload for large files
/// - **Connection Pooling**: The HTTP client reuses connections for efficiency
/// - **Timeout Management**: Configure appropriate timeouts for your network conditions
/// 
/// ## Troubleshooting
/// 
/// ### Common Issues
/// 
/// **Connection Refused**
/// - Ensure your local server is running and accessible
/// - Check firewall settings and port availability
/// - Verify the baseUri in your configuration
/// 
/// **CORS Errors (Web)**
/// - Configure proper CORS headers on your server
/// - Ensure preflight OPTIONS requests are handled
/// - Check browser developer console for specific CORS messages
/// 
/// **Upload Failures**
/// - Verify server accepts base64-encoded content
/// - Check Content-Type and Content-Transfer-Encoding headers
/// - Ensure server has sufficient disk space
/// 
/// **Authentication Issues**
/// - Verify API tokens/headers are correctly configured
/// - Check server logs for authentication errors
/// - Ensure tokens haven't expired
/// 
/// ## Integration with CloudProviderFactory
/// 
/// ```dart
/// // Register with factory for automatic instantiation
/// final config = LocalProviderConfiguration(
///   type: CloudProviderType.localServer,
///   displayName: 'Development Server',
///   baseUri: Uri.parse('http://localhost:3000'),
///   capabilities: {ProviderCapability.upload, ProviderCapability.createFolders},
/// );
/// 
/// // The factory will automatically create ExampleLocalServerProvider instances
/// final provider = CloudProviderFactory.createFromConfiguration(config);
/// ```
class ExampleLocalServerProvider extends LocalCloudProvider {
  /// Creates an ExampleLocalServerProvider with the given configuration
  /// 
  /// [configuration] - Local provider configuration with server settings
  /// [account] - Optional cloud account for the provider
  ExampleLocalServerProvider({
    required LocalProviderConfiguration configuration,
    super.account,
  }) : super(localConfiguration: configuration);

  @override
  CloudProviderType get providerType => CloudProviderType.localServer;

  @override
  String get displayName => configuration.displayName;

  @override
  String? get logoAssetPath => null; // Uses default icon fallback

  @override
  ProviderCapabilities getCapabilities() {
    return ProviderCapabilities(
      canUpload: true,
      canCreateFolders: true,
      canDelete: true,
      canSearch: true,
      maxUploadSize: 100 * 1024 * 1024, // 100 MB
      supportedUploadTypes: [
        'text/plain',
        'application/json',
        'application/pdf',
        'image/png',
        'image/jpeg',
        'image/gif',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
    );
  }

  @override
  Future<FileListPage> listFolder({
    String? folderId,
    String? pageToken,
    int pageSize = 50,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'pageSize': pageSize.toString(),
      };
      if (folderId != null) {
        queryParams['folderId'] = folderId;
      }
      if (pageToken != null) {
        queryParams['pageToken'] = pageToken;
      }
      
      // Build path with query parameters
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final path = '/api/files${queryString.isNotEmpty ? '?$queryString' : ''}';
      
      // Make request using LocalCloudProvider helper
      final response = await makeGetRequest(path);
      validateResponse(response, 'List folder');
      
      final data = parseJsonResponse(response, 'List folder');
      
      // Parse file entries from response
      final entries = (data['files'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map((fileData) => _parseFileEntry(fileData))
          .toList();
      
      return FileListPage(
        entries: entries,
        nextPageToken: data['nextPageToken'] as String?,
        hasMore: data['hasMore'] as bool? ?? false,
      );
    } catch (e) {
      AppLogger.error('Failed to list folder: $e', component: 'ExampleLocalServerProvider');
      rethrow;
    }
  }

  @override
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  }) async {
    try {
      final requestData = {
        'name': name,
        'parentId': parentId,
        'isFolder': true,
      };
      
      // Make request using LocalCloudProvider helper
      final response = await makePostRequest('/api/folders', body: requestData);
      validateResponse(response, 'Create folder');
      
      final data = parseJsonResponse(response, 'Create folder');
      return _parseFileEntry(data);
    } catch (e) {
      AppLogger.error('Failed to create folder "$name": $e', component: 'ExampleLocalServerProvider');
      rethrow;
    }
  }

  @override
  Future<void> deleteEntry({
    required String entryId,
    bool permanent = false,
  }) async {
    try {
      final path = '/api/files/$entryId${permanent ? '?permanent=true' : ''}';
      
      // Make request using LocalCloudProvider helper
      final response = await makeDeleteRequest(path);
      validateResponse(response, 'Delete entry');
      
      AppLogger.info('Successfully deleted entry: $entryId', component: 'ExampleLocalServerProvider');
    } catch (e) {
      AppLogger.error('Failed to delete entry "$entryId": $e', component: 'ExampleLocalServerProvider');
      rethrow;
    }
  }

  @override
  Stream<List<int>> downloadFile({
    required String fileId,
  }) async* {
    try {
      final path = '/api/files/$fileId/download';
      
      // Use LocalCloudProvider streaming helper
      final stream = await makeStreamRequest(path);
      
      AppLogger.info('Starting download for file: $fileId', component: 'ExampleLocalServerProvider');
      
      await for (final chunk in stream) {
        yield chunk;
      }
      
      AppLogger.success('Download completed for file: $fileId', component: 'ExampleLocalServerProvider');
    } catch (e) {
      AppLogger.error('Failed to download file "$fileId": $e', component: 'ExampleLocalServerProvider');
      rethrow;
    }
  }

  @override
  Stream<UploadProgress> uploadFile({
    required String fileName,
    required Stream<List<int>> fileBytes,
    String? parentId,
    String? mimeType,
  }) async* {
    final startTime = DateTime.now();
    
    try {
      // Convert stream to bytes for upload
      // Note: For production use with large files in web environments,
      // consider implementing chunked upload to avoid memory constraints
      final List<int> allBytes = [];
      await for (final chunk in fileBytes) {
        allBytes.addAll(chunk);
      }
      
      final totalSize = allBytes.length;
      
      // Web-specific consideration: Large files may hit browser memory limits
      if (totalSize > 50 * 1024 * 1024) { // 50MB threshold
        AppLogger.warning(
          'Large file upload ($totalSize bytes) may face memory constraints in web environments',
          component: 'ExampleLocalServerProvider',
        );
      }
      
      // Emit starting progress
      yield UploadProgress(
        uploaded: 0,
        total: totalSize,
        fileName: fileName,
        speed: 0.0,
        estimatedTimeRemaining: null,
        status: UploadStatus.waiting,
        error: null,
        startTime: startTime,
        lastUpdate: DateTime.now(),
      );
      
      // Build query parameters for upload endpoint
      final queryParams = <String, String>{
        'fileName': fileName,
      };
      if (parentId != null) {
        queryParams['parentId'] = parentId;
      }
      if (mimeType != null) {
        queryParams['mimeType'] = mimeType;
      }
      
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final path = '/api/upload${queryString.isNotEmpty ? '?$queryString' : ''}';
      
      // Emit progress during upload (simplified - in reality this would be chunked)
      yield UploadProgress(
        uploaded: totalSize ~/ 2,
        total: totalSize,
        fileName: fileName,
        speed: totalSize / 2.0,
        estimatedTimeRemaining: const Duration(seconds: 1),
        status: UploadStatus.uploading,
        error: null,
        startTime: startTime,
        lastUpdate: DateTime.now(),
      );
      
      // Make the upload request with web-friendly approach
      // Use base64 encoding for web compatibility, but consider chunking for large files
      final response = await makeRequest(
        'POST',
        path,
        body: base64Encode(allBytes),
        additionalHeaders: {
          'Content-Type': 'application/octet-stream',
          'Content-Transfer-Encoding': 'base64',
          // Add CORS-friendly headers
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      
      validateResponse(response, 'Upload file');
      
      // Emit completion progress
      yield UploadProgress(
        uploaded: totalSize,
        total: totalSize,
        fileName: fileName,
        speed: totalSize / DateTime.now().difference(startTime).inSeconds,
        estimatedTimeRemaining: Duration.zero,
        status: UploadStatus.completed,
        error: null,
        startTime: startTime,
        lastUpdate: DateTime.now(),
      );
      
      AppLogger.success('Upload completed for file: $fileName', component: 'ExampleLocalServerProvider');
    } catch (e) {
      AppLogger.error('Failed to upload file "$fileName": $e', component: 'ExampleLocalServerProvider');
      
      yield UploadProgress(
        uploaded: 0,
        total: 0,
        fileName: fileName,
        speed: 0.0,
        estimatedTimeRemaining: null,
        status: UploadStatus.error,
        error: e.toString(),
        startTime: startTime,
        lastUpdate: DateTime.now(),
      );
    }
  }

  @override
  Future<FileListPage> searchByName({
    required String query,
    String? pageToken,
    int pageSize = 50,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'query': query,
        'pageSize': pageSize.toString(),
      };
      if (pageToken != null) {
        queryParams['pageToken'] = pageToken;
      }
      
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final path = '/api/search?$queryString';
      
      // Make request using LocalCloudProvider helper
      final response = await makeGetRequest(path);
      validateResponse(response, 'Search by name');
      
      final data = parseJsonResponse(response, 'Search by name');
      
      // Parse file entries from response
      final entries = (data['files'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map((fileData) => _parseFileEntry(fileData))
          .toList();
      
      return FileListPage(
        entries: entries,
        nextPageToken: data['nextPageToken'] as String?,
        hasMore: data['hasMore'] as bool? ?? false,
      );
    } catch (e) {
      AppLogger.error('Failed to search by name "$query": $e', component: 'ExampleLocalServerProvider');
      rethrow;
    }
  }
  
  /// Helper method to parse file entry data from server response
  FileEntry _parseFileEntry(Map<String, dynamic> data) {
    return FileEntry(
      id: data['id'] as String,
      name: data['name'] as String,
      isFolder: data['isFolder'] as bool? ?? false,
      size: data['size'] as int?,
      mimeType: data['mimeType'] as String?,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String)
          : null,
      modifiedAt: data['modifiedAt'] != null
          ? DateTime.tryParse(data['modifiedAt'] as String)
          : null,
      parents: data['parents'] != null
          ? List<String>.from(data['parents'] as List)
          : [],
      thumbnailUrl: data['thumbnailUrl'] as String?,
      hasThumbnail: data['hasThumbnail'] as bool? ?? false,
      thumbnailVersion: data['thumbnailVersion'] as String?,
      downloadUrl: data['downloadUrl'] as String?,
      canDownload: data['canDownload'] as bool? ?? true,
      canDelete: data['canDelete'] as bool? ?? true,
      canShare: data['canShare'] as bool? ?? false,
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : {},
    );
  }
}