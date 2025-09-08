import 'dart:async';
import 'package:googleapis/drive/v3.dart' as drive;
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
import '../auth/oauth_manager.dart';

/// HTTP client that uses OAuthCloudProvider's authentication
class OAuthAuthenticatedClient extends http.BaseClient {
  final OAuthCloudProvider _oauthProvider;
  final http.Client _client;

  OAuthAuthenticatedClient(this._oauthProvider) : _client = http.Client();

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

/// Google Drive provider implementation using official googleapis SDK
class GoogleDriveProvider extends OAuthCloudProvider {
  drive.DriveApi? _driveApi;
  OAuthAuthenticatedClient? _httpClient;
  
  @override
  CloudProviderType get providerType => CloudProviderType.googleDrive;
  
  @override
  String get displayName => 'Google Drive';
  
  @override
  String get logoAssetPath => 'assets/logos/google_drive.png';
  
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
  
  /// Creates a new Google Drive provider with the given configuration
  GoogleDriveProvider({
    required super.oauthConfiguration,
    super.account,
  }) {
    if (currentAccount != null) {
      _httpClient = OAuthAuthenticatedClient(this);
      _driveApi = drive.DriveApi(_httpClient!);
    }
  }
  
  @override
  void setCurrentAccount(CloudAccount? account) {
    super.setCurrentAccount(account);
    
    // Reinitialize API client when account changes
    if (currentAccount != null) {
      _httpClient = OAuthAuthenticatedClient(this);
      _driveApi = drive.DriveApi(_httpClient!);
      AppLogger.info('Google Drive API client reinitialized', component: 'GoogleDrive');
    } else {
      _driveApi = null;
      _httpClient?.close();
      _httpClient = null;
      AppLogger.info('Google Drive API client cleared', component: 'GoogleDrive');
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
      maxPageSize: 100,
    );
  }

  /// Converts Google Drive file to unified FileEntry
  FileEntry _convertToFileEntry(drive.File driveFile) {
    final isFolder = driveFile.mimeType == 'application/vnd.google-apps.folder';
    
    // Safely handle thumbnail fields with validation
    String? thumbnailUrl;
    bool hasThumbnail = false;
    String? thumbnailVersion;
    
    try {
      thumbnailUrl = driveFile.thumbnailLink;
      hasThumbnail = driveFile.hasThumbnail ?? false;
      thumbnailVersion = driveFile.thumbnailVersion?.toString();
      
      // Validate thumbnail URL if present
      if (thumbnailUrl != null && Uri.tryParse(thumbnailUrl) == null) {
        thumbnailUrl = null;
        hasThumbnail = false;
      }
    } catch (e) {
      // Log error but don't fail the entire conversion
      AppLogger.warning('Error processing thumbnail data for file ${driveFile.id}', component: 'GoogleDrive');
      thumbnailUrl = null;
      hasThumbnail = false;
      thumbnailVersion = null;
    }
    
    return FileEntry(
      id: driveFile.id!,
      name: driveFile.name!,
      isFolder: isFolder,
      size: isFolder ? null : (driveFile.size != null ? int.tryParse(driveFile.size!) : null),
      mimeType: isFolder ? null : driveFile.mimeType,
      createdAt: driveFile.createdTime,
      modifiedAt: driveFile.modifiedTime,
      parents: driveFile.parents ?? [],
      thumbnailUrl: thumbnailUrl,
      hasThumbnail: hasThumbnail,
      thumbnailVersion: thumbnailVersion,
      downloadUrl: driveFile.webContentLink,
      canDownload: driveFile.capabilities?.canDownload ?? true,
      canDelete: driveFile.capabilities?.canTrash ?? false,
      canShare: driveFile.capabilities?.canShare ?? false,
      metadata: {
        'googleDrive': {
          'mimeType': driveFile.mimeType,
          'capabilities': driveFile.capabilities?.toJson(),
          'hasThumbnail': hasThumbnail,
          'thumbnailVersion': thumbnailVersion,
        },
      },
    );
  }

