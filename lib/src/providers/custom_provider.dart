import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../enums/cloud_provider_type.dart';
import '../enums/oauth_scope.dart';
import '../models/file_entry.dart';
import '../models/provider_capabilities.dart';
import '../models/cloud_account.dart';
import 'base_cloud_provider.dart';

/// Configuration for the custom provider
class CustomProviderConfig {
  /// Display name of the provider (e.g., "Minha Galeria")
  final String displayName;
  
  /// Base URL of the server
  final String baseUrl;
  
  /// Widget to display as logo/icon
  final Widget logoWidget;
  
  /// Whether to show account management features
  final bool showAccountManagement;
  
  /// Provider type identifier
  final String providerType;

  const CustomProviderConfig({
    required this.displayName,
    required this.baseUrl,
    required this.logoWidget,
    this.showAccountManagement = true,
    this.providerType = 'custom',
  });
}

/// Custom provider implementation that connects to a configurable server
class CustomProvider extends BaseCloudProvider {
  final CustomProviderConfig config;
  late http.Client _httpClient;

  @override
  CloudProviderType get providerType => CloudProviderType.custom;

  @override
  String get displayName => config.displayName;

  @override
  String get logoAssetPath => ''; // Not used since we have logoWidget

  @override
  Set<OAuthScope> get requiredScopes => {}; // Custom provider doesn't use OAuth scopes

  /// Widget to display as logo/icon
  Widget get logoWidget => config.logoWidget;

  /// Whether to show account management features
  bool get showAccountManagement => config.showAccountManagement;

  CustomProvider({required this.config}) {
    _httpClient = http.Client();
  }

  @override
  ProviderCapabilities getCapabilities() {
    return const ProviderCapabilities(
      canUpload: true,
      canCreateFolders: true,
      canDelete: true,
      canSearch: true,
      canChunkedUpload: false,
      hasThumbnails: false,
      maxPageSize: 100,
    );
  }

  @override
  Future<FileListPage> listFolder({
    String? folderId,
    String? pageToken,
    int pageSize = 50,
  }) async {
    // If no account management, return mock file list for demo
    if (!config.showAccountManagement) {
      return _getMockFileList(folderId);
    }
    
    final headers = _getAuthHeaders();
    final queryParams = <String, String>{};
    
    if (folderId != null) queryParams['folder'] = folderId;
    if (pageToken != null) queryParams['page_token'] = pageToken;
    queryParams['page_size'] = pageSize.toString();

    final uri = Uri.parse('${config.baseUrl}/api/files').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await _httpClient.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final files = (data['files'] as List)
          .map((fileData) => _parseFileEntry(fileData))
          .toList();

      return FileListPage(
        entries: files,
        nextPageToken: data['next_page_token'],
        hasMore: data['has_next_page'] ?? false,
      );
    }

    throw CloudProviderException(
      'Failed to list files: ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  @override
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  }) async {
    // If no account management, return mock created folder
    if (!config.showAccountManagement) {
      final now = DateTime.now();
      return FileEntry(
        id: 'mock_folder_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        isFolder: true,
        size: 0,
        modifiedAt: now,
        createdAt: now,
        mimeType: null,
      );
    }
    
    final headers = _getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    final body = json.encode({
      'name': name,
      'parent_id': parentId,
    });

    final response = await _httpClient.post(
      Uri.parse('${config.baseUrl}/api/folders'),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return _parseFileEntry(data);
    }

    throw CloudProviderException(
      'Failed to create folder: ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  @override
  Future<void> deleteEntry({
    required String entryId,
    bool permanent = false,
  }) async {
    // If no account management, just pretend deletion worked
    if (!config.showAccountManagement) {
      return;
    }
    
    final headers = _getAuthHeaders();
    final uri = Uri.parse('${config.baseUrl}/api/files/$entryId').replace(
      queryParameters: permanent ? {'permanent': 'true'} : null,
    );

    final response = await _httpClient.delete(uri, headers: headers);

    if (response.statusCode != 204) {
      throw CloudProviderException(
        'Failed to delete entry: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Stream<List<int>> downloadFile({required String fileId}) async* {
    final headers = _getAuthHeaders();
    final response = await _httpClient.get(
      Uri.parse('${config.baseUrl}/api/files/$fileId/download'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      yield response.bodyBytes;
    } else {
      throw CloudProviderException(
        'Failed to download file: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Stream<UploadProgress> uploadFile({
    required String fileName,
    required Stream<List<int>> fileBytes,
    String? parentId,
    String? mimeType,
  }) async* {
    final headers = _getAuthHeaders();
    
    // Process stream incrementally to show real progress
    final allBytes = <int>[];
    var totalBytesReceived = 0;
    int? estimatedTotal;
    
    // First pass: collect bytes and emit progress
    await for (final chunk in fileBytes) {
      allBytes.addAll(chunk);
      totalBytesReceived = allBytes.length;
      
      // For first chunk, we don't know total yet
      estimatedTotal ??= totalBytesReceived;
      
      // Emit progress for each chunk received
      final progressObj = UploadProgress(
        uploaded: totalBytesReceived,
        total: estimatedTotal,
        fileName: fileName,
        status: UploadStatus.uploading,
        speed: chunk.length / 0.05, // Simulate speed based on chunk size
      );
      
      yield progressObj;
      
      // Update estimated total to match current progress for smoother progress bar
      estimatedTotal = math.max(estimatedTotal, totalBytesReceived + 1024); // Always stay ahead
      
      // Add small delay to make progress visible
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    // Now we know the real total size
    final totalBytes = allBytes.length;
    
    // Emit final progress update with correct total
    yield UploadProgress(
      uploaded: totalBytes,
      total: totalBytes,
      fileName: fileName,
      status: UploadStatus.uploading,
    );
    
    // Simulate server processing time
    await Future.delayed(const Duration(milliseconds: 200));
    
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${config.baseUrl}/api/upload'),
    );

    request.headers.addAll(headers);
    
    if (parentId != null) {
      request.fields['parent_id'] = parentId;
    }
    
    if (mimeType != null) {
      request.fields['mime_type'] = mimeType;
    }

    // Create multipart file
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      allBytes,
      filename: fileName,
    );
    
    request.files.add(multipartFile);

    // Send the actual request
    try {
      final response = await request.send();

      if (response.statusCode == 201) {
        yield UploadProgress(
          uploaded: totalBytes,
          total: totalBytes,
          fileName: fileName,
          status: UploadStatus.completed,
        );
      } else {
        yield UploadProgress(
          uploaded: totalBytes,
          total: totalBytes,
          fileName: fileName,
          status: UploadStatus.error,
          error: 'Upload failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      yield UploadProgress(
        uploaded: totalBytes,
        total: totalBytes,
        fileName: fileName,
        status: UploadStatus.error,
        error: 'Upload failed: $e',
      );
    }
  }

  @override
  Future<FileListPage> searchByName({
    required String query,
    String? pageToken,
    int pageSize = 50,
  }) async {
    final headers = _getAuthHeaders();
    final queryParams = <String, String>{
      'q': query,
      'page_size': pageSize.toString(),
    };
    
    if (pageToken != null) queryParams['page_token'] = pageToken;

    final uri = Uri.parse('${config.baseUrl}/api/search').replace(
      queryParameters: queryParams,
    );

    final response = await _httpClient.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final files = (data['files'] as List)
          .map((fileData) => _parseFileEntry(fileData))
          .toList();

      return FileListPage(
        entries: files,
        nextPageToken: data['next_page_token'],
        hasMore: data['has_next_page'] ?? false,
      );
    }

    throw CloudProviderException(
      'Failed to search files: ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  @override
  Future<UserProfile> getUserProfile() async {
    // Custom provider may not have user profiles if it doesn't require account management
    if (!config.showAccountManagement) {
      // Return a mock profile for demo purposes
      return const UserProfile(
        id: 'mock_user',
        name: 'Demo User',
        email: 'demo@example.com',
        photoUrl: null,
      );
    }
    
    // For account-based custom providers, fetch from server
    final headers = _getAuthHeaders();
    final uri = Uri.parse('${config.baseUrl}/api/profile');
    
    final response = await _httpClient.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return UserProfile(
        id: data['id'],
        name: data['name'],
        email: data['email'],
        photoUrl: data['photo_url'],
        metadata: data['metadata'] ?? {},
      );
    }
    
    throw CloudProviderException(
      'Failed to get user profile: ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }
  
  @override
  Future<CloudAccount> refreshAuth(CloudAccount account) async {
    // Custom provider may not need token refresh if it doesn't require account management
    if (!config.showAccountManagement) {
      // Return the same account for non-account-based custom providers
      return account;
    }
    
    // For account-based custom providers, implement token refresh logic
    if (account.refreshToken == null) {
      throw CloudProviderException('No refresh token available');
    }
    
    final headers = {'Content-Type': 'application/json'};
    final body = json.encode({
      'refresh_token': account.refreshToken,
    });
    
    final uri = Uri.parse('${config.baseUrl}/api/auth/refresh');
    final response = await _httpClient.post(uri, headers: headers, body: body);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return account.copyWith(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        expiresAt: data['expires_at'] != null ? 
            DateTime.parse(data['expires_at']) : null,
      );
    }
    
    throw CloudProviderException(
      'Failed to refresh token: ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  Map<String, String> _getAuthHeaders() {
    return {
      'Authorization': 'Bearer dev',
      'Content-Type': 'application/json',
    };
  }

  FileEntry _parseFileEntry(Map<String, dynamic> data) {
    return FileEntry(
      id: data['id'],
      name: data['name'],
      isFolder: data['is_folder'] ?? false,
      size: data['size'] ?? 0,
      modifiedAt: DateTime.parse(data['modified_at']),
      mimeType: data['mime_type'],
      downloadUrl: data['download_url'],
      thumbnailUrl: data['thumbnail_url'],
    );
  }
  
  /// Returns mock file list for demo when no account management
  FileListPage _getMockFileList(String? folderId) {
    final now = DateTime.now();
    
    if (folderId == null) {
      // Root folder - show some sample folders and files
      return FileListPage(
        entries: [
          FileEntry(
            id: 'folder_documents',
            name: 'Documents',
            isFolder: true,
            size: 0,
            modifiedAt: now.subtract(const Duration(days: 2)),
            createdAt: now.subtract(const Duration(days: 30)),
            mimeType: null,
          ),
          FileEntry(
            id: 'folder_images',
            name: 'Images', 
            isFolder: true,
            size: 0,
            modifiedAt: now.subtract(const Duration(days: 1)),
            createdAt: now.subtract(const Duration(days: 15)),
            mimeType: null,
          ),
          FileEntry(
            id: 'file_report',
            name: 'Enterprise Report.pdf',
            isFolder: false,
            size: 2456789,
            modifiedAt: now.subtract(const Duration(hours: 3)),
            createdAt: now.subtract(const Duration(days: 5)),
            mimeType: 'application/pdf',
            downloadUrl: null,
          ),
          FileEntry(
            id: 'file_presentation',
            name: 'Company Presentation.pptx',
            isFolder: false,
            size: 8965432,
            modifiedAt: now.subtract(const Duration(days: 1)),
            createdAt: now.subtract(const Duration(days: 7)),
            mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            downloadUrl: null,
          ),
        ],
        nextPageToken: null,
        hasMore: false,
      );
    } else if (folderId == 'folder_documents') {
      // Documents folder
      return FileListPage(
        entries: [
          FileEntry(
            id: 'doc_policy',
            name: 'Security Policy.docx',
            isFolder: false,
            size: 156789,
            modifiedAt: now.subtract(const Duration(days: 2)),
            createdAt: now.subtract(const Duration(days: 10)),
            mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            downloadUrl: null,
          ),
          FileEntry(
            id: 'doc_manual',
            name: 'User Manual.pdf',
            isFolder: false,
            size: 3456789,
            modifiedAt: now.subtract(const Duration(days: 5)),
            createdAt: now.subtract(const Duration(days: 20)),
            mimeType: 'application/pdf',
            downloadUrl: null,
          ),
        ],
        nextPageToken: null,
        hasMore: false,
      );
    } else if (folderId == 'folder_images') {
      // Images folder
      return FileListPage(
        entries: [
          FileEntry(
            id: 'img_logo',
            name: 'Company Logo.png',
            isFolder: false,
            size: 245678,
            modifiedAt: now.subtract(const Duration(hours: 12)),
            createdAt: now.subtract(const Duration(days: 3)),
            mimeType: 'image/png',
            downloadUrl: null,
          ),
          FileEntry(
            id: 'img_banner',
            name: 'Marketing Banner.jpg',
            isFolder: false,
            size: 567890,
            modifiedAt: now.subtract(const Duration(days: 1)),
            createdAt: now.subtract(const Duration(days: 4)),
            mimeType: 'image/jpeg',
            downloadUrl: null,
          ),
        ],
        nextPageToken: null,
        hasMore: false,
      );
    } else {
      // Empty folder or unknown
      return FileListPage(
        entries: [],
        nextPageToken: null,
        hasMore: false,
      );
    }
  }
}