import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../providers/base_cloud_provider.dart';
import '../models/file_entry.dart';
import '../models/provider_capabilities.dart';
import '../models/cloud_account.dart';
import '../models/account_status.dart';

/// Google Drive API response models
class GoogleDriveFile {
  final String id;
  final String name;
  final String? mimeType;
  final int? size;
  final DateTime? modifiedTime;
  final List<String> parents;
  final String? thumbnailLink;
  final String? webContentLink;
  final Map<String, bool> capabilities;
  
  GoogleDriveFile({
    required this.id,
    required this.name,
    this.mimeType,
    this.size,
    this.modifiedTime,
    this.parents = const [],
    this.thumbnailLink,
    this.webContentLink,
    this.capabilities = const {},
  });
  
  factory GoogleDriveFile.fromJson(Map<String, dynamic> json) {
    return GoogleDriveFile(
      id: json['id'] as String,
      name: json['name'] as String,
      mimeType: json['mimeType'] as String?,
      size: json['size'] != null ? int.tryParse(json['size'].toString()) : null,
      modifiedTime: json['modifiedTime'] != null 
          ? DateTime.tryParse(json['modifiedTime'] as String)
          : null,
      parents: List<String>.from(json['parents'] as List? ?? []),
      thumbnailLink: json['thumbnailLink'] as String?,
      webContentLink: json['webContentLink'] as String?,
      capabilities: Map<String, bool>.from(json['capabilities'] as Map? ?? {}),
    );
  }
  
  /// Converts Google Drive file to unified FileEntry
  FileEntry toFileEntry() {
    final isFolder = mimeType == 'application/vnd.google-apps.folder';
    
    return FileEntry(
      id: id,
      name: name,
      isFolder: isFolder,
      size: isFolder ? null : size,
      mimeType: isFolder ? null : mimeType,
      modifiedAt: modifiedTime,
      parents: parents,
      thumbnailUrl: thumbnailLink,
      downloadUrl: webContentLink,
      canDownload: capabilities['canDownload'] ?? true,
      canDelete: capabilities['canTrash'] ?? false,
      canShare: capabilities['canShare'] ?? false,
      metadata: {
        'googleDrive': {
          'mimeType': mimeType,
          'capabilities': capabilities,
        },
      },
    );
  }
}

/// Google Drive user profile
class GoogleDriveUser {
  final String id;
  final String displayName;
  final String emailAddress;
  final String? photoLink;
  
  GoogleDriveUser({
    required this.id,
    required this.displayName,
    required this.emailAddress,
    this.photoLink,
  });
  
  factory GoogleDriveUser.fromJson(Map<String, dynamic> json) {
    return GoogleDriveUser(
      id: json['permissionId'] as String? ?? json['id'] as String,
      displayName: json['displayName'] as String,
      emailAddress: json['emailAddress'] as String,
      photoLink: json['photoLink'] as String?,
    );
  }
  
  UserProfile toUserProfile() {
    return UserProfile(
      id: id,
      name: displayName,
      email: emailAddress,
      photoUrl: photoLink,
    );
  }
}

/// Google Drive provider implementation
class GoogleDriveProvider extends BaseCloudProvider {
  static const String _baseUrl = 'https://www.googleapis.com/drive/v3';
  static const String _uploadUrl = 'https://www.googleapis.com/upload/drive/v3';
  
  CloudAccount? _currentAccount;
  
  @override
  String get providerType => 'google_drive';
  
  @override
  String get displayName => 'Google Drive';
  
  @override
  String get logoAssetPath => 'assets/logos/google_drive.png';
  
  @override
  CloudAccount? get currentAccount => _currentAccount;
  
