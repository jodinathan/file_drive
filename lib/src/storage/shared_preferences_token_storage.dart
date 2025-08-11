/// SharedPreferences implementation of TokenStorage
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/oauth_types.dart';
import 'token_storage.dart';
import 'account_deletion_mixin.dart';

/// Implementation of TokenStorage using SharedPreferences
class SharedPreferencesTokenStorage with AccountDeletionMixin implements TokenStorage {
  static const String _tokenPrefix = 'file_drive_token_';
  static const String _activeUserPrefix = 'file_drive_active_user_';
  
  SharedPreferences? _prefs;
  
  /// Initialize SharedPreferences
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      print('🔧 [Storage] Inicializando SharedPreferences...');
      _prefs = await SharedPreferences.getInstance();
      print('🔧 [Storage] SharedPreferences inicializado');
      
      // Debug: list all existing keys
      final allKeys = _prefs!.getKeys();
      final tokenKeys = allKeys.where((k) => k.startsWith(_tokenPrefix)).toList();
      final activeUserKeys = allKeys.where((k) => k.startsWith(_activeUserPrefix)).toList();
      print('🔧 [Storage] Debug - Chaves de token existentes: $tokenKeys');
      print('🔧 [Storage] Debug - Chaves de usuário ativo existentes: $activeUserKeys');
    }
  }
  
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
    await _ensureInitialized();
    
    print('💾 [Storage] Salvando token para $providerId:$userId');
    print('💾 [Storage] Token: success=${token.success}, hasPermissionIssues=${token.hasPermissionIssues}, needsReauth=${token.needsReauth}');
    
    final key = _getTokenKey(providerId, userId);
    final tokenJson = jsonEncode({
      'success': token.success,
      'accessToken': token.accessToken,
      'refreshToken': token.refreshToken,
      'expiresAt': token.expiresAt?.toIso8601String(),
      'error': token.error,
      'metadata': token.metadata,
'userName': token.userName,
'userEmail': token.userEmail,
'userPicture': token.userPicture,
'userInfoUpdatedAt': token.userInfoUpdatedAt?.toIso8601String(),
      'hasPermissionIssues': token.hasPermissionIssues,
      'needsReauth': token.needsReauth,
    });
    
    await _prefs!.setString(key, tokenJson);
    print('💾 [Storage] Token salvo com chave: $key');
  }
  
  @override
  Future<AuthResult?> getToken(String providerId, String userId) async {
    await _ensureInitialized();
    
    final key = _getTokenKey(providerId, userId);
    final tokenJson = _prefs!.getString(key);
    
    print('🔍 [Storage] Carregando token para $providerId:$userId com chave: $key');
    print('🔍 [Storage] Token JSON encontrado: ${tokenJson != null ? "SIM" : "NÃO"}');
    
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
userName: data['userName'],
userEmail: data['userEmail'],
userPicture: data['userPicture'],
userInfoUpdatedAt: data['userInfoUpdatedAt'] != null ? DateTime.parse(data['userInfoUpdatedAt']) : null,
        hasPermissionIssues: data['hasPermissionIssues'] ?? false,
        needsReauth: data['needsReauth'] ?? false,
      );
      
      print('🔍 [Storage] Token carregado: success=${result.success}, hasPermissionIssues=${result.hasPermissionIssues}, needsReauth=${result.needsReauth}');
      return result;
    } catch (e) {
      print('❌ [Storage] Erro ao carregar token: $e');
      // If token is corrupted, remove it
      await _prefs!.remove(key);
      return null;
    }
  }
  
  @override
  Future<Map<String, AuthResult>> getAllTokens(String providerId) async {
    await _ensureInitialized();
    
    print('🔍 [Storage] Buscando todos os tokens para provider: $providerId');
    
    final tokens = <String, AuthResult>{};
    final keys = _prefs!.getKeys();
    final prefix = '${_tokenPrefix}$providerId';
    
    print('🔍 [Storage] Chaves encontradas no storage: ${keys.where((k) => k.startsWith(prefix)).toList()}');
    
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        // Extract userId from key: "file_drive_token_providerId_userId"
        final userId = key.substring(prefix.length + 1);
        print('🔍 [Storage] Carregando token para userId: $userId');
        final token = await getToken(providerId, userId);
        if (token != null) {
          tokens[userId] = token;
          print('✅ [Storage] Token carregado para $userId');
        } else {
          print('❌ [Storage] Falha ao carregar token para $userId');
        }
      }
    }
    
    print('🔍 [Storage] Total de tokens carregados: ${tokens.length}');
    return tokens;
  }
  
  @override
  Future<void> removeToken(String providerId, String userId) async {
    await _ensureInitialized();
    
    final key = _getTokenKey(providerId, userId);
    await _prefs!.remove(key);
    
    // If this was the active user, clear it
    final activeUser = await getActiveUser(providerId);
    if (activeUser == userId) {
      await clearActiveUser(providerId);
    }
  }
  
  @override
  Future<void> removeAllTokens(String providerId) async {
    await _ensureInitialized();
    
    final keys = _prefs!.getKeys();
    final prefix = '${_tokenPrefix}$providerId';
    
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await _prefs!.remove(key);
      }
    }
    
    // Clear active user
    await clearActiveUser(providerId);
  }
  
  @override
  Future<bool> hasToken(String providerId, String userId) async {
    await _ensureInitialized();
    
    final key = _getTokenKey(providerId, userId);
    return _prefs!.containsKey(key);
  }
  
  @override
  Future<String?> getActiveUser(String providerId) async {
    await _ensureInitialized();
    
    final key = _getActiveUserKey(providerId);
    print('🔍 [Storage] Buscando usuário ativo para provider: $providerId');
    print('🔍 [Storage] Chave do usuário ativo: $key');
    final activeUser = _prefs!.getString(key);
    print('🔍 [Storage] Usuário ativo encontrado: $activeUser');
    return activeUser;
  }
  
  @override
  Future<void> setActiveUser(String providerId, String userId) async {
    await _ensureInitialized();
    
    final key = _getActiveUserKey(providerId);
    print('💾 [Storage] Salvando usuário ativo: $providerId -> $userId');
    print('💾 [Storage] Chave do usuário ativo: $key');
    await _prefs!.setString(key, userId);
    print('💾 [Storage] Usuário ativo salvo com sucesso');
  }
  
  @override
  Future<void> clearActiveUser(String providerId) async {
    await _ensureInitialized();
    
    final key = _getActiveUserKey(providerId);
    await _prefs!.remove(key);
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
    await _ensureInitialized();
    
    int deletedCount = 0;
    final keys = _prefs!.getKeys();
    final prefix = '${_tokenPrefix}$providerId';
    
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await _prefs!.remove(key);
        deletedCount++;
      }
    }
    
    // Clear active user
    await clearActiveUser(providerId);
    
    return deletedCount;
  }
  
  @override
  Future<List<String>> getUserIdsForProvider(String providerId) async {
    await _ensureInitialized();
    
    final userIds = <String>[];
    final keys = _prefs!.getKeys();
    final prefix = '${_tokenPrefix}$providerId';
    
    for (final key in keys) {
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