/// Google Drive provider implementation with file operations
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../storage/token_storage.dart';
import '../../utils/constants.dart';
import '../../models/oauth_types.dart';
import '../../models/cloud_item.dart';
import '../../config/config.dart'; // Configuração OAuth
import '../../models/cloud_file.dart' as models;
import '../../models/cloud_folder.dart' as models;
import '../../models/file_operations.dart';
import '../../models/search_models.dart';
import '../../config/app_config.dart';
import '../../auth/web_auth_client.dart';
import '../base/oauth_cloud_provider.dart';
import '../base/cloud_provider.dart';

/// Google Drive cloud provider implementation
class GoogleDriveProvider extends OAuthCloudProvider {
  static const String scopes = 'https://www.googleapis.com/auth/drive';
  
  GoogleDriveProvider({
    required TokenStorage tokenStorage,
    Function(OAuthParams)? urlGenerator,
    Function(String providerId, String userId)? onTokenDelete,
    WebAuthClient? webAuthClient,
  }) : super(
    tokenStorage: tokenStorage,
    urlGenerator: urlGenerator ?? ((params) => '${AppConfig.serverBaseUrl}${AppConfig.authEndpoint}?state=${params.state}'),
    webAuthClient: webAuthClient ?? const FlutterWebAuthClient(),
    onTokenDelete: onTokenDelete,
  );
  
  @override
  String get providerId => 'google_drive';
  
  @override
  String get providerName => ProviderNames.googleDrive;
  
  @override
  String get providerIcon => 'assets/icons/google_drive.svg';
  
  @override
  Color get providerColor => Color(UIConstants.providerColors['Google Drive']!);

  @override
  ProviderCapabilities get capabilities => ProviderCapabilities.full();

  @override
  OAuthParams createOAuthParams() {
    return OAuthParams(
      clientId: OAuthConfig.clientId, // Usar configuração OAuth
      redirectUri: '${AppConfig.serverBaseUrl}/auth/callback',
      scopes: [scopes],
      state: _generateState(),
    );
  }

  @override
  Future<Map<String, dynamic>?> getUserInfoFromProvider(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
  }

