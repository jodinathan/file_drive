import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../enums/cloud_provider_type.dart';
import '../enums/oauth_scope.dart';
import 'base_cloud_provider.dart';
import 'oauth_cloud_provider.dart';
import '../models/file_entry.dart';
import '../models/provider_capabilities.dart';
import '../models/cloud_account.dart';
import '../utils/app_logger.dart';

/// HTTP client that uses OAuthCloudProvider's authentication
class DropboxAuthenticatedClient extends http.BaseClient {
  final OAuthCloudProvider _oauthProvider;
  final http.Client _client;

  DropboxAuthenticatedClient(this._oauthProvider) : _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      // Get authenticated headers from parent OAuth provider
      final headers = await _oauthProvider.getAuthenticatedHeaders();
      request.headers.addAll(headers);
      return _client.send(request);
    } catch (e) {
      // If authentication fails, let the parent handle it
      rethrow;
    }
  }

  @override
  void close() {
    _client.close();
  }
}

/// Dropbox provider implementation using Dropbox API v2
class DropboxProvider extends OAuthCloudProvider {
  DropboxAuthenticatedClient? _httpClient;
  static const String _baseUrl = 'https://api.dropboxapi.com/2';
  static const String _contentUrl = 'https://content.dropboxapi.com/2';
  
  @override
  CloudProviderType get providerType => CloudProviderType.dropbox;
  
  @override
  String get displayName => 'Dropbox';
  
  @override
  String get logoAssetPath => 'assets/logos/dropbox.png';
  
  @override
  bool get requiresAccountManagement => true;
  
  @override
  Set<OAuthScope> get requiredScopes => {
    OAuthScope.readFiles,
    OAuthScope.writeFiles,
    OAuthScope.createFolders,
    OAuthScope.deleteFiles,
    OAuthScope.readProfile,
    OAuthScope.readMetadata,
  };
  
  /// Creates a new Dropbox provider with the given configuration
  DropboxProvider({
    required super.oauthConfiguration,
    super.account,
  }) {
    if (currentAccount != null) {
      _httpClient = DropboxAuthenticatedClient(this);
    }
  }
  
  @override
  ProviderCapabilities getCapabilities() {
    return const ProviderCapabilities(
      canUpload: true,
      canCreateFolders: true,
      canDelete: true,
      canPermanentDelete: true,
      canSearch: true,
      canChunkedUpload: true,
      hasThumbnails: true,
      canShare: true,
      canMove: true,
      canCopy: true,
      canRename: true,
      maxPageSize: 2000, // Dropbox supports up to 2000 items per page
    );
  }

  /// Converts Dropbox metadata to unified FileEntry
  FileEntry _convertToFileEntry(Map<String, dynamic> metadata) {
    final tag = metadata['.tag'] as String;
    final isFolder = tag == 'folder';
    final id = metadata['id'] as String? ?? metadata['path_lower'] as String;
    final name = metadata['name'] as String;
    
    // Handle thumbnail information
    bool hasThumbnail = false;
    if (!isFolder) {
      final hasPreview = metadata['has_explicit_shared_members'] as bool? ?? false;
      hasThumbnail = hasPreview || _isImageFile(name);
    }
    
    // Parse timestamps
    DateTime? createdAt;
    DateTime? modifiedAt;
    
    try {
      final modifiedTimeStr = metadata['client_modified'] as String? ?? 
                              metadata['server_modified'] as String?;
      
      if (modifiedTimeStr != null) {
        modifiedAt = DateTime.parse(modifiedTimeStr);
        createdAt = modifiedAt; // Dropbox doesn't distinguish between created/modified
      }
    } catch (e) {
      AppLogger.warning('Error parsing timestamps for Dropbox item $id', component: 'Dropbox');
    }
    
    // Get parent information from path
    final pathLower = metadata['path_lower'] as String? ?? '';
    final parentPath = pathLower.substring(0, pathLower.lastIndexOf('/'));
    
    return FileEntry(
      id: id,
      name: name,
      isFolder: isFolder,
      size: isFolder ? null : (metadata['size'] as int?),
      mimeType: isFolder ? null : _getMimeTypeFromExtension(name),
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      parents: parentPath.isEmpty ? [] : [parentPath],
      thumbnailUrl: null, // Dropbox thumbnails require separate API call
      hasThumbnail: hasThumbnail,
      thumbnailVersion: metadata['content_hash'] as String?, // Use content hash as version
      downloadUrl: null, // Dropbox requires separate download call
      canDownload: !isFolder,
      canDelete: true,
      canShare: metadata['sharing_info'] != null,
      metadata: {
        'dropbox': {
          'tag': tag,
          'pathLower': metadata['path_lower'],
          'pathDisplay': metadata['path_display'],
          'contentHash': metadata['content_hash'],
          'rev': metadata['rev'],
          'sharingInfo': metadata['sharing_info'],
        },
      },
    );
  }