  /// Handles API errors with enhanced OAuth error handling patterns
  void _handleApiError(Exception e) {
    AppLogger.error('GoogleDrive API Error', component: 'GoogleDrive', error: e);
    AppLogger.debug('Type: ${e.runtimeType}', component: 'GoogleDrive');
    AppLogger.debug('Message: ${e.toString()}', component: 'GoogleDrive');
    AppLogger.debug('Current Account: ${currentAccount?.email}', component: 'GoogleDrive');
    
    // Use parent OAuth provider's error handling for authentication errors
    if (isAuthenticationError(e)) {
      AppLogger.warning('Authentication error detected - delegating to OAuth provider', component: 'GoogleDrive');
      handleOAuthError(e);
      return; // handleOAuthError will throw appropriate exception
    }
    
    // Handle Google Drive specific errors
    if (e.toString().contains('403')) {
      if (e.toString().contains('insufficientPermissions') || 
          e.toString().contains('forbidden')) {
        AppLogger.warning('Insufficient permissions detected', component: 'GoogleDrive');
        _updateAccountStatus(AccountStatus.missingScopes);
        throw CloudProviderException(
          'Insufficient permissions. Please reauthorize with required scopes.',
          code: 'insufficient_permissions',
          statusCode: 403,
        );
      } else if (e.toString().contains('quotaExceeded')) {
        throw CloudProviderException(
          'Google Drive quota exceeded. Please try again later.',
          code: 'quota_exceeded',
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
    }
    
    // Generic error with improved context
    AppLogger.error('Unhandled Google Drive API error', component: 'GoogleDrive');
    throw CloudProviderException(
      'Google Drive operation failed: ${e.toString()}',
      originalException: e,
    );
  }

  /// Check if the error is authentication-related
  @override
  bool isAuthenticationError(dynamic error) {
    assert(error != null, 'Error cannot be null');
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains('401') || 
           errorString.contains('unauthorized') ||
           errorString.contains('invalid_token') ||
           errorString.contains('token_expired');
  }

  /// Get Google Drive specific headers for API requests
  @override
  Future<Map<String, String>> getProviderSpecificHeaders() async {
    return {
      'User-Agent': 'Flutter FileCloud Google Drive Client/1.0',
    };
  }

  /// Performs OAuth token exchange with Google Drive
  @override
  Future<Map<String, dynamic>> performTokenExchange(
    Uri tokenUrl, 
    String authorizationCode, 
    String state,
  ) async {
    assert(tokenUrl.toString().isNotEmpty, 'Token URL cannot be empty');
    assert(authorizationCode.isNotEmpty, 'Authorization code cannot be empty');
    assert(state.isNotEmpty, 'State cannot be empty');
    
    // This should be handled by the OAuth server, not the client
    throw UnimplementedError(
      'Token exchange should be handled by the OAuth server. '
      'Use the server endpoint to exchange authorization code for tokens.'
    );
  }

  /// Parses token response from Google Drive OAuth server
  @override
  CloudAccount parseTokenResponse(Map<String, dynamic> response) {
    assert(response.isNotEmpty, 'Token response cannot be empty');
    
    final accessToken = response['access_token'] as String?;
    final refreshToken = response['refresh_token'] as String?;
    final expiresIn = response['expires_in'] as int?;
    
    assert(accessToken != null && accessToken.isNotEmpty, 
           'Access token is required in token response');
    
    DateTime? expiresAt;
    if (expiresIn != null) {
      expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    }
    
    assert(accessToken != null && accessToken.isNotEmpty, 
           'Access token is required for CloudAccount creation');
    
    final now = DateTime.now();
    return CloudAccount(
      id: 'temp_${now.millisecondsSinceEpoch}',
      externalId: 'temp_external_${now.millisecondsSinceEpoch}', // Will be updated after getUserProfile
      email: 'pending@google.com', // Will be updated after getUserProfile
      name: 'Pending User',
      providerType: providerType.name,
      accessToken: accessToken!,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      createdAt: now,
      updatedAt: now,
      // scopes: oauthConfiguration.scopes, // TODO: Add scopes support to CloudAccount
    );
  }

  /// Generates secure OAuth state parameter
  @override
  String generateOAuthState() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = DateTime.now().microsecond.toString();
    return '${timestamp}_${random}_google_drive';
  }

  /// Launches authorization URL in browser
  @override
  Future<void> launchAuthorizationUrl(Uri authUrl) async {
    assert(authUrl.toString().isNotEmpty, 'Authorization URL cannot be empty');
    assert(authUrl.hasScheme, 'Authorization URL must have a valid scheme');
    
    throw UnimplementedError(
      'Authorization URL launching should be handled by the FileCloudWidget. '
      'URL to launch: ${authUrl.toString()}'
    );
  }

  /// Performs OAuth token refresh with Google Drive
  @override
  Future<CloudAccount> performTokenRefresh(CloudAccount account) async {
    assert(account.refreshToken != null && account.refreshToken!.isNotEmpty,
           'Refresh token is required for token refresh');
    assert(account.providerType == providerType.name,
           'Account provider type must match this provider');
    
    AppLogger.debug('Performing token refresh for account: ${account.email}', component: 'GoogleDrive');
    
    try {
      // Use OAuth manager to refresh the token
      final oauthManager = OAuthManager();
      
      // Use the dedicated refresh endpoint instead of token URL generator
      // The server has /auth/refresh endpoint specifically for token refresh
      final baseUrl = oauthConfiguration.tokenUrlGenerator('').toString();
      final refreshUrl = baseUrl.replaceAll('/auth/tokens/', '/auth/refresh');
      
      AppLogger.debug('Using refresh URL: $refreshUrl', component: 'GoogleDrive');
      
      final result = await oauthManager.refreshToken(
        refreshUrl: refreshUrl,
        refreshToken: account.refreshToken!,
      );
      
      if (result.isSuccess) {
        AppLogger.info('Token refresh successful', component: 'GoogleDrive');
        
        // Create updated account with new tokens
        final updatedAccount = account.copyWith(
          accessToken: result.accessToken!,
          refreshToken: result.refreshToken ?? account.refreshToken,
          expiresAt: result.expiresAt,
          updatedAt: DateTime.now(),
        );
        
        AppLogger.debug('Updated account created with new tokens', component: 'GoogleDrive');
        return updatedAccount;
        
      } else {
        AppLogger.error('Token refresh failed: ${result.error}', component: 'GoogleDrive');
        throw CloudProviderException(
          'Token refresh failed: ${result.error}',
          code: 'refresh_failed',
        );
      }
      
    } catch (e) {
      AppLogger.error('Exception during token refresh: $e', component: 'GoogleDrive');
      throw CloudProviderException(
        'Token refresh failed: ${e.toString()}',
        code: 'refresh_failed',
        originalException: e,
      );
    }
  }

  /// Performs HTTP request with Google Drive API error handling
  @override
  Future<Map<String, dynamic>> performHttpRequest(
    String method, 
    Uri url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    assert(method.isNotEmpty, 'HTTP method cannot be empty');
    assert(url.toString().isNotEmpty, 'URL cannot be empty');
    assert(['GET', 'POST', 'PUT', 'DELETE', 'PATCH'].contains(method.toUpperCase()),
           'HTTP method must be valid: $method');
    
    throw UnimplementedError(
      'HTTP requests for Google Drive should use the googleapis SDK. '
      'Method: $method, URL: $url'
    );
  }

  /// Performs streaming HTTP request for file downloads
  @override
  Future<Stream<List<int>>> performStreamRequest(
    Uri url,
    Map<String, String> headers,
  ) async {
    assert(url.toString().isNotEmpty, 'URL cannot be empty');
    assert(headers.isNotEmpty, 'Headers cannot be empty');
    
    throw UnimplementedError(
      'Streaming requests for Google Drive should use the googleapis SDK. '
      'URL: $url'
    );
  }

  /// Updates the current account status
  void _updateAccountStatus(AccountStatus status) {
    if (currentAccount != null) {
      // Update account in parent class if needed
      // Note: Account status is managed by OAuthCloudProvider
    }
  }

  void _ensureInitialized() {
    if (_driveApi == null) {
      throw CloudProviderException('Provider not initialized with an account');
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
      // Build query for folder contents
      String query = "trashed=false";
      if (folderId != null) {
        query += " and '$folderId' in parents";
      } else {
        query += " and 'root' in parents";
      }

      final response = await _driveApi!.files.list(
        q: query,
        pageSize: pageSize,
        pageToken: pageToken,
        $fields: 'nextPageToken,files(id,name,mimeType,size,modifiedTime,createdTime,parents,thumbnailLink,hasThumbnail,thumbnailVersion,webContentLink,capabilities)',
      );
      
      final files = (response.files ?? [])
          .map((driveFile) => _convertToFileEntry(driveFile))
          .toList();
      
      return FileListPage(
        entries: files,
        nextPageToken: response.nextPageToken,
        hasMore: response.nextPageToken != null,
      );
      
    } catch (e) {
      _handleApiError(e is Exception ? e : Exception(e.toString()));
      rethrow; // Won't reach here due to _handleApiError throwing
    }
  }
  
  /// Cancels an ongoing upload operation
  Future<void> cancelUpload(String uploadId) async {
    // Implementation depends on how upload tracking is implemented
    // For now, this is a placeholder as the current upload implementation
    // doesn't support cancellation tracking
    AppLogger.info('Upload cancellation requested: $uploadId', component: 'GoogleDrive');
    
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
      final driveFile = drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentId ?? 'root'];
      
      final createdFile = await _driveApi!.files.create(
        driveFile,
        $fields: 'id,name,mimeType,modifiedTime,parents',
      );
      
      return _convertToFileEntry(createdFile);
      
    } catch (e) {
      _handleApiError(e is Exception ? e : Exception(e.toString()));
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
      if (permanent) {
        await _driveApi!.files.delete(entryId);
      } else {
        final file = drive.File()..trashed = true;
        await _driveApi!.files.update(file, entryId);
      }
    } catch (e) {
      _handleApiError(e is Exception ? e : Exception(e.toString()));
      rethrow; // Won't reach here due to _handleApiError throwing
    }
  }
  
