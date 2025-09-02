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
    if (_isAuthenticationError(e)) {
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
  bool _isAuthenticationError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('401') || 
           errorString.contains('unauthorized') ||
           errorString.contains('invalid_token') ||
           errorString.contains('token_expired');
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
      _handleApiError(e as Exception);
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
      if (permanent) {
        await _driveApi!.files.delete(entryId);
      } else {
        final file = drive.File()..trashed = true;
        await _driveApi!.files.update(file, entryId);
      }
    } catch (e) {
      _handleApiError(e as Exception);
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
      _handleApiError(e as Exception);
      rethrow; // Won't reach here due to _handleApiError throwing
    }
  }
  
  @override
  Future<UserProfile> getUserProfile() async {
    _ensureInitialized();
    
    try {
      final about = await _driveApi!.about.get($fields: 'user');
      final user = about.user!;
      
      return UserProfile(
        id: user.permissionId!,
        name: user.displayName!,
        email: user.emailAddress!,
        photoUrl: user.photoLink,
      );
      
    } catch (e) {
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