  @override
  void initialize(CloudAccount account) {
    _currentAccount = account;
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
  
  /// Gets authorization headers for API requests
  Map<String, String> get _authHeaders {
    if (_currentAccount == null) {
      throw CloudProviderException('Provider not initialized with an account');
    }
    
    return {
      'Authorization': 'Bearer ${_currentAccount!.accessToken}',
      'Accept': 'application/json',
    };
  }
  
  /// Handles API errors and updates account status if needed
  void _handleApiError(http.Response response) {
    if (response.statusCode == 401) {
      // Unauthorized - token is invalid
      _updateAccountStatus(AccountStatus.revoked);
      throw CloudProviderException(
        'Authentication failed. Please reauthorize your account.',
        code: 'unauthorized',
        statusCode: 401,
      );
    } else if (response.statusCode == 403) {
      // Forbidden - might be scope issue
      final body = response.body;
      if (body.contains('insufficientPermissions') || body.contains('forbidden')) {
        _updateAccountStatus(AccountStatus.missingScopes);
        throw CloudProviderException(
          'Insufficient permissions. Please reauthorize with required scopes.',
          code: 'insufficient_permissions',
          statusCode: 403,
        );
      }
    }
    
    // Generic error
    throw CloudProviderException(
      'API request failed: ${response.statusCode} ${response.reasonPhrase}',
      statusCode: response.statusCode,
    );
  }
  
  /// Updates the current account status
  void _updateAccountStatus(AccountStatus status) {
    if (_currentAccount != null) {
      _currentAccount = _currentAccount!.updateStatus(status);
    }
  }
  
  @override
  Future<FileListPage> listFolder({
    String? folderId,
    String? pageToken,
    int pageSize = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'pageSize': pageSize.toString(),
        'fields': 'nextPageToken,files(id,name,mimeType,size,modifiedTime,parents,thumbnailLink,webContentLink,capabilities)',
      };
      
      if (pageToken != null) {
        queryParams['pageToken'] = pageToken;
      }
      
      // Build query for folder contents
      String query = "trashed=false";
      if (folderId != null) {
        query += " and '$folderId' in parents";
      } else {
        query += " and 'root' in parents";
      }
      queryParams['q'] = query;
      
      final uri = Uri.parse('$_baseUrl/files').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _authHeaders);
      
      if (response.statusCode != 200) {
        _handleApiError(response);
      }
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      final files = (data['files'] as List<dynamic>? ?? [])
          .map((fileJson) => GoogleDriveFile.fromJson(fileJson as Map<String, dynamic>))
          .map((driveFile) => driveFile.toFileEntry())
          .toList();
      
      return FileListPage(
        entries: files,
        nextPageToken: data['nextPageToken'] as String?,
        hasMore: data['nextPageToken'] != null,
      );
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      throw CloudProviderException('Failed to list folder contents: ${e.toString()}');
    }
  }
  
  @override
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  }) async {
    try {
      final metadata = <String, dynamic>{
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': [parentId ?? 'root'],
      };
      
      final response = await http.post(
        Uri.parse('$_baseUrl/files?fields=id,name,mimeType,modifiedTime,parents'),
        headers: {
          ..._authHeaders,
          'Content-Type': 'application/json',
        },
        body: json.encode(metadata),
      );
      
      if (response.statusCode != 200) {
        _handleApiError(response);
      }
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      final driveFile = GoogleDriveFile.fromJson(data);
      return driveFile.toFileEntry();
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      throw CloudProviderException('Failed to create folder: ${e.toString()}');
    }
  }
  
  @override
  Future<void> deleteEntry({
    required String entryId,
    bool permanent = false,
  }) async {
    try {
      final Uri uri;
      if (permanent) {
        uri = Uri.parse('$_baseUrl/files/$entryId');
      } else {
        uri = Uri.parse('$_baseUrl/files/$entryId');
      }
      
      final response = permanent 
          ? await http.delete(uri, headers: _authHeaders)
          : await http.patch(
              uri,
              headers: {
                ..._authHeaders,
                'Content-Type': 'application/json',
              },
              body: json.encode({'trashed': true}),
            );
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        _handleApiError(response);
      }
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      throw CloudProviderException('Failed to delete entry: ${e.toString()}');
    }
  }
  
  @override
  Stream<List<int>> downloadFile({required String fileId}) async* {
    try {
      final uri = Uri.parse('$_baseUrl/files/$fileId?alt=media');
      final request = http.Request('GET', uri);
      request.headers.addAll(_authHeaders);
      
      final response = await request.send();
      
      if (response.statusCode != 200) {
        throw CloudProviderException(
          'Download failed: ${response.statusCode} ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }
      
      yield* response.stream;
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      throw CloudProviderException('Failed to download file: ${e.toString()}');
    }
  }
  
  @override
  Stream<UploadProgress> uploadFile({
    required String fileName,
    required Stream<List<int>> fileBytes,
    String? parentId,
    String? mimeType,
  }) async* {
    try {
      // Convert stream to bytes for upload
      final bytes = await fileBytes.expand((chunk) => chunk).toList();
      final totalSize = bytes.length;
      
      // Create metadata
      final metadata = <String, dynamic>{
        'name': fileName,
        'parents': [parentId ?? 'root'],
      };
      
      if (mimeType != null) {
        metadata['mimeType'] = mimeType;
      }
      
      // Use multipart upload for simplicity
      final boundary = 'dart-boundary-${DateTime.now().millisecondsSinceEpoch}';
      final metadataJson = json.encode(metadata);
      
      final multipartBody = [
        '--$boundary',
        'Content-Type: application/json; charset=UTF-8',
        '',
        metadataJson,
        '--$boundary',
        'Content-Type: ${mimeType ?? 'application/octet-stream'}',
        '',
      ].join('\r\n').codeUnits;
      
      multipartBody.addAll(bytes);
      multipartBody.addAll('\r\n--$boundary--'.codeUnits);
      
      yield UploadProgress(uploaded: 0, total: totalSize);
      
      final response = await http.post(
        Uri.parse('$_uploadUrl/files?uploadType=multipart&fields=id,name,mimeType,size,modifiedTime,parents'),
        headers: {
          ..._authHeaders,
          'Content-Type': 'multipart/related; boundary="$boundary"',
        },
        body: multipartBody,
      );
      
      if (response.statusCode != 200) {
        _handleApiError(response);
      }
      
      yield UploadProgress(uploaded: totalSize, total: totalSize);
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      throw CloudProviderException('Failed to upload file: ${e.toString()}');
    }
  }
  
  @override
  Future<FileListPage> searchByName({
    required String query,
    String? pageToken,
    int pageSize = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'q': "name contains '$query' and trashed=false",
        'pageSize': pageSize.toString(),
        'fields': 'nextPageToken,files(id,name,mimeType,size,modifiedTime,parents,thumbnailLink,webContentLink,capabilities)',
      };
      
      if (pageToken != null) {
        queryParams['pageToken'] = pageToken;
      }
      
      final uri = Uri.parse('$_baseUrl/files').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _authHeaders);
      
      if (response.statusCode != 200) {
        _handleApiError(response);
      }
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      final files = (data['files'] as List<dynamic>? ?? [])
          .map((fileJson) => GoogleDriveFile.fromJson(fileJson as Map<String, dynamic>))
          .map((driveFile) => driveFile.toFileEntry())
          .toList();
      
      return FileListPage(
        entries: files,
        nextPageToken: data['nextPageToken'] as String?,
        hasMore: data['nextPageToken'] != null,
      );
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      throw CloudProviderException('Failed to search files: ${e.toString()}');
    }
  }
  
  @override
  Future<UserProfile> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/about?fields=user'),
        headers: _authHeaders,
      );
      
      if (response.statusCode != 200) {
        _handleApiError(response);
      }
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      final userData = data['user'] as Map<String, dynamic>;
      final driveUser = GoogleDriveUser.fromJson(userData);
      
      return driveUser.toUserProfile();
      
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      throw CloudProviderException('Failed to get user profile: ${e.toString()}');
    }
  }
  
  @override
  Future<CloudAccount> refreshAuth(CloudAccount account) async {
    // This method should be implemented by the OAuth manager
    // For now, throw an exception indicating that refresh should be handled externally
    throw CloudProviderException(
      'Token refresh should be handled by the OAuth manager',
      code: 'refresh_externally',
    );
  }
}