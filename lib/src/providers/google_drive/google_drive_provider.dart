/// Google Drive provider implementation
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_cloud_storage/fl_cloud_storage.dart';

import '../../models/oauth_types.dart';
import '../../utils/constants.dart';
import '../base/oauth_cloud_provider.dart';

/// Google Drive cloud provider implementation
class GoogleDriveProvider extends OAuthCloudProvider {
  CloudStorageService? _cloudService;
  
  GoogleDriveProvider({
    Function(OAuthParams)? urlGenerator,
  }) : super(
    // Frontend só chama o servidor - URL simples
    urlGenerator: urlGenerator ?? ((params) => '${ServerConfig.baseUrl}${ServerConfig.authEndpoint}?state=${params.state}'),
  );
  
  @override
  String get providerName => ProviderNames.googleDrive;
  
  @override
  String get providerIcon => 'assets/icons/google_drive.svg';
  
  @override
  Color get providerColor => Color(UIConstants.providerColors['Google Drive']!);
  
  @override
  OAuthParams createOAuthParams() {
    // ❌ FRONTEND NÃO PRECISA GERAR PARÂMETROS OAUTH!
    // O servidor que faz isso. Frontend só chama o servidor.

    return OAuthParams(
      clientId: '', // Servidor que tem isso
      redirectUri: '', // Servidor que define isso
      scopes: [], // Servidor que define isso
      state: _generateState(), // Só o state é gerado aqui
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
      print('Error fetching user info: $e');
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
      print('Error validating token: $e');
      return false;
    }
  }
  
  @override
  Future<AuthResult?> refreshTokenWithProvider(String refreshToken) async {
    try {
      // ❌ FRONTEND NÃO DEVE FAZER REFRESH DIRETO!
      // Deve chamar o servidor que faz o refresh
      final response = await http.post(
        Uri.parse('${ServerConfig.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AuthResult.success(
          accessToken: data['access_token'],
          refreshToken: refreshToken, // Keep the same refresh token
          expiresAt: DateTime.now().add(Duration(seconds: data['expires_in'])),
          metadata: data,
        );
      }
      return null;
    } catch (e) {
      print('Error refreshing token: $e');
      return null;
    }
  }
  
  @override
  Future<void> revokeToken(String token) async {
    try {
      // ❌ FRONTEND NÃO DEVE REVOGAR DIRETO!
      // Deve chamar o servidor que faz o revoke
      await http.post(
        Uri.parse('${ServerConfig.baseUrl}/auth/revoke'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
    } catch (e) {
      debugPrint('Error revoking token: $e');
    }
  }
  
  /// Initialize cloud storage service
  Future<void> _initializeCloudService() async {
    if (_cloudService == null && accessToken != null) {
      try {
        _cloudService = await CloudStorageService.initialize(
          StorageType.GOOGLE_DRIVE,
          cloudStorageConfig: GoogleDriveScope.full,
        );
      } catch (e) {
        print('Error initializing cloud service: $e');
      }
    }
  }
  
  /// Get cloud storage service instance
  Future<CloudStorageService?> getCloudService() async {
    await _initializeCloudService();
    return _cloudService;
  }
  
  /// Check if cloud service is available
  bool get hasCloudService => _cloudService != null;
  
  /// Generate random state for OAuth
  String _generateState() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'state_$timestamp';
  }
  
  @override
  void dispose() {
    _cloudService = null;
    super.dispose();
  }
  
  /// Additional Google Drive specific methods
  
  /// Get Drive quota information
  Future<Map<String, dynamic>?> getDriveQuota() async {
    if (!isAuthenticated || accessToken == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/about?fields=storageQuota'),
        headers: {
          'Authorization': 'Bearer $accessToken',
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
    if (!isAuthenticated || accessToken == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files?pageSize=1'),
        headers: {
          'Authorization': 'Bearer $accessToken',
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
      'scopes': ['drive.file'], // Informativo apenas
      'authenticated': isAuthenticated,
      'status': status.name,
      'hasCloudService': hasCloudService,
      'capabilities': {
        'upload': capabilities.supportsUpload,
        'download': capabilities.supportsDownload,
        'delete': capabilities.supportsDelete,
        'search': capabilities.supportsSearch,
        'sharing': capabilities.supportsSharing,
      },
    };
  }
}
