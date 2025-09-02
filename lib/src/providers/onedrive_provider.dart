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
import '../models/account_status.dart';
import '../utils/app_logger.dart';

/// HTTP client that uses OAuthCloudProvider's authentication for OneDrive requests
class OneDriveAuthenticatedClient extends http.BaseClient {
  final OneDriveProvider _oneDriveProvider;
  final http.Client _client;

  OneDriveAuthenticatedClient(this._oneDriveProvider) : _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      // Get authenticated headers from parent OAuth provider
      final headers = await _oneDriveProvider.getAuthenticatedHeaders();
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

/// OneDrive provider implementation using Microsoft Graph API
class OneDriveProvider extends OAuthCloudProvider {
  OneDriveAuthenticatedClient? _httpClient;
  
  // Microsoft Graph API base URL
  static const String _graphApiBase = 'https://graph.microsoft.com/v1.0';
  
  @override
  CloudProviderType get providerType => CloudProviderType.oneDrive;
  
  @override
  String get displayName => 'OneDrive';
  
  @override
  String get logoAssetPath => 'assets/logos/onedrive.png';
  
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
  
  /// Creates a new OneDrive provider with the given OAuth configuration
  OneDriveProvider({
    required super.oauthConfiguration,
    super.account,
  }) {
    if (currentAccount != null) {
      _httpClient = OneDriveAuthenticatedClient(this);
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
      maxPageSize: 200, // OneDrive supports up to 200 items per request
    );
  }

  /// Converts OneDrive item to unified FileEntry
  FileEntry _convertToFileEntry(Map<String, dynamic> oneDriveItem) {
    final isFolder = oneDriveItem['folder'] != null;
    
    // Safely handle thumbnail fields with validation
    String? thumbnailUrl;
    bool hasThumbnail = false;
    String? thumbnailVersion;
    
    try {
      final thumbnails = oneDriveItem['thumbnails'] as List<dynamic>?;
      if (thumbnails != null && thumbnails.isNotEmpty) {
        final thumbnail = thumbnails[0] as Map<String, dynamic>?;
        if (thumbnail != null && thumbnail['medium'] != null) {
          final medium = thumbnail['medium'] as Map<String, dynamic>;
          thumbnailUrl = medium['url'] as String?;
          hasThumbnail = thumbnailUrl != null;
        }
      }
      
      // Validate thumbnail URL if present
      if (thumbnailUrl != null && Uri.tryParse(thumbnailUrl) == null) {
        thumbnailUrl = null;
        hasThumbnail = false;
      }
    } catch (e) {
      // Log error but don't fail the entire conversion
      AppLogger.warning('Error processing thumbnail data for file ${oneDriveItem['id']}', component: 'OneDrive');
      thumbnailUrl = null;
      hasThumbnail = false;
      thumbnailVersion = null;
    }
    
    // Parse parent references
    List<String> parents = [];
    try {
      final parentReference = oneDriveItem['parentReference'] as Map<String, dynamic>?;
      if (parentReference != null && parentReference['id'] != null) {
        parents = [parentReference['id'] as String];
      }
    } catch (e) {
      AppLogger.warning('Error processing parent reference for file ${oneDriveItem['id']}', component: 'OneDrive');
    }
    
    return FileEntry(
      id: oneDriveItem['id'] as String,
      name: oneDriveItem['name'] as String,
      isFolder: isFolder,
      size: isFolder ? null : oneDriveItem['size'] as int?,
      mimeType: isFolder ? null : (oneDriveItem['file']?['mimeType'] as String?),
      createdAt: DateTime.tryParse(oneDriveItem['createdDateTime'] as String? ?? ''),
      modifiedAt: DateTime.tryParse(oneDriveItem['lastModifiedDateTime'] as String? ?? ''),
      parents: parents,
      thumbnailUrl: thumbnailUrl,
      hasThumbnail: hasThumbnail,
      thumbnailVersion: thumbnailVersion,
      downloadUrl: oneDriveItem['@microsoft.graph.downloadUrl'] as String?,
      canDownload: true, // OneDrive generally allows downloads
      canDelete: oneDriveItem['deleted'] == null,
      canShare: true, // OneDrive generally supports sharing
      metadata: {
        'oneDrive': {
          'webUrl': oneDriveItem['webUrl'],
          'eTag': oneDriveItem['eTag'],
          'cTag': oneDriveItem['cTag'],
          'createdBy': oneDriveItem['createdBy'],
          'lastModifiedBy': oneDriveItem['lastModifiedBy'],
          'hasThumbnail': hasThumbnail,
        },
      },
    );
  }