  /// Check if file is an image based on extension
  bool _isImageFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(extension);
  }

  /// Get MIME type from file extension
  String? _getMimeTypeFromExtension(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
    return mimeTypes[extension];
  }

  /// Handles API errors with enhanced OAuth error handling patterns
  void _handleApiError(Exception e, {http.Response? response}) {
    AppLogger.error('Dropbox API Error', component: 'Dropbox', error: e);
    AppLogger.debug('Type: ${e.runtimeType}', component: 'Dropbox');
    AppLogger.debug('Message: ${e.toString()}', component: 'Dropbox');
    AppLogger.debug('Current Account: ${currentAccount?.email}', component: 'Dropbox');
    
    if (response != null) {
      AppLogger.debug('HTTP Status: ${response.statusCode}', component: 'Dropbox');
      AppLogger.debug('Response Body: ${response.body}', component: 'Dropbox');
    }
    
    // Use parent OAuth provider's error handling for authentication errors
    if (_isAuthenticationError(e, response)) {
      AppLogger.warning('Authentication error detected - delegating to OAuth provider', component: 'Dropbox');
      handleOAuthError(e);
      return; // handleOAuthError will throw appropriate exception
    }
    
    // Handle Dropbox API specific errors
    if (response != null) {
      switch (response.statusCode) {
        case 401:
          throw CloudProviderException(
            'Authentication failed. Please reauthorize your Dropbox account.',
            code: 'authentication_failed',
            statusCode: 401,
          );
        case 403:
          throw CloudProviderException(
            'Insufficient permissions. Please reauthorize with required scopes.',
            code: 'insufficient_permissions',
            statusCode: 403,
          );
        case 404:
          throw CloudProviderException(
            'Requested file or folder not found.',
            code: 'not_found',
            statusCode: 404,
          );
        case 409:
          if (response.body.contains('insufficient_space')) {
            throw CloudProviderException(
              'Dropbox storage full.',
              code: 'insufficient_storage',
              statusCode: 409,
            );
          }
          break;
        case 429:
          throw CloudProviderException(
            'Rate limit exceeded. Please try again later.',
            code: 'rate_limit',
            statusCode: 429,
          );
      }
      
      // Try to parse Dropbox error response
      try {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        final errorSummary = errorData['error_summary'] as String?;
        if (errorSummary != null) {
          throw CloudProviderException(
            'Dropbox API error: $errorSummary',
            code: 'dropbox_api_error',
            statusCode: response.statusCode,
          );
        }
      } catch (_) {
        // If we can't parse the error, fall through to generic error
      }
    }
    
    // Generic error with improved context
    AppLogger.error('Unhandled Dropbox API error', component: 'Dropbox');
    throw CloudProviderException(
      'Dropbox operation failed: ${e.toString()}',
      originalException: e,
    );
  }

  /// Check if the error is authentication-related
  bool _isAuthenticationError(dynamic error, http.Response? response) {
    if (response?.statusCode == 401) {
      return true;
    }
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains('401') || 
           errorString.contains('unauthorized') ||
           errorString.contains('invalid_token') ||
           errorString.contains('token_expired') ||
           errorString.contains('invalid_access_token');
  }


  void _ensureInitialized() {
    if (_httpClient == null) {
      throw CloudProviderException('Provider not initialized with an account');
    }
  }

  /// Makes authenticated HTTP request to Dropbox API
  Future<Map<String, dynamic>> _makeDropboxRequest(
    String endpoint, {
    Map<String, dynamic>? body,
    String method = 'POST',
    bool useContentEndpoint = false,
  }) async {
    _ensureInitialized();
    
    try {
      final baseUrl = useContentEndpoint ? _contentUrl : _baseUrl;
      final url = '$baseUrl$endpoint';
      
      http.Response response;
      final headers = {'Content-Type': 'application/json'};
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _httpClient!.get(Uri.parse(url), headers: headers);
          break;
        case 'POST':
          response = await _httpClient!.post(
            Uri.parse(url),
            headers: headers,
            body: body != null ? json.encode(body) : null,
          );
          break;
        case 'DELETE':
          response = await _httpClient!.delete(Uri.parse(url), headers: headers);
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return <String, dynamic>{};
        }
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        _handleApiError(
          HttpException('Request failed with status ${response.statusCode}'),
          response: response,
        );
        throw StateError('Should not reach here'); // _handleApiError always throws
      }
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      throw StateError('Should not reach here'); // _handleApiError always throws
    }
  }
  
  @override
  Future<FileListPage> listFolder({
    String? folderId,
    String? pageToken,
    int pageSize = 50,
  }) async {
    _ensureInitialized();
    
    try {
      final body = <String, dynamic>{
        'path': folderId ?? '',
        'recursive': false,
        'include_media_info': true,
        'include_deleted': false,
        'include_has_explicit_shared_members': true,
        'limit': pageSize,
      };
      
      if (pageToken != null) {
        body['cursor'] = pageToken;
      }
      
      final endpoint = pageToken != null ? '/files/list_folder/continue' : '/files/list_folder';
      final response = await _makeDropboxRequest(endpoint, body: body);
      
      final entries = (response['entries'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map((entry) => _convertToFileEntry(entry))
          .toList();
      
      final hasMore = response['has_more'] as bool? ?? false;
      final cursor = response['cursor'] as String?;
      
      return FileListPage(
        entries: entries,
        nextPageToken: hasMore ? cursor : null,
        hasMore: hasMore,
      );
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      throw StateError('Should not reach here'); // _handleApiError always throws
    }
  }
  
  /// Cancels an ongoing upload operation
  Future<void> cancelUpload(String uploadId) async {
    AppLogger.info('Upload cancellation requested: $uploadId', component: 'Dropbox');
    
    // In a full implementation, this would:
    // 1. Track active uploads by ID
    // 2. Cancel the underlying HTTP request
    // 3. Clean up any temporary resources
    
    throw UnimplementedError('Upload cancellation not yet implemented');
  }

  @override
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  }) async {
    _ensureInitialized();
    
    try {
      final path = parentId != null ? '$parentId/$name' : '/$name';
      
      final body = {
        'path': path,
        'autorename': false,
      };
      
      final response = await _makeDropboxRequest('/files/create_folder_v2', body: body);
      final metadata = response['metadata'] as Map<String, dynamic>;
      
      return _convertToFileEntry(metadata);
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      throw StateError('Should not reach here'); // _handleApiError always throws
    }
  }
  
  @override
  Future<void> deleteEntry({
    required String entryId,
    bool permanent = false,
  }) async {
    _ensureInitialized();
    
    try {
      final body = {'path': entryId};
      
      await _makeDropboxRequest('/files/delete_v2', body: body);
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      throw StateError('Should not reach here'); // _handleApiError always throws
    }
  }
  
  @override
  Stream<List<int>> downloadFile({required String fileId}) async* {
    _ensureInitialized();
    
    try {
      final response = await _httpClient!.post(
        Uri.parse('$_contentUrl/files/download'),
        headers: {
          'Dropbox-API-Arg': json.encode({'path': fileId}),
        },
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        yield response.bodyBytes;
      } else {
        _handleApiError(
          HttpException('Download failed with status ${response.statusCode}'),
          response: response,
        );
      }
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      throw StateError('Should not reach here'); // _handleApiError always throws
    }
  }
  
  @override
  Stream<UploadProgress> uploadFile({
    required String fileName,
    required Stream<List<int>> fileBytes,
    String? parentId,
    String? mimeType,
  }) async* {
    _ensureInitialized();
    
    try {
      // Convert stream to bytes for upload size calculation
      final bytes = await fileBytes.expand((chunk) => chunk).toList();
      final totalSize = bytes.length;
      
      yield UploadProgress(
        uploaded: 0,
        total: totalSize,
        fileName: fileName,
        status: UploadStatus.uploading,
      );
      
      final path = parentId != null ? '$parentId/$fileName' : '/$fileName';
      
      final response = await _httpClient!.post(
        Uri.parse('$_contentUrl/files/upload'),
        headers: {
          'Content-Type': 'application/octet-stream',
          'Dropbox-API-Arg': json.encode({
            'path': path,
            'mode': 'add',
            'autorename': true,
            'mute': false,
          }),
        },
        body: bytes,
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        yield UploadProgress(
          uploaded: totalSize,
          total: totalSize,
          fileName: fileName,
          status: UploadStatus.completed,
        );
      } else {
        yield UploadProgress(
          uploaded: 0,
          total: totalSize,
          fileName: fileName,
          status: UploadStatus.error,
          error: 'Upload failed with status ${response.statusCode}',
        );
        
        _handleApiError(
          HttpException('Upload failed with status ${response.statusCode}'),
          response: response,
        );
      }
      
    } catch (e) {
      yield UploadProgress(
        uploaded: 0,
        total: 0,
        fileName: fileName,
        status: UploadStatus.error,
        error: e.toString(),
      );
      
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      throw StateError('Should not reach here'); // _handleApiError always throws
    }
  }
  
  @override
  Future<FileListPage> searchByName({
    required String query,
    String? pageToken,
    int pageSize = 50,
  }) async {
    _ensureInitialized();
    
    try {
      final body = <String, dynamic>{
        'query': query,
        'mode': {
          '.tag': 'filename',
        },
        'max_results': pageSize,
      };
      
      if (pageToken != null) {
        body['start'] = int.tryParse(pageToken) ?? 0;
      }
      
      final response = await _makeDropboxRequest('/files/search_v2', body: body);
      
      final matches = (response['matches'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map((match) {
            final metadata = match['metadata'] as Map<String, dynamic>?;
            final matchMetadata = metadata?['metadata'] as Map<String, dynamic>?;
            return matchMetadata != null ? _convertToFileEntry(matchMetadata) : null;
          })
          .where((entry) => entry != null)
          .cast<FileEntry>()
          .toList();
      
      final hasMore = response['more'] as bool? ?? false;
      final start = (response['start'] as int? ?? 0) + matches.length;
      
      return FileListPage(
        entries: matches,
        nextPageToken: hasMore ? start.toString() : null,
        hasMore: hasMore,
      );
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      throw StateError('Should not reach here'); // _handleApiError always throws
    }
  }
  
  @override
  Future<UserProfile> getUserProfile() async {
    _ensureInitialized();
    
    try {
      final response = await _makeDropboxRequest('/users/get_current_account');
      
      return UserProfile(
        id: response['account_id'] as String,
        name: response['name']?['display_name'] as String? ?? 'Dropbox User',
        email: response['email'] as String,
        photoUrl: response['profile_photo_url'] as String?,
      );
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      throw StateError('Should not reach here'); // _handleApiError always throws
    }
  }
  
  @override
  Future<CloudAccount> refreshAuth(CloudAccount account) async {
    if (account.refreshToken == null || account.refreshToken!.isEmpty) {
      throw CloudProviderException(
        'No refresh token available for account ${account.email}',
        code: 'no_refresh_token',
      );
    }

    try {
      // Use configuration's token URL generator instead of hardcoded URLs
      final tokenUrl = oauthConfiguration.tokenUrlGenerator('refresh');
      
      AppLogger.debug('Refreshing token for account: ${account.email}', component: 'Dropbox');
      AppLogger.debug('Using token URL from configuration: $tokenUrl', component: 'Dropbox');
      
      // Delegate to parent OAuth provider's token refresh implementation
      return await refreshTokens(account);
      
    } catch (e) {
      AppLogger.error('Token refresh failed', component: 'Dropbox', error: e);
      throw CloudProviderException(
        'Token refresh failed: ${e.toString()}',
        code: 'refresh_failed',
        originalException: e,
      );
    }
  }

  @override
  void dispose() {
    _httpClient?.close();
    _httpClient = null;
    super.dispose(); // Call parent dispose
  }
}

/// Exception for HTTP-related errors
class HttpException implements Exception {
  final String message;
  
  const HttpException(this.message);
  
  @override
  String toString() => 'HttpException: $message';
}