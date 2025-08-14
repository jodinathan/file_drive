import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/file_entry.dart';
import '../models/provider_capabilities.dart';
import 'base_cloud_provider.dart';

/// Provider que conecta ao servidor local para testes (sem autenticação)
class LocalServerProvider extends BaseCloudProvider {
  static const String providerId = 'local_server';
  static const String providerName = 'Local Server';
  
  final String serverUrl;
  final String testToken;
  
  LocalServerProvider({
    this.serverUrl = 'http://localhost:8080',
    this.testToken = 'test_token_dev',
  });
  
  @override
  String get providerType => providerId;
  
  @override
  String get displayName => providerName;
  
  @override
  String? get logoAssetPath => null; // Uses icon fallback
  
  @override
  bool get requiresAccountManagement => false; // 🔑 No account management needed
  
  @override
  ProviderCapabilities getCapabilities() {
    return ProviderCapabilities(
      canUpload: true,
      canCreateFolders: true,
      canDelete: true,
      canSearch: false, // Simplified for now
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
    final queryParams = <String, String>{};
    if (folderId != null) {
      queryParams['folder'] = folderId;
    }
    if (pageToken != null) {
      queryParams['page_token'] = pageToken;
    }
    
    final uri = Uri.parse('$serverUrl/api/files').replace(queryParameters: queryParams);
    final response = await _makeRequest('GET', uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : ''));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final files = (data['files'] as List)
          .map((file) => FileEntry.fromJson(file))
          .toList();
      
      return FileListPage(
        entries: files,
        nextPageToken: (data['has_next_page'] as bool? ?? false) ? 'next' : null,
        hasMore: data['has_next_page'] as bool? ?? false,
      );
    } else {
      throw CloudProviderException(
        'Failed to list files: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
  
  @override
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  }) async {
    final body = json.encode({
      'name': name,
      'parent_id': parentId,
      'metadata': {},
    });
    
    final response = await _makeRequest(
      'POST',
      '/api/folders',
      body: body,
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return FileEntry.fromJson(data);
    } else {
      throw CloudProviderException(
        'Failed to create folder: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
  
  @override
  Future<void> deleteEntry({
    required String entryId,
    bool permanent = false,
  }) async {
    final response = await _makeRequest('DELETE', '/api/files/$entryId');
    
    if (response.statusCode != 204) {
      throw CloudProviderException(
        'Failed to delete entry: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
  
  @override
  Stream<List<int>> downloadFile({
    required String fileId,
  }) async* {
    print('📥 LocalServerProvider.downloadFile called with fileId: "$fileId"');
    print('📥 FileId type: ${fileId.runtimeType}');
    print('📥 FileId length: ${fileId.length}');
    print('📥 FileId bytes: ${fileId.codeUnits}');
    
    final response = await _makeRequest('GET', '/api/download/$fileId');
    
    if (response.statusCode == 200) {
      print('✅ Download successful for fileId: "$fileId"');
      yield response.bodyBytes;
    } else {
      print('❌ Download failed for fileId: "$fileId" - Status: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
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
    // Convert stream to bytes
    final List<int> allBytes = [];
    await for (final chunk in fileBytes) {
      allBytes.addAll(chunk);
    }
    
    final totalSize = allBytes.length;
    
    // Emit starting progress
    yield UploadProgress.starting(fileName: fileName, total: totalSize);
    
    try {
      final queryParams = <String, String>{
        'file_name': fileName,
      };
      if (parentId != null) {
        queryParams['parent_id'] = parentId;
      }
      
      final uri = Uri.parse('$serverUrl/api/upload').replace(queryParameters: queryParams);
      
      final request = http.Request('POST', uri);
      request.headers['Authorization'] = 'Bearer $testToken';
      request.bodyBytes = allBytes;
      
      // Emit progress during upload (simplified)
      yield UploadProgress(
        uploaded: totalSize ~/ 2,
        total: totalSize,
        fileName: fileName,
        status: UploadStatus.uploading,
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201) {
        // Emit completion progress
        yield UploadProgress.completed(
          fileName: fileName,
          total: totalSize,
          startTime: DateTime.now().subtract(Duration(seconds: 1)),
        );
      } else {
        yield UploadProgress.error(
          fileName: fileName,
          total: totalSize,
          error: 'Upload failed: ${response.statusCode}',
          startTime: DateTime.now().subtract(Duration(seconds: 1)),
          uploaded: 0,
        );
      }
    } catch (e) {
      yield UploadProgress.error(
        fileName: fileName,
        total: totalSize,
        error: 'Upload failed: $e',
        startTime: DateTime.now().subtract(Duration(seconds: 1)),
        uploaded: 0,
      );
    }
  }
  
  @override
  Future<FileListPage> searchByName({
    required String query,
    String? pageToken,
    int pageSize = 50,
  }) async {
    // Simplified implementation - search not implemented on server
    throw CloudProviderException('Search not implemented for local server');
  }
  
  // Helper methods
  
  Future<http.Response> _makeRequest(
    String method,
    String path, {
    String? body,
    Map<String, String>? headers,
  }) async {
    print('🌐 Making $method request to path: "$path"');
    print('🌐 Path bytes: ${path.codeUnits}');
    
    final uri = Uri.parse('$serverUrl$path');
    print('🌐 Final URI: "$uri"');
    print('🌐 URI path: "${uri.path}"');
    print('🌐 URI path bytes: ${uri.path.codeUnits}');
    
    final requestHeaders = {
      'Authorization': 'Bearer $testToken', // Uses test token directly
      ...?headers,
    };
    
    switch (method.toUpperCase()) {
      case 'GET':
        return await http.get(uri, headers: requestHeaders);
      case 'POST':
        return await http.post(uri, headers: requestHeaders, body: body);
      case 'DELETE':
        return await http.delete(uri, headers: requestHeaders);
      case 'PUT':
        return await http.put(uri, headers: requestHeaders, body: body);
      default:
        throw CloudProviderException('Unsupported HTTP method: $method');
    }
  }
}