  /// Handles API errors with enhanced OAuth error handling patterns
  void _handleApiError(Exception e) {
    AppLogger.error('OneDrive API Error', component: 'OneDrive', error: e);
    AppLogger.debug('Type: ${e.runtimeType}', component: 'OneDrive');
    AppLogger.debug('Message: ${e.toString()}', component: 'OneDrive');
    AppLogger.debug('Current Account: ${currentAccount?.email}', component: 'OneDrive');
    
    // Use parent OAuth provider's error handling for authentication errors
    if (_isAuthenticationError(e)) {
      AppLogger.warning('Authentication error detected - delegating to OAuth provider', component: 'OneDrive');
      handleOAuthError(e);
      return; // handleOAuthError will throw appropriate exception
    }
    
    // Handle OneDrive/Microsoft Graph specific errors
    if (e.toString().contains('403')) {
      if (e.toString().contains('Forbidden') || 
          e.toString().contains('InsufficientPermissions')) {
        AppLogger.warning('Insufficient permissions detected', component: 'OneDrive');
        _updateAccountStatus(AccountStatus.missingScopes);
        throw CloudProviderException(
          'Insufficient permissions. Please reauthorize with required scopes.',
          code: 'insufficient_permissions',
          statusCode: 403,
        );
      } else if (e.toString().contains('TooManyRequests')) {
        throw CloudProviderException(
          'OneDrive rate limit exceeded. Please try again later.',
          code: 'rate_limit',
          statusCode: 403,
        );
      }
    } else if (e.toString().contains('404')) {
      throw CloudProviderException(
        'Requested file or folder not found.',
        code: 'not_found',
        statusCode: 404,
      );
    } else if (e.toString().contains('429')) {
      throw CloudProviderException(
        'Rate limit exceeded. Please try again later.',
        code: 'rate_limit',
        statusCode: 429,
      );
    } else if (e.toString().contains('507')) {
      throw CloudProviderException(
        'OneDrive storage quota exceeded.',
        code: 'quota_exceeded',
        statusCode: 507,
      );
    }
    
    // Generic error with improved context
    AppLogger.error('Unhandled OneDrive API error', component: 'OneDrive');
    throw CloudProviderException(
      'OneDrive operation failed: ${e.toString()}',
      originalException: e,
    );
  }

  /// Check if the error is authentication-related
  bool _isAuthenticationError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('401') || 
           errorString.contains('unauthorized') ||
           errorString.contains('invalid_token') ||
           errorString.contains('token_expired') ||
           errorString.contains('unauthenticated');
  }

  /// Updates the current account status
  void _updateAccountStatus(AccountStatus status) {
    if (currentAccount != null) {
      // Update account in parent class if needed
      // Note: Account status is managed by OAuthCloudProvider
    }
  }

  void _ensureInitialized() {
    if (_httpClient == null) {
      throw CloudProviderException('Provider not initialized with an account');
    }
  }

  /// Makes an authenticated HTTP request to Microsoft Graph API
  Future<Map<String, dynamic>> _makeGraphRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    _ensureInitialized();
    
