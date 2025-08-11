import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../utils/constants.dart';
import '../../models/oauth_types.dart';
import '../../storage/token_storage.dart';
import '../../config/config.dart';
import '../../auth/web_auth_client.dart';
import '../../models/cloud_account.dart';
import 'cloud_provider.dart';

/// Abstract class for OAuth-based cloud providers
abstract class OAuthCloudProvider extends BaseCloudProvider {
  final Function(OAuthParams) urlGenerator;
  final TokenStorage tokenStorage;
  final WebAuthClient webAuthClient;
  final Function(String providerId, String userId)? onTokenDelete;
  
  AuthResult? _authResult;
  String? _userId;
  String? _activeUserId;
  bool _needsReauth = false;

  OAuthCloudProvider({
    required this.urlGenerator,
    required this.tokenStorage,
    this.webAuthClient = const FlutterWebAuthClient(),
    this.onTokenDelete,
  });

  /// Get provider unique identifier
  String get providerId;

  /// Get current user info for display
  Future<CloudAccount?> getCurrentUserInfo() async {
  if (_activeUserId == null) return null;

  final token = await tokenStorage.getToken(providerId, _activeUserId!);
  if (token == null) return null;

  AccountStatus status = token.hasPermissionIssues || token.needsReauth 
      ? AccountStatus.needsReauth 
      : AccountStatus.active;

  String? name = token.userName;
  String? email = token.userEmail;
  String? picture = token.userPicture;

  if (token.accessToken != null && !token.isExpired) {
    try {
      final userInfo = await getUserInfoFromProvider(token.accessToken!);
      name = userInfo?['name'] ?? name;
      email = userInfo?['email'] ?? email;
      picture = userInfo?['picture'] ?? picture;
    } catch (e) {
      status = AccountStatus.error;
    }
  }

  name ??= 'Usuário';
  email ??= '...';

  return CloudAccount(
    id: _activeUserId!,
    name: name,
    email: email,
    photoUrl: picture,
    status: status,
    isActive: true,
  );
}

  /// Get all available users for this provider
  Future<List<CloudAccount>> getAllUsers() async {
  final tokens = await tokenStorage.getAllTokens(providerId);
  final users = <CloudAccount>[];

  for (final entry in tokens.entries) {
    final userId = entry.key;
    final token = entry.value;

    AccountStatus status = (token.hasPermissionIssues || token.needsReauth) 
        ? AccountStatus.needsReauth 
        : AccountStatus.active;

    String? name = token.userName;
    String? email = token.userEmail;
    String? picture = token.userPicture;

    if (token.accessToken != null && !token.isExpired) {
      try {
        final userInfo = await getUserInfoFromProvider(token.accessToken!);
        if (userInfo != null) {
          final updatedToken = token.copyWithUserInfo(
            userName: userInfo['name'],
            userEmail: userInfo['email'],
            userPicture: userInfo['picture'],
          );
          await tokenStorage.storeToken(providerId, userId, updatedToken);
          name = userInfo['name'];
          email = userInfo['email'];
          picture = userInfo['picture'];
        }
      } catch (e) {
        status = AccountStatus.error;
      }
    }

    name ??= 'Usuário Desconhecido';
    email ??= 'Não disponível';

    users.add(CloudAccount(
      id: userId,
      name: name,
      email: email,
      photoUrl: picture,
      status: status,
      isActive: userId == _activeUserId,
    ));
  }

  return users;
}

  /// Switch to a different user
  Future<bool> switchToUser(String userId) async {
    print('🔄 [Switch] Iniciando switchToUser para: $userId');
    print('🔄 [Switch] Chamando tokenStorage.getToken...');
    final token = await tokenStorage.getToken(providerId, userId);
    if (token == null) {
      print('❌ [Switch] Token não encontrado para usuário: $userId');
      return false;
    }
    
    // Accept tokens even if they have permission issues (need reauth)
    // Only reject if completely invalid (no access token)
    if (token.accessToken?.isEmpty ?? true) {
      print('❌ [Switch] Token inválido (accessToken vazio) para usuário: $userId');
      return false;
    }
    
    print('✅ [Switch] Token válido encontrado para usuário: $userId');
    print('✅ [Switch] Token: success=${token.success}, hasPermissionIssues=${token.hasPermissionIssues}, needsReauth=${token.needsReauth}');
    
    _authResult = token;
    _userId = userId;
    _activeUserId = userId;
    _needsReauth = token.needsReauth || token.hasPermissionIssues;
    
    print('🔄 [Switch] Chamando tokenStorage.setActiveUser...');
    await tokenStorage.setActiveUser(providerId, userId);
    
    // Update status based on permission issues
    if (_needsReauth) {
      print('⚠️ [Switch] Usuário carregado com necessidade de reauth: $userId');
      updateStatus(ProviderStatus.needsReauth);
    } else {
      print('✅ [Switch] Usuário carregado com sucesso: $userId');
      updateStatus(ProviderStatus.connected);
    }
    
    return true;
  }

