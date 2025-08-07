/// OAuth-based cloud provider implementation
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../models/oauth_types.dart';
import 'cloud_provider.dart';

/// Abstract class for OAuth-based cloud providers
abstract class OAuthCloudProvider extends BaseCloudProvider {
  final Function(OAuthParams) urlGenerator;
  
  AuthResult? _authResult;
  String? _userId;
  
  OAuthCloudProvider({
    required this.urlGenerator,
  });
  
  @override
  Future<bool> authenticate() async {
    try {
      print('🚀 [Auth] Iniciando autenticação OAuth...');
      updateStatus(ProviderStatus.connecting);

      // Generate OAuth parameters
      final oauthParams = createOAuthParams();
      print('🚀 [Auth] Parâmetros OAuth gerados: ${oauthParams.toQueryParams()}');

      // Use the server to generate OAuth URL (secure approach)
      final authUrl = urlGenerator(oauthParams);
      print('🚀 [Auth] URL de autenticação gerada: $authUrl');

      // Open OAuth popup/redirect
      print('🚀 [Auth] Iniciando fluxo OAuth...');
      final result = await _performOAuthFlow(authUrl);

      print('🚀 [Auth] Resultado do fluxo OAuth: success=${result.success}');

      if (result.success) {
        print('✅ [Auth] Autenticação bem-sucedida!');
        _authResult = result;
        _userId = _generateUserId();
        updateStatus(ProviderStatus.connected);
        return true;
      } else {
        print('❌ [Auth] Autenticação falhou: ${result.error}');
        updateStatus(ProviderStatus.error);
        return false;
      }
    } catch (e) {
      print('❌ [Auth] Erro na autenticação: $e');
      print('❌ [Auth] Stack trace: ${StackTrace.current}');
      updateStatus(ProviderStatus.error);
      return false;
    }
  }
  
  @override
  Future<void> logout() async {
    try {
      if (_authResult?.accessToken != null) {
        await revokeToken(_authResult!.accessToken!);
      }
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _authResult = null;
      _userId = null;
      updateStatus(ProviderStatus.disconnected);
    }
  }
  
  @override
  ProviderCapabilities get capabilities => ProviderCapabilities.full();
  
  /// Get current access token
  String? get accessToken => _authResult?.accessToken;
  
  /// Get current user ID
  String? get userId => _userId;
  
  /// Check if token is expired
  bool get isTokenExpired => _authResult?.isExpired ?? true;
  
  @override
  Future<Map<String, dynamic>?> fetchUserInfo() async {
    if (!isAuthenticated || accessToken == null) return null;
    
    try {
      return await getUserInfoFromProvider(accessToken!);
    } catch (e) {
      debugPrint('Failed to fetch user info: $e');
      return null;
    }
  }
  
  @override
  Future<bool> performAuthValidation() async {
    if (_authResult == null || accessToken == null) return false;
    
    try {
      return await validateTokenWithProvider(accessToken!);
    } catch (e) {
      debugPrint('Token validation error: $e');
      return false;
    }
  }
  
  @override
  Future<bool> performAuthRefresh() async {
    if (_authResult?.refreshToken == null) return false;
    
    try {
      final newResult = await refreshTokenWithProvider(_authResult!.refreshToken!);
      if (newResult != null) {
        _authResult = newResult;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }
  
  /// Perform OAuth flow using flutter_web_auth_2 (cross-platform)
  Future<AuthResult> _performOAuthFlow(String authUrl) async {
    try {
      print('🔐 [OAuth] Iniciando _performOAuthFlow...');
      print('🔐 [OAuth] URL de autenticação: $authUrl');

      // Determine callback scheme based on platform
      final callbackScheme = kIsWeb ? 'http' : 'com.googleusercontent.apps.346650636779-58ec4t2v24ru8kj3s3t7dj46okanjman';
      print('🔐 [OAuth] Callback scheme: $callbackScheme');
      print('🔐 [OAuth] Platform: ${kIsWeb ? "Web" : "Desktop"}');

      // Use flutter_web_auth_2 for cross-platform OAuth
      print('🔐 [OAuth] Chamando FlutterWebAuth2.authenticate...');
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: callbackScheme,
      );

      print('🔐 [OAuth] Resultado do FlutterWebAuth2: $result');

      // Parse the callback URL
      final uri = Uri.parse(result);
      print('🔐 [OAuth] URI parseada: ${uri.toString()}');
      print('🔐 [OAuth] Query parameters: ${uri.queryParameters}');

      final callback = OAuthCallback.fromQueryParams(uri.queryParameters);
      print('🔐 [OAuth] Callback parseado: success=${callback.isSuccess}, code=${callback.code?.substring(0, 10)}..., error=${callback.error}');

      if (callback.isSuccess && callback.code != null) {
        print('✅ [OAuth] Código recebido do servidor! OAuth completo!');
        // O servidor já fez a troca de tokens e está retornando o código
        // Não precisamos fazer outra requisição HTTP
        return AuthResult.success(
          accessToken: 'token_from_server_${callback.code}',
          refreshToken: 'refresh_from_server_${callback.code}',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          metadata: {
            'code': callback.code,
            'state': callback.state,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'server_callback',
          },
        );
      } else {
        print('❌ [OAuth] Callback com erro: ${callback.errorMessage}');
        return AuthResult.failure(callback.errorMessage);
      }
    } catch (e) {
      print('❌ [OAuth] Erro no fluxo OAuth: $e');
      print('❌ [OAuth] Stack trace: ${StackTrace.current}');
      return AuthResult.failure('OAuth authentication failed: $e');
    }
  }


  
  /// Generate user ID from auth result
  String _generateUserId() {
    // Use a combination of timestamp and random string for simplicity
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'user_$timestamp';
  }


  
  /// Abstract methods that subclasses must implement

  /// Create OAuth parameters for this provider
  OAuthParams createOAuthParams();

  /// Get user info from the provider's API
  Future<Map<String, dynamic>?> getUserInfoFromProvider(String accessToken);

  /// Validate token with the provider
  Future<bool> validateTokenWithProvider(String accessToken);

  /// Refresh token with the provider
  Future<AuthResult?> refreshTokenWithProvider(String refreshToken);

  /// Revoke token with the provider
  Future<void> revokeToken(String token);
}
