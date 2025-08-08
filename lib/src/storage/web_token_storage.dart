/// Web-specific localStorage implementation for token storage
library;

import 'dart:html' as html;
import 'dart:convert';
import '../models/oauth_types.dart';
import 'token_storage.dart';
import 'account_deletion_mixin.dart';

/// Web implementation using localStorage for better hot restart persistence
class WebTokenStorage with AccountDeletionMixin implements TokenStorage {
  static const String _tokenPrefix = 'file_drive_token_';
  static const String _activeUserPrefix = 'file_drive_active_user_';
  
  /// Generate storage key for token
  String _getTokenKey(String providerId, String userId) {
    return '${_tokenPrefix}${providerId}_$userId';
  }
  
  /// Generate storage key for active user
  String _getActiveUserKey(String providerId) {
    return '${_activeUserPrefix}$providerId';
  }
  
  @override
  Future<void> storeToken(String providerId, String userId, AuthResult token) async {
    print('💾 [Web Storage] Salvando token para $providerId:$userId');
    print('💾 [Web Storage] Token: success=${token.success}, hasPermissionIssues=${token.hasPermissionIssues}, needsReauth=${token.needsReauth}');
    
    final key = _getTokenKey(providerId, userId);
    final tokenJson = jsonEncode({
      'success': token.success,
      'accessToken': token.accessToken,
      'refreshToken': token.refreshToken,
      'expiresAt': token.expiresAt?.toIso8601String(),
      'error': token.error,
      'metadata': token.metadata,
      'hasPermissionIssues': token.hasPermissionIssues,
      'needsReauth': token.needsReauth,
    });
    
    html.window.localStorage[key] = tokenJson;
    print('💾 [Web Storage] Token salvo com chave: $key');
  }
  
  @override
  Future<AuthResult?> getToken(String providerId, String userId) async {
    final key = _getTokenKey(providerId, userId);
    final tokenJson = html.window.localStorage[key];
    
    print('🔍 [Web Storage] Carregando token para $providerId:$userId com chave: $key');
    print('🔍 [Web Storage] Token JSON encontrado: ${tokenJson != null ? "SIM" : "NÃO"}');
    
    if (tokenJson == null) return null;
    
    try {
      final data = jsonDecode(tokenJson);
      final result = AuthResult(
        success: data['success'] ?? false,
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
        expiresAt: data['expiresAt'] != null 
            ? DateTime.parse(data['expiresAt']) 
            : null,
        error: data['error'],
        metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
        hasPermissionIssues: data['hasPermissionIssues'] ?? false,
        needsReauth: data['needsReauth'] ?? false,
      );
      
      print('🔍 [Web Storage] Token carregado: success=${result.success}, hasPermissionIssues=${result.hasPermissionIssues}, needsReauth=${result.needsReauth}');
      return result;
    } catch (e) {
      print('❌ [Web Storage] Erro ao carregar token: $e');
      // If token is corrupted, remove it
      html.window.localStorage.remove(key);
      return null;
    }
  }
  
  @override
  Future<Map<String, AuthResult>> getAllTokens(String providerId) async {
    print('🔍 [Web Storage] Buscando todos os tokens para provider: $providerId');
    
    final tokens = <String, AuthResult>{};
    final localStorage = html.window.localStorage;
    final prefix = '${_tokenPrefix}$providerId';
    
    final matchingKeys = localStorage.keys.where((k) => k.startsWith(prefix)).toList();
    print('🔍 [Web Storage] Chaves encontradas no localStorage: $matchingKeys');
    
    for (final key in matchingKeys) {
      // Extract userId from key: "file_drive_token_providerId_userId"
      final userId = key.substring(prefix.length + 1);
      print('🔍 [Web Storage] Carregando token para userId: $userId');
      final token = await getToken(providerId, userId);
      if (token != null) {
        tokens[userId] = token;
        print('✅ [Web Storage] Token carregado para $userId');
      } else {
        print('❌ [Web Storage] Falha ao carregar token para $userId');
      }
    }
    
    print('🔍 [Web Storage] Total de tokens carregados: ${tokens.length}');
    return tokens;
  }
  
  @override
  Future<void> removeToken(String providerId, String userId) async {
    final key = _getTokenKey(providerId, userId);
    html.window.localStorage.remove(key);
    
    // If this was the active user, clear it
    final activeUser = await getActiveUser(providerId);
    if (activeUser == userId) {
      await clearActiveUser(providerId);
    }
  }
  
  @override
  Future<void> removeAllTokens(String providerId) async {
    final localStorage = html.window.localStorage;
    final prefix = '${_tokenPrefix}$providerId';
    
    final keysToRemove = localStorage.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      localStorage.remove(key);
    }
    
    // Clear active user
    await clearActiveUser(providerId);
  }
  
  @override
  Future<bool> hasToken(String providerId, String userId) async {
    final key = _getTokenKey(providerId, userId);
    return html.window.localStorage.containsKey(key);
  }
  
  @override
  Future<String?> getActiveUser(String providerId) async {
    final key = _getActiveUserKey(providerId);
    print('🔍 [Web Storage] Buscando usuário ativo para provider: $providerId');
    print('🔍 [Web Storage] Chave do usuário ativo: $key');
    final activeUser = html.window.localStorage[key];
    print('🔍 [Web Storage] Usuário ativo encontrado: $activeUser');
    return activeUser;
  }
  
  @override
  Future<void> setActiveUser(String providerId, String userId) async {
    final key = _getActiveUserKey(providerId);
    print('💾 [Web Storage] Salvando usuário ativo: $providerId -> $userId');
    print('💾 [Web Storage] Chave do usuário ativo: $key');
    html.window.localStorage[key] = userId;
    print('💾 [Web Storage] Usuário ativo salvo com sucesso');
  }
  
  @override
  Future<void> clearActiveUser(String providerId) async {
    final key = _getActiveUserKey(providerId);
    html.window.localStorage.remove(key);
  }
  
  // AccountDeletionMixin implementation
  
  @override
  Future<bool> deleteUserAccount(String providerId, String userId) async {
    try {
      await removeToken(providerId, userId);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<int> deleteAllAccountsForProvider(String providerId) async {
    int deletedCount = 0;
    final localStorage = html.window.localStorage;
    final prefix = '${_tokenPrefix}$providerId';
    
    final keysToRemove = localStorage.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      localStorage.remove(key);
      deletedCount++;
    }
    
    // Clear active user
    await clearActiveUser(providerId);
    
    return deletedCount;
  }
  
  @override
  Future<List<String>> getUserIdsForProvider(String providerId) async {
    final userIds = <String>[];
    final localStorage = html.window.localStorage;
    final prefix = '${_tokenPrefix}$providerId';
    
    for (final key in localStorage.keys) {
      if (key.startsWith(prefix)) {
        // Extract userId from key: "file_drive_token_providerId_userId"
        final userId = key.substring(prefix.length + 1);
        userIds.add(userId);
      }
    }
    
    return userIds;
  }
  
  @override
  Future<bool> userAccountExists(String providerId, String userId) async {
    return await hasToken(providerId, userId);
  }
}