  /// Delete a user token
  Future<void> deleteUser(String userId) async {
    await tokenStorage.removeToken(providerId, userId);
    
    // If this was the active user, clear it
    if (_activeUserId == userId) {
      _authResult = null;
      _userId = null;
      _activeUserId = null;
      await tokenStorage.clearActiveUser(providerId);
      updateStatus(ProviderStatus.disconnected);
    }
    
    // Call optional delete callback
    onTokenDelete?.call(providerId, userId);
  }

  /// Initialize provider by loading stored tokens
  Future<void> initializeFromStorage() async {
    print('🔄 [Init] Inicializando provider a partir do armazenamento...');
    print('🔄 [Init] ProviderId: $providerId');
    
    // Try to get the active user
    print('🔄 [Init] Chamando tokenStorage.getActiveUser...');
    final activeUserId = await tokenStorage.getActiveUser(providerId);
    print('🔄 [Init] Usuário ativo armazenado: $activeUserId');
    
    if (activeUserId != null) {
      print('🔄 [Init] Chamando switchToUser para usuário ativo...');
      final success = await switchToUser(activeUserId);
      print('🔄 [Init] Carregamento do usuário ativo: $success');
      if (!success) {
        // Active user token is invalid, try to find any valid token
        print('🔄 [Init] Usuário ativo inválido, procurando outros tokens...');
        print('🔄 [Init] Chamando tokenStorage.getAllTokens...');
        final tokens = await tokenStorage.getAllTokens(providerId);
        print('🔄 [Init] Tokens encontrados: ${tokens.keys.toList()}');
        
        for (final entry in tokens.entries) {
          // Accept any token that has an access token, even with permission issues
          if ((entry.value.accessToken?.isNotEmpty ?? false) && !entry.value.isExpired) {
            print('🔄 [Init] Tentando carregar usuário: ${entry.key}');
            final switched = await switchToUser(entry.key);
            if (switched) {
              print('✅ [Init] Usuário carregado com sucesso: ${entry.key}');
              break;
            }
          }
        }
      }
    } else {
      print('🔄 [Init] Nenhum usuário ativo, procurando tokens salvos...');
      print('🔄 [Init] Chamando tokenStorage.getAllTokens...');
      final tokens = await tokenStorage.getAllTokens(providerId);
      print('🔄 [Init] Tokens encontrados: ${tokens.keys.toList()}');
      
      // Se encontrar qualquer token, mesmo com permission issues, tenta carregar
      for (final entry in tokens.entries) {
        // Accept any token that has an access token, even with permission issues
        if ((entry.value.accessToken?.isNotEmpty ?? false) && !entry.value.isExpired) {
          print('🔄 [Init] Tentando carregar usuário: ${entry.key}');
          final switched = await switchToUser(entry.key);
          if (switched) {
            print('✅ [Init] Usuário carregado com sucesso: ${entry.key}');
            break;
          }
        } else {
          print('⚠️ [Init] Token rejeitado para usuário ${entry.key}: accessToken vazio ou expirado');
          print('⚠️ [Init] AccessToken presente: ${(entry.value.accessToken?.isNotEmpty ?? false)}, Expirado: ${entry.value.isExpired}');
        }
      }
      
      // Se não conseguiu carregar nenhum token, vamos forçar a criação de um provider
      // com base no primeiro token com permission issues encontrado
      if (status == ProviderStatus.disconnected && tokens.isNotEmpty) {
        final firstToken = tokens.entries.first;
        print('🔄 [Init] Nenhum token carregado, mas tokens existem. Forçando carregamento do primeiro...');
        print('🔄 [Init] Primeiro token: userId=${firstToken.key}, hasPermissionIssues=${firstToken.value.hasPermissionIssues}');
        
        if (firstToken.value.hasPermissionIssues) {
          // Força carregamento do token com problema de permissão
          _authResult = firstToken.value;
          _userId = firstToken.key;
          _activeUserId = firstToken.key;
          _needsReauth = true;
          
          await tokenStorage.setActiveUser(providerId, firstToken.key);
          updateStatus(ProviderStatus.needsReauth);
          print('✅ [Init] Token com problema de permissão carregado à força: ${firstToken.key}');
        }
      }
    }
    
    print('🔄 [Init] Inicialização concluída. Status final: $status');
  }