    Uri url = Uri.parse('$_graphApiBase$endpoint');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      url = url.replace(queryParameters: queryParameters);
    }
    
    late http.Response response;
    
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _httpClient!.get(url);
          break;
        case 'POST':
          response = await _httpClient!.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await _httpClient!.put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await _httpClient!.delete(url);
          break;
        case 'PATCH':
          response = await _httpClient!.patch(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        default:
          throw CloudProviderException('Unsupported HTTP method: $method');
      }
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          return {};
        }
      } else {
        throw CloudProviderException(
          'OneDrive API request failed: ${response.statusCode} ${response.reasonPhrase}',
          code: 'api_error',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      rethrow; // Won't reach here due to _handleApiError throwing
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
      String endpoint;
      if (folderId != null) {
        endpoint = '/me/drive/items/$folderId/children';
      } else {
        endpoint = '/me/drive/root/children';
      }
      
      final queryParams = {
        '\$top': pageSize.toString(),
        '\$expand': 'thumbnails(select=medium)',
      };
      
      if (pageToken != null) {
        queryParams['\$skiptoken'] = pageToken;
      }
      
      final response = await _makeGraphRequest('GET', endpoint, queryParameters: queryParams);
      
      final items = (response['value'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map((item) => _convertToFileEntry(item))
          .toList();
      
      final nextLink = response['@odata.nextLink'] as String?;
      String? nextPageToken;
      
      if (nextLink != null) {
        // Extract skip token from next link
        final uri = Uri.parse(nextLink);
        nextPageToken = uri.queryParameters['\$skiptoken'];
      }
      
      return FileListPage(
        entries: items,
        nextPageToken: nextPageToken,
        hasMore: nextPageToken != null,
      );
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      rethrow; // Won't reach here due to _handleApiError throwing
    }
  }
  
  @override
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  }) async {
    _ensureInitialized();
    
    try {
      String endpoint;
      if (parentId != null) {
        endpoint = '/me/drive/items/$parentId/children';
      } else {
        endpoint = '/me/drive/root/children';
      }
      
      final body = {
        'name': name,
        'folder': {},
        '@microsoft.graph.conflictBehavior': 'rename',
      };
      
      final response = await _makeGraphRequest('POST', endpoint, body: body);
      
      return _convertToFileEntry(response);
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      rethrow; // Won't reach here due to _handleApiError throwing
    }
  }
  
  @override
  Future<void> deleteEntry({
    required String entryId,
    bool permanent = false,
  }) async {
    _ensureInitialized();
    
    try {
      final endpoint = '/me/drive/items/$entryId';
      await _makeGraphRequest('DELETE', endpoint);
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      rethrow; // Won't reach here due to _handleApiError throwing
    }
  }
  
  @override
  Stream<List<int>> downloadFile({required String fileId}) async* {
    _ensureInitialized();
    
    try {
      final endpoint = '/me/drive/items/$fileId/content';
      final url = Uri.parse('$_graphApiBase$endpoint');
      
      final request = http.Request('GET', url);
      final headers = await getAuthenticatedHeaders();
      request.headers.addAll(headers);
      
      final response = await _httpClient!.send(request);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        yield* response.stream;
      } else {
        throw CloudProviderException(
          'Failed to download file: ${response.statusCode} ${response.reasonPhrase}',
          code: 'download_failed',
          statusCode: response.statusCode,
        );
      }
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      rethrow; // Won't reach here due to _handleApiError throwing
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
      
      String endpoint;
      if (parentId != null) {
        endpoint = '/me/drive/items/$parentId:/$fileName:/content';
      } else {
        endpoint = '/me/drive/root:/$fileName:/content';
      }
      
      final url = Uri.parse('$_graphApiBase$endpoint');
      final request = http.Request('PUT', url);
      final headers = await getAuthenticatedHeaders();
      
      if (mimeType != null) {
        headers['Content-Type'] = mimeType;
      }
      
      request.headers.addAll(headers);
      request.bodyBytes = bytes;
      
      final response = await _httpClient!.send(request);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        yield UploadProgress(
          uploaded: totalSize,
          total: totalSize,
          fileName: fileName,
          status: UploadStatus.completed,
        );
      } else {
        throw CloudProviderException(
          'File upload failed: ${response.statusCode} ${response.reasonPhrase}',
          code: 'upload_failed',
          statusCode: response.statusCode,
        );
      }
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      rethrow; // Won't reach here due to _handleApiError throwing
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
      final endpoint = '/me/drive/root/search(q=\'$query\')';
      
      final queryParams = {
        '\$top': pageSize.toString(),
        '\$expand': 'thumbnails(select=medium)',
      };
      
      if (pageToken != null) {
        queryParams['\$skiptoken'] = pageToken;
      }
      
      final response = await _makeGraphRequest('GET', endpoint, queryParameters: queryParams);
      
      final items = (response['value'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map((item) => _convertToFileEntry(item))
          .toList();
      
      final nextLink = response['@odata.nextLink'] as String?;
      String? nextPageToken;
      
      if (nextLink != null) {
        // Extract skip token from next link
        final uri = Uri.parse(nextLink);
        nextPageToken = uri.queryParameters['\$skiptoken'];
      }
      
      return FileListPage(
        entries: items,
        nextPageToken: nextPageToken,
        hasMore: nextPageToken != null,
      );
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      rethrow; // Won't reach here due to _handleApiError throwing
    }
  }
  
  @override
  Future<UserProfile> getUserProfile() async {
    _ensureInitialized();
    
    try {
      final response = await _makeGraphRequest('GET', '/me');
      
      return UserProfile(
        id: response['id'] as String,
        name: response['displayName'] as String,
        email: response['mail'] as String? ?? response['userPrincipalName'] as String,
        photoUrl: null, // Could be implemented with /me/photo if needed
      );
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      _handleApiError(e as Exception);
      rethrow; // Won't reach here due to _handleApiError throwing
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
      
      AppLogger.debug('Refreshing token for account: ${account.email}', component: 'OneDrive');
      AppLogger.debug('Using token URL from configuration: $tokenUrl', component: 'OneDrive');
      
      // Delegate to parent OAuth provider's token refresh implementation
      return await refreshTokens(account);
      
    } catch (e) {
      AppLogger.error('Token refresh failed', component: 'OneDrive', error: e);
      throw CloudProviderException(
        'Token refresh failed: ${e.toString()}',
        code: 'refresh_failed',
        originalException: e,
      );
    }
  }

  // Required abstract method implementations from OAuthCloudProvider


  @override
  void dispose() {
    _httpClient?.close();
    _httpClient = null;
    super.dispose(); // Call parent dispose
  }
}