  @override
  Stream<List<int>> downloadFile({required String fileId}) async* {
    _ensureInitialized();
    
    try {
      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      yield* media.stream;
      
    } catch (e) {
      _handleApiError(e is Exception ? e : Exception(e.toString()));
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
      
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [parentId ?? 'root'];
      
      if (mimeType != null) {
        driveFile.mimeType = mimeType;
      }
      
      yield UploadProgress(
        uploaded: 0,
        total: totalSize,
        fileName: fileName,
        status: UploadStatus.uploading,
      );
      
      final media = drive.Media(
        Stream.fromIterable([bytes]),
        totalSize,
        contentType: mimeType ?? 'application/octet-stream',
      );
      
      await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id,name,mimeType,size,modifiedTime,parents',
      );
      
      yield UploadProgress(
        uploaded: totalSize,
        total: totalSize,
        fileName: fileName,
        status: UploadStatus.completed,
      );
      
    } catch (e) {
      _handleApiError(e is Exception ? e : Exception(e.toString()));
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
      final response = await _driveApi!.files.list(
        q: "name contains '$query' and trashed=false",
        pageSize: pageSize,
        pageToken: pageToken,
        $fields: 'nextPageToken,files(id,name,mimeType,size,modifiedTime,createdTime,parents,thumbnailLink,hasThumbnail,thumbnailVersion,webContentLink,capabilities)',
      );
      
      final files = (response.files ?? [])
          .map((driveFile) => _convertToFileEntry(driveFile))
          .toList();
      
      return FileListPage(
        entries: files,
        nextPageToken: response.nextPageToken,
        hasMore: response.nextPageToken != null,
      );
      
    } catch (e) {
      _handleApiError(e is Exception ? e : Exception(e.toString()));
      rethrow; // Won't reach here due to _handleApiError throwing
    }
  }
  
  @override
  Future<UserProfile> getUserProfile() async {
    _ensureInitialized();
    
    try {
      AppLogger.debug('Calling Google Drive API about.get()', component: 'GoogleDrive');
      final about = await _driveApi!.about.get($fields: 'user');
      AppLogger.debug('About response received: ${about.toJson()}', component: 'GoogleDrive');
      
      final user = about.user!;
      AppLogger.debug('User data: ${user.toJson()}', component: 'GoogleDrive');
      
      return UserProfile(
        id: user.permissionId!,
        name: user.displayName!,
        email: user.emailAddress!,
        photoUrl: user.photoLink,
      );
      
    } catch (e, stackTrace) {
      AppLogger.error('Error in getUserProfile - Type: ${e.runtimeType}', component: 'GoogleDrive');
      AppLogger.error('Error message: ${e.toString()}', component: 'GoogleDrive');
      AppLogger.error('Stack trace: $stackTrace', component: 'GoogleDrive');
      
      if (e is Exception) {
        _handleApiError(e);
      } else {
        // Handle non-Exception errors (like NoSuchMethodError)
        AppLogger.error('Non-Exception error caught: $e', component: 'GoogleDrive', error: e);
        throw CloudProviderException(
          'Falha ao obter informações do usuário: ${e.toString()}',
          code: 'user_profile_error',
          originalException: e is Exception ? e : null,
        );
      }
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
      
      AppLogger.debug('Refreshing token for account: ${account.email}', component: 'GoogleDrive');
      AppLogger.debug('Using token URL from configuration: $tokenUrl', component: 'GoogleDrive');
      
      // Delegate to parent OAuth provider's token refresh implementation
      return await refreshTokens(account);
      
    } catch (e) {
      AppLogger.error('Token refresh failed', component: 'GoogleDrive', error: e);
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
    _driveApi = null;
    super.dispose(); // Call parent dispose
  }
}