  @override
  Future<bool> authenticate() async {
    try {
      print('🚀 [Auth] Iniciando autenticação OAuth...');
      
      updateStatus(ProviderStatus.connecting);
      
      final params = createOAuthParams();
      final authUrl = urlGenerator(params);
      
      print('🚀 [Auth] Parâmetros OAuth gerados: ${params.toQueryParams()}');
      print('🚀 [Auth] URL de autenticação gerada: $authUrl');
      print('🚀 [Auth] Iniciando fluxo OAuth...');
      
      var result = await _performOAuthFlow(authUrl);
// Fetch user info after successful auth
if (result.success) {
  final userInfo = await getUserInfoFromProvider(result.accessToken!);
  if (userInfo != null) {
    result = result.copyWithUserInfo(
      userName: userInfo['name'],
      userEmail: userInfo['email'],
      userPicture: userInfo['picture'],
    );
  }
}

// Then store
      print('🚀 [Auth] Resultado do fluxo OAuth: success=${result.success}');

      if (result.success || result.hasPermissionIssues) {
        // Store token even if it has permission issues
        // This ensures the user account is saved and listed
        if (result.success) {
          print('✅ [Auth] Autenticação bem-sucedida!');
        } else {
          print('⚠️ [Auth] Autenticação bem-sucedida mas com problemas de permissão!');
        }
        
        _authResult = result;
        
        // Generate or get user ID from token metadata
        _userId = result.metadata['user_id']?.toString() ?? _generateUserId();
        _activeUserId = _userId;
        
        // Store the token
        print('💾 [Auth] Chamando tokenStorage.storeToken...');
        await tokenStorage.storeToken(providerId, _userId!, result);
        print('💾 [Auth] Chamando tokenStorage.setActiveUser...');
        await tokenStorage.setActiveUser(providerId, _userId!);
        print('💾 [Auth] TokenStorage concluído.');
        
        // Verificação imediata do usuário ativo
        print('🔍 [Auth] Verificação imediata: carregando usuário ativo recém-salvo...');
        final savedActiveUser = await tokenStorage.getActiveUser(providerId);
        if (savedActiveUser == _userId) {
          print('✅ [Auth] Verificação OK: Usuário ativo salvo corretamente: $savedActiveUser');
        } else {
          print('❌ [Auth] ERRO: Usuário ativo não foi salvo! Esperado: $_userId, Encontrado: $savedActiveUser');
        }
        
        print('💾 [Auth] Token armazenado para usuário: $_userId');
        print('💾 [Auth] Status do resultado: success=${result.success}, hasPermissionIssues=${result.hasPermissionIssues}, needsReauth=${result.needsReauth}');
        
        // Verificação imediata: tentar carregar o token que acabamos de salvar
        print('🔍 [Auth] Verificação imediata: tentando carregar token recém-salvo...');
        final savedToken = await tokenStorage.getToken(providerId, _userId!);
        if (savedToken != null) {
          print('✅ [Auth] Verificação OK: Token carregado imediatamente após salvar');
          print('✅ [Auth] Token verificado: success=${savedToken.success}, hasPermissionIssues=${savedToken.hasPermissionIssues}');
        } else {
          print('❌ [Auth] ERRO: Token não foi encontrado imediatamente após salvar!');
        }
        
        // Verificação de todos os tokens
        print('🔍 [Auth] Verificando todos os tokens salvos...');
        final allTokens = await tokenStorage.getAllTokens(providerId);
        print('🔍 [Auth] Tokens encontrados na verificação: ${allTokens.keys.toList()}');
        
        // Set appropriate status based on permission issues
        if (result.hasPermissionIssues) {
          print('⚠️ [Auth] Definindo status como needsReauth devido a problemas de permissão');
          updateStatus(ProviderStatus.needsReauth);
        } else {
          print('✅ [Auth] Definindo status como connected');
          updateStatus(ProviderStatus.connected);
        }
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
      if (_activeUserId != null) {
        await tokenStorage.removeToken(providerId, _activeUserId!);
      }
      _authResult = null;
      _userId = null;
      _activeUserId = null;
      updateStatus(ProviderStatus.disconnected);
    }
  }
  
  @override
  ProviderCapabilities get capabilities => ProviderCapabilities.full();
  
  /// Get current access token
  String? get accessToken => _authResult?.accessToken;
  
  /// Get current user ID
  String? get userId => _userId;
  
  /// Get active user ID
  String? get activeUserId => _activeUserId;
  
  /// Whether user needs re-authentication due to permission issues
  bool get needsReauth => _needsReauth;
  
  /// Check if token is expired
  bool get isTokenExpired => _authResult?.isExpired ?? true;
  
  @override
  Future<Map<String, dynamic>?> fetchUserInfo() async {
    if (!isAuthenticated || accessToken == null) return null;

    try {
      final userInfo = await getUserInfoFromProvider(accessToken!);
      return userInfo;
    } catch (e) {
      debugPrint('Error fetching user info: $e');
      return null;
    }
  }

  Future<bool> refreshAccessToken() async {
    if (_authResult?.refreshToken == null) return false;

    try {
      final newAuthResult = await refreshTokenWithProvider(_authResult!.refreshToken!);
      if (newAuthResult != null && newAuthResult.success) {
        _authResult = newAuthResult;
        
        // Update stored token
        if (_activeUserId != null) {
          await tokenStorage.storeToken(providerId, _activeUserId!, newAuthResult);
        }
        
        updateStatus(ProviderStatus.connected);
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
      final callbackScheme = kIsWeb ? 'http' : OAuthConfig.customSchemeRedirectUri;
      print('🔐 [OAuth] Callback scheme: $callbackScheme');
      print('🔐 [OAuth] Platform: ${kIsWeb ? "Web" : "Desktop"}');

      // Use webAuthClient for cross-platform OAuth
      print('🔐 [OAuth] Chamando webAuthClient.authenticate...');
      final result = await webAuthClient.authenticate(
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
        print('✅ [OAuth] Código recebido do servidor! Buscando tokens...');
        
        // Buscar os tokens reais do servidor usando o state
        try {
          final tokenResponse = await http.get(
            Uri.parse('${ServerConfig.baseUrl}/auth/tokens/${callback.state}'),
            headers: {'Content-Type': 'application/json'},
          );

          if (tokenResponse.statusCode == 200) {
            final tokenData = jsonDecode(tokenResponse.body);
            print('✅ [OAuth] Tokens obtidos do servidor!');
            print('🔍 [OAuth] Access token: ${tokenData['access_token']?.substring(0, 20)}...');
            print('🔍 [OAuth] Token type: ${tokenData['token_type']}');
            print('🔍 [OAuth] Expires in: ${tokenData['expires_in']}');
            print('🔍 [OAuth] Scopes: ${tokenData['scope']}');
            
            // Check if required scopes are present
            final grantedScopes = tokenData['scope']?.toString() ?? '';
            print('🔍 [OAuth] Verificando scopes: $grantedScopes');
            final scopesValid = hasRequiredScopes(grantedScopes);
            print('🔍 [OAuth] HasRequiredScopes: $scopesValid');
            
            // Get user info to generate user ID and cache user data
            String? userId;
            String? userName;
            String? userEmail;
            String? userPicture;
            try {
              final userInfo = await getUserInfoFromProvider(tokenData['access_token']);
              userId = userInfo?['id']?.toString() ?? userInfo?['sub']?.toString();
              userName = userInfo?['name']?.toString();
              userEmail = userInfo?['email']?.toString();
              userPicture = userInfo?['picture']?.toString();
              print('✅ [OAuth] User info obtido: id=$userId, name=$userName, email=$userEmail');
            } catch (e) {
              print('⚠️ [OAuth] Could not get user info for ID: $e');
            }
            
            // Create AuthResult with proper permission status
            if (scopesValid) {
              return AuthResult.success(
                accessToken: tokenData['access_token'],
                refreshToken: tokenData['refresh_token'],
                expiresAt: tokenData['expires_in'] != null 
                    ? DateTime.now().add(Duration(seconds: tokenData['expires_in']))
                    : DateTime.now().add(const Duration(hours: 1)),
                userId: userId,
                userName: userName,
                userEmail: userEmail,
                userPicture: userPicture,
                metadata: {
                  'code': callback.code,
                  'state': callback.state,
                  'timestamp': DateTime.now().toIso8601String(),
                  'source': 'server_token_retrieval',
                  'token_type': tokenData['token_type'] ?? 'Bearer',
                  'user_id': userId,
                  'granted_scopes': grantedScopes,
                },
              );
            } else {
              print('⚠️ [OAuth] Scopes insuficientes detectados durante a autenticação');
              return AuthResult.permissionIssue(
                accessToken: tokenData['access_token'],
                refreshToken: tokenData['refresh_token'],
                expiresAt: tokenData['expires_in'] != null 
                    ? DateTime.now().add(Duration(seconds: tokenData['expires_in']))
                    : DateTime.now().add(const Duration(hours: 1)),
                userId: userId,
                userName: userName,
                userEmail: userEmail,
                userPicture: userPicture,
                metadata: {
                  'code': callback.code,
                  'state': callback.state,
                  'timestamp': DateTime.now().toIso8601String(),
                  'source': 'server_token_retrieval',
                  'token_type': tokenData['token_type'] ?? 'Bearer',
                  'user_id': userId,
                  'granted_scopes': grantedScopes,
                },
                error: 'Scopes insuficientes para acesso ao Drive - é necessário reautenticação',
              );
            }
          } else {
            print('❌ [OAuth] Erro ao buscar tokens do servidor: ${tokenResponse.statusCode}');
            print('❌ [OAuth] Resposta: ${tokenResponse.body}');
            return AuthResult.failure('Failed to retrieve tokens from server: ${tokenResponse.statusCode}');
          }
        } catch (e) {
          print('❌ [OAuth] Erro ao buscar tokens: $e');
          return AuthResult.failure('Token retrieval failed: $e');
        }
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


  
  /// Handle API errors and update token status accordingly
  /// Returns true if the error was handled gracefully (permission issue)
  /// Returns false if it's a fatal error that should be rethrown
  Future<bool> handleApiError(int statusCode, String responseBody, String operation) async {
    print('🔍 [API Error] Status: $statusCode, Operation: $operation');
    print('🔍 [API Error] Response: $responseBody');
    
    // HTTP 401/403 typically indicates permission issues
    if (statusCode == 401 || statusCode == 403 || 
        responseBody.contains('insufficient') || 
        responseBody.contains('permission') ||
        responseBody.contains('scope') ||
        responseBody.contains('unauthorized')) {
      
      print('🔒 [Permission] Detected permission issues - marking account for re-auth');
      
      if (activeUserId != null) {
        await markTokenAsNeedsReauth(activeUserId!, 'Permission issues detected during $operation');
      }
      
      // Return true to indicate this was handled gracefully
      return true;
    }
    
    // For other errors, return false to indicate they should be rethrown
    return false;
  }
  
  /// Mark a token as needing re-authentication due to permission issues
  Future<void> markTokenAsNeedsReauth(String userId, String error) async {
    final currentToken = await tokenStorage.getToken(providerId, userId);
    if (currentToken != null && (currentToken.accessToken?.isNotEmpty ?? false)) {
      final updatedToken = AuthResult.permissionIssue(
        accessToken: currentToken.accessToken!,
        refreshToken: currentToken.refreshToken,
        expiresAt: currentToken.expiresAt,
        metadata: currentToken.metadata,
        error: error,
      );
      
      // Store updated token with permission flags
      await tokenStorage.storeToken(providerId, userId, updatedToken);
      
      // Update status to indicate issues
      updateStatus(ProviderStatus.needsReauth);
    }
  }
  
  /// Get a valid token for API calls, handling permission issues gracefully
  Future<AuthResult?> getValidTokenForApi() async {
    if (!isAuthenticated) return null;
    
    // Try to get stored token for current user
    if (activeUserId != null) {
      final storedToken = await tokenStorage.getToken(providerId, activeUserId!);
      // Accept tokens even with permission issues for reauth
      if (storedToken != null && (storedToken.accessToken?.isNotEmpty ?? false)) {
        // Check if token is expired and needs refresh
        if (storedToken.isExpired && storedToken.refreshToken != null) {
          final refreshed = await refreshAccessToken();
          if (refreshed) {
            return await tokenStorage.getToken(providerId, activeUserId!);
          }
        }
        return storedToken;
      }
    }
    
    return null;
  }

  /// Abstract methods that subclasses must implement

  /// Create OAuth parameters for this provider
  OAuthParams createOAuthParams();

  /// Check if the granted scopes include all required scopes for this provider
  bool hasRequiredScopes(String grantedScopes) {
    // This should be overridden by concrete providers to define their required scopes
    // For now, return true as base implementation
    return true;
  }
  
  /// Get user info from the provider's API
  Future<Map<String, dynamic>?> getUserInfoFromProvider(String accessToken);

  /// Validate token with the provider
  Future<bool> validateTokenWithProvider(String accessToken);

  /// Refresh token with the provider 
  Future<AuthResult?> refreshTokenWithProvider(String refreshToken);

  /// Revoke token with the provider
  Future<void> revokeToken(String accessToken);
}