  @override
  Future<bool> validateTokenWithProvider(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=$accessToken'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AuthResult?> refreshTokenWithProvider(String refreshToken) async {
    try {
      // Frontend não faz refresh direto! Chama o servidor que faz o refresh
      final response = await http.post(
        Uri.parse('${AppConfig.serverBaseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AuthResult.success(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'] ?? refreshToken,
          expiresAt: DateTime.now().add(Duration(seconds: data['expires_in'] ?? 3600)),
        );
      }
      return null;
    } catch (e) {
      print('Error refreshing token: $e');
      return null;
    }
  }

  @override
  Future<void> revokeToken(String accessToken) async {
    try {
      // Frontend não revoga direto! Chama o servidor que faz o revoke
      await http.post(
        Uri.parse('${AppConfig.serverBaseUrl}/auth/revoke'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': accessToken}),
      );
    } catch (e) {
      print('Error revoking token: $e');
    }
  }

  /// Generate a random state parameter for OAuth
  String _generateState() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'state_${random}_${List.generate(8, (index) => chars[random % chars.length]).join()}';
  }

  // File Operations Implementation

  @override
  Future<List<CloudItem>> listItems(String? folderId) async {
    final token = await getValidTokenForApi();
    if (token == null) throw Exception('Not authenticated');

    try {
      print('🔍 [API] Listando itens no folder: $folderId');
      print('🔍 [API] Folder ID: ${folderId ?? "root"}');

      // Build query for Google Drive API
      final query = folderId != null 
          ? "'$folderId' in parents and trashed=false"
          : "'root' in parents and trashed=false";

      print('🔍 [API] Query: $query');

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files?'
            'q=${Uri.encodeQueryComponent(query)}&'
            'fields=files(id,name,mimeType,size,createdTime,modifiedTime,parents,thumbnailLink,webViewLink)'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [API] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> files = data['files'] ?? [];
        
        print('✅ [API] ${files.length} itens encontrados');
        return files.map((file) => _mapToCloudItem(file)).toList();
      } else {
        // Handle API errors gracefully
        final handled = await handleApiError(response.statusCode, response.body, 'list files');
        if (handled) {
          // Return empty list instead of throwing exception for permission issues
          print('⚠️ [API] Permission issues detected - returning empty list');
          return [];
        } else {
          // For other errors, still throw
          throw Exception('Failed to list items: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      print('❌ [API] Error listing items: $e');
      rethrow;
    }
  }

  @override
  Future<models.CloudFolder> createFolder(String name, String? parentId) async {
    if (!isAuthenticated) throw Exception('Not authenticated');
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) throw Exception('No valid access token');

      final metadata = {
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        if (parentId != null) 'parents': [parentId],
      };

      final response = await http.post(
        Uri.parse('https://www.googleapis.com/drive/v3/files'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(metadata),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _mapToCloudFolder(data);
      } else {
        throw Exception('Failed to create folder: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating folder: $e');
      rethrow;
    }
  }

  @override
  Stream<UploadProgress> uploadFile(FileUpload fileUpload) async* {
    if (!isAuthenticated) throw Exception('Not authenticated');
    
    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) throw Exception('No valid access token');

      yield UploadProgress(
        uploadId: uploadId,
        fileName: fileUpload.fileName,
        bytesUploaded: 0,
        totalBytes: fileUpload.fileSize,
        status: UploadStatus.pending,
      );

      // Read file bytes
      final fileBytes = await fileUpload.file.readAsBytes();
      final totalBytes = fileBytes.length;

      yield UploadProgress(
        uploadId: uploadId,
        fileName: fileUpload.fileName,
        bytesUploaded: 0,
        totalBytes: totalBytes,
        status: UploadStatus.uploading,
      );

      // Prepare metadata
      final metadata = {
        'name': fileUpload.fileName,
        if (fileUpload.parentFolderId != null) 'parents': [fileUpload.parentFolderId!],
      };

      // For simplicity, using simple upload (resumable upload would be better for large files)
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
      );
      
      request.headers['Authorization'] = 'Bearer ${token.accessToken}';
      request.files.add(http.MultipartFile(
        'metadata',
        Stream.value(utf8.encode(jsonEncode(metadata))),
        utf8.encode(jsonEncode(metadata)).length,
        contentType: MediaType('application', 'json'),
      ));
      request.files.add(http.MultipartFile(
        'media',
        Stream.value(fileBytes),
        fileBytes.length,
        contentType: MediaType.parse(fileUpload.mimeType),
      ));

      final streamedResponse = await request.send();
      
      // Simulate progress updates
      var bytesUploaded = 0;
      final chunkSize = totalBytes ~/ 10; // 10 progress updates
      
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(Duration(milliseconds: 100));
        bytesUploaded = (i * chunkSize).clamp(0, totalBytes);
        
        yield UploadProgress(
          uploadId: uploadId,
          fileName: fileUpload.fileName,
          bytesUploaded: bytesUploaded,
          totalBytes: totalBytes,
          status: UploadStatus.uploading,
        );
      }

      if (streamedResponse.statusCode == 200) {
        yield UploadProgress(
          uploadId: uploadId,
          fileName: fileUpload.fileName,
          bytesUploaded: totalBytes,
          totalBytes: totalBytes,
          status: UploadStatus.completed,
        );
      } else {
        // Handle API errors gracefully
        final responseBody = await streamedResponse.stream.bytesToString();
        final handled = await handleApiError(streamedResponse.statusCode, responseBody, 'upload file');
        if (!handled) {
          throw Exception('Upload failed: ${streamedResponse.statusCode}');
        }
        // If handled (permission issue), we still throw but with different message
        throw Exception('Upload failed due to permission issues: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      yield UploadProgress(
        uploadId: uploadId,
        fileName: fileUpload.fileName,
        bytesUploaded: 0,
        totalBytes: fileUpload.fileSize,
        status: UploadStatus.failed,
        error: e.toString(),
      );
    }
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    if (!isAuthenticated) throw Exception('Not authenticated');
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) throw Exception('No valid access token');

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading file: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    if (!isAuthenticated) throw Exception('Not authenticated');
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) throw Exception('No valid access token');

      final response = await http.delete(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$itemId'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete item: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting item: $e');
      rethrow;
    }
  }

  @override
  Future<void> moveItem(String itemId, String newParentId) async {
    if (!isAuthenticated) throw Exception('Not authenticated');
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) throw Exception('No valid access token');

      // First get current parents
      final getResponse = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$itemId?fields=parents'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
        },
      );

      if (getResponse.statusCode != 200) {
        throw Exception('Failed to get current parents: ${getResponse.statusCode}');
      }

      final data = jsonDecode(getResponse.body);
      final currentParents = (data['parents'] as List?)?.join(',') ?? '';

      // Update parents
      final response = await http.patch(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$itemId?'
            'addParents=$newParentId&'
            'removeParents=$currentParents'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to move item: ${response.statusCode}');
      }
    } catch (e) {
      print('Error moving item: $e');
      rethrow;
    }
  }

  @override
  Future<void> renameItem(String itemId, String newName) async {
    if (!isAuthenticated) throw Exception('Not authenticated');
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) throw Exception('No valid access token');

      final response = await http.patch(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$itemId'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': newName}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to rename item: ${response.statusCode}');
      }
    } catch (e) {
      print('Error renaming item: $e');
      rethrow;
    }
  }

  @override
  Future<List<CloudItem>> searchItems(SearchQuery query) async {
    if (!isAuthenticated) throw Exception('Not authenticated');
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) throw Exception('No valid access token');

      // Build Google Drive search query
      var driveQuery = "trashed=false";
      
      if (query.query.isNotEmpty) {
        driveQuery += " and name contains '${query.query}'";
      }
      
      if (query.folderId != null) {
        driveQuery += " and '${query.folderId}' in parents";
      }

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files?'
            'q=${Uri.encodeQueryComponent(driveQuery)}&'
            'pageSize=${query.maxResults}&'
            'fields=files(id,name,mimeType,size,createdTime,modifiedTime,parents,thumbnailLink,webViewLink)'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> files = data['files'] ?? [];
        
        var items = files.map((file) => _mapToCloudItem(file)).toList();
        
        // Apply local filtering and sorting
        items = _applyQueryFilters(items, query);
        items = _applySorting(items, query.sortBy);
        
        return items;
      } else {
        throw Exception('Failed to search items: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching items: $e');
      rethrow;
    }
  }

  @override
  Future<CloudItem?> getItemById(String itemId) async {
    if (!isAuthenticated) throw Exception('Not authenticated');
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) throw Exception('No valid access token');

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$itemId?'
            'fields=id,name,mimeType,size,createdTime,modifiedTime,parents,thumbnailLink,webViewLink'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _mapToCloudItem(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to get item: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting item: $e');
      rethrow;
    }
  }

  @override
  Future<List<models.CloudFolder>> getFolderPath(String? folderId) async {
    if (!isAuthenticated) throw Exception('Not authenticated');
    if (folderId == null) return [];
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) throw Exception('No valid access token');

      final List<models.CloudFolder> path = [];
      String? currentId = folderId;

      while (currentId != null && currentId != 'root') {
        final response = await http.get(
          Uri.parse('https://www.googleapis.com/drive/v3/files/$currentId?'
              'fields=id,name,parents,createdTime,modifiedTime'),
          headers: {
            'Authorization': 'Bearer ${token.accessToken}',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          path.insert(0, _mapToCloudFolder(data));
          
          final parents = data['parents'] as List?;
          currentId = parents?.isNotEmpty == true ? parents!.first : null;
        } else {
          break;
        }
      }

      return path;
    } catch (e) {
      print('Error getting folder path: $e');
      return [];
    }
  }

  // Helper methods

  CloudItem _mapToCloudItem(Map<String, dynamic> driveItem) {
    final id = driveItem['id'] as String;
    final name = driveItem['name'] as String;
    final mimeType = driveItem['mimeType'] as String;
    final parentId = (driveItem['parents'] as List?)?.first;
    final createdTime = DateTime.parse(driveItem['createdTime']);
    final modifiedTime = DateTime.parse(driveItem['modifiedTime']);

    if (mimeType == 'application/vnd.google-apps.folder') {
      return models.CloudFolder(
        id: id,
        name: name,
        parentId: parentId,
        createdAt: createdTime,
        modifiedAt: modifiedTime,
        permissions: FolderPermissions(
          canRead: true,
          canWrite: true,
          canDelete: true,
          canCreateFiles: true,
          canCreateFolders: true,
        ),
      );
    } else {
      final sizeStr = driveItem['size'] as String?;
      final size = sizeStr != null ? int.tryParse(sizeStr) ?? 0 : 0;
      
      return models.CloudFile(
        id: id,
        name: name,
        parentId: parentId,
        createdAt: createdTime,
        modifiedAt: modifiedTime,
        size: size,
        mimeType: mimeType,
        thumbnailUrl: driveItem['thumbnailLink'],
        downloadUrl: driveItem['webViewLink'],
        permissions: FilePermissions(
          canRead: true,
          canWrite: true,
          canDelete: true,
          canShare: true,
        ),
      );
    }
  }

  models.CloudFolder _mapToCloudFolder(Map<String, dynamic> driveItem) {
    return models.CloudFolder(
      id: driveItem['id'],
      name: driveItem['name'],
      parentId: (driveItem['parents'] as List?)?.first,
      createdAt: DateTime.parse(driveItem['createdTime']),
      modifiedAt: DateTime.parse(driveItem['modifiedTime']),
      permissions: FolderPermissions(
        canRead: true,
        canWrite: true,
        canDelete: true,
        canCreateFiles: true,
        canCreateFolders: true,
      ),
    );
  }

  List<CloudItem> _applyQueryFilters(List<CloudItem> items, SearchQuery query) {
    var filtered = items;

    // Filter by file types
    if (query.fileTypes.isNotEmpty) {
      filtered = filtered.where((item) {
        if (item is models.CloudFile) {
          return query.fileTypes.contains(item.mimeType);
        }
        return item.type == CloudItemType.folder; // Keep folders
      }).toList();
    }

    // Filter by date range
    if (query.dateRange != null) {
      filtered = filtered.where((item) {
        return query.dateRange!.contains(item.modifiedAt);
      }).toList();
    }

    // Filter by size range
    if (query.sizeRange != null) {
      filtered = filtered.where((item) {
        if (item is models.CloudFile) {
          return query.sizeRange!.contains(item.size);
        }
        return true; // Keep folders
      }).toList();
    }

    return filtered;
  }

  List<CloudItem> _applySorting(List<CloudItem> items, SortOption sortBy) {
    switch (sortBy) {
      case SortOption.nameAsc:
        items.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.nameDesc:
        items.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortOption.dateAsc:
        items.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
        break;
      case SortOption.dateDesc:
        items.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
      case SortOption.sizeAsc:
        items.sort((a, b) {
          if (a is models.CloudFile && b is models.CloudFile) {
            return a.size.compareTo(b.size);
          }
          return 0;
        });
        break;
      case SortOption.sizeDesc:
        items.sort((a, b) {
          if (a is models.CloudFile && b is models.CloudFile) {
            return b.size.compareTo(a.size);
          }
          return 0;
        });
        break;
      case SortOption.typeAsc:
        items.sort((a, b) => a.type.toString().compareTo(b.type.toString()));
        break;
      case SortOption.typeDesc:
        items.sort((a, b) => b.type.toString().compareTo(a.type.toString()));
        break;
    }
    return items;
  }


  @override
  Future<bool> performAuthValidation() async {
    final token = await getValidTokenForApi();
    if (token?.accessToken == null) return false;
    return await validateTokenWithProvider(token!.accessToken!);
  }

  @override
  Future<bool> performAuthRefresh() async {
    return await refreshAccessToken();
  }

  /// Additional Google Drive specific methods
  
  /// Get Drive quota information
  Future<Map<String, dynamic>?> getDriveQuota() async {
    if (!isAuthenticated) return null;
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) return null;
      
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/about?fields=storageQuota'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['storageQuota'];
      }
      return null;
    } catch (e) {
      print('Error fetching drive quota: $e');
      return null;
    }
  }
  
  /// Test connection to Google Drive
  Future<bool> testConnection() async {
    if (!isAuthenticated) return false;
    
    try {
      final token = await getValidTokenForApi();
      if (token == null) return false;
      
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files?pageSize=1'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'Content-Type': 'application/json',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error testing connection: $e');
      return false;
    }
  }
  
  /// Get provider-specific information
  Map<String, dynamic> getProviderInfo() {
    return {
      'name': providerName,
      'type': 'oauth',
      'scopes': [scopes],
      'authenticated': isAuthenticated,
      'status': status.name,
      'hasCloudService': isAuthenticated,
      'capabilities': {
        'upload': capabilities.supportsUpload,
        'download': capabilities.supportsDownload,
        'delete': capabilities.supportsDelete,
        'search': capabilities.supportsSearch,
        'sharing': capabilities.supportsSharing,
      },
    };
  }
  
  /// Check if error indicates permission issues and mark account accordingly
  @override
  bool hasRequiredScopes(String grantedScopes) {
    final scopes = grantedScopes.split(' ');
    
    // Check if we have full drive access
    if (scopes.contains('https://www.googleapis.com/auth/drive')) {
      print('✅ [Scopes] Acesso completo ao Drive detectado');
      return true;
    }
    
    // Check for file-specific access (minimum requirement)
    if (scopes.contains('https://www.googleapis.com/auth/drive.file')) {
      print('⚠️ [Scopes] Apenas acesso a arquivos específicos - funcionalidade limitada');
      return true; // Still usable but limited
    }
    
    if (scopes.contains('https://www.googleapis.com/auth/drive.readonly')) {
      print('⚠️ [Scopes] Apenas acesso de leitura - funcionalidade limitada');
      return true; // Read-only access
    }
    
    print('❌ [Scopes] Scopes insuficientes detectados. Disponível: $grantedScopes');
    print('❌ [Scopes] Necessário pelo menos: drive.file ou drive.readonly');
    return false;
  }
}
