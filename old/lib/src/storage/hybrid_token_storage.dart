/// Robust token storage with multiple persistence strategies for development
library;

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/oauth_types.dart';
import 'token_storage.dart';
import 'account_deletion_mixin.dart';

/// Hybrid implementation that uses both SharedPreferences and local file storage
/// for maximum persistence during development
class HybridTokenStorage with AccountDeletionMixin implements TokenStorage {
  static const String _tokenPrefix = 'file_drive_token_';
  static const String _activeUserPrefix = 'file_drive_active_user_';
  static const String _fileName = 'file_drive_tokens.json';
  
  SharedPreferences? _prefs;
  File? _storageFile;
  Map<String, dynamic>? _fileData;
  
  /// Initialize storage systems
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      print('🔧 [Hybrid] Inicializando SharedPreferences...');
      _prefs = await SharedPreferences.getInstance();
      print('🔧 [Hybrid] SharedPreferences inicializado');
    }
    
    if (_storageFile == null) {
      print('🔧 [Hybrid] Inicializando file storage...');
      try {
        final directory = await getApplicationDocumentsDirectory();
        _storageFile = File('${directory.path}/$_fileName');
        print('🔧 [Hybrid] File storage path: ${_storageFile!.path}');
        
        // Load existing data
        if (await _storageFile!.exists()) {
          final content = await _storageFile!.readAsString();
          _fileData = jsonDecode(content);
          print('🔧 [Hybrid] File data loaded: ${_fileData!.keys.length} keys');
        } else {
          _fileData = {};
          print('🔧 [Hybrid] File storage initialized with empty data');
        }
      } catch (e) {
        print('⚠️ [Hybrid] File storage initialization failed: $e');
        _fileData = {};
      }
    }
  }
  
  /// Save data to file storage
  Future<void> _saveToFile() async {
    try {
      if (_storageFile != null && _fileData != null) {
        final content = jsonEncode(_fileData);
        await _storageFile!.writeAsString(content);
        print('💾 [Hybrid] Data saved to file: ${_fileData!.keys.length} keys\n${StackTrace.current}');
        print('💾 [Hybrid] File content size: ${content.length} chars');
        
        // Verify the save worked
        if (await _storageFile!.exists()) {
          final verifyContent = await _storageFile!.readAsString();
          final verifyData = jsonDecode(verifyContent);
          print('💾 [Hybrid] File save verified: ${verifyData.keys.length} keys');
        }
      }
    } catch (e) {
      print('❌ [Hybrid] Failed to save to file: $e');
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
    
    print('💾 [Hybrid] Salvando token para $providerId:$userId');
    print('💾 [Hybrid] Token: success=${token.success}, hasPermissionIssues=${token.hasPermissionIssues}, needsReauth=${token.needsReauth}');
    
    final key = _getTokenKey(providerId, userId);
    final tokenData = {
      'success': token.success,
      'accessToken': token.accessToken,
      'refreshToken': token.refreshToken,
      'expiresAt': token.expiresAt?.toIso8601String(),
      'error': token.error,
      'metadata': token.metadata,
      'hasPermissionIssues': token.hasPermissionIssues,
      'needsReauth': token.needsReauth,
      'userId': token.userId,
      'userName': token.userName,
      'userEmail': token.userEmail,
      'userPicture': token.userPicture,
      'userInfoUpdatedAt': token.userInfoUpdatedAt?.toIso8601String(),
    };
    final tokenJson = jsonEncode(tokenData);
    
    // Store in SharedPreferences
    try {
      await _prefs!.setString(key, tokenJson);
      print('💾 [Hybrid] Token salvo em SharedPreferences com chave: $key');
    } catch (e) {
      print('❌ [Hybrid] Falha ao salvar em SharedPreferences: $e');
    }
    
    // Store in file
    try {
      _fileData![key] = tokenData;
      await _saveToFile();
      print('💾 [Hybrid] Token salvo em file storage');
    } catch (e) {
      print('❌ [Hybrid] Falha ao salvar em file storage: $e');
    }
  }
  
  @override
  Future<AuthResult?> getToken(String providerId, String userId) async {
    await _ensureInitialized();
    
    final key = _getTokenKey(providerId, userId);
    print('🔍 [Hybrid] Carregando token para $providerId:$userId com chave: $key');
    
    // Try SharedPreferences first
    String? tokenJson = _prefs!.getString(key);
    String source = 'SharedPreferences';
    
    // If not found, try file storage
    if (tokenJson == null && _fileData != null && _fileData!.containsKey(key)) {
      tokenJson = jsonEncode(_fileData![key]);
      source = 'File Storage';
      print('🔍 [Hybrid] Token não encontrado em SharedPreferences, usando file storage');
    }
    
    print('🔍 [Hybrid] Token JSON encontrado em $source: ${tokenJson != null ? "SIM" : "NÃO"}');
    
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
        userId: data['userId'],
        userName: data['userName'],
        userEmail: data['userEmail'],
        userPicture: data['userPicture'],
        userInfoUpdatedAt: data['userInfoUpdatedAt'] != null 
            ? DateTime.parse(data['userInfoUpdatedAt'])
            : null,
      );
      
      print('🔍 [Hybrid] Token carregado de $source: success=${result.success}, hasPermissionIssues=${result.hasPermissionIssues}, needsReauth=${result.needsReauth}');
      return result;
    } catch (e) {
      print('❌ [Hybrid] Erro ao carregar token: $e');
      // If token is corrupted, remove it from both storages
      await _prefs!.remove(key);
      _fileData?.remove(key);
      await _saveToFile();
      return null;
    }
  }
  
  @override
  Future<Map<String, AuthResult>> getAllTokens(String providerId) async {
    await _ensureInitialized();
    
    print('🔍 [Hybrid] Buscando todos os tokens para provider: $providerId');
    
    final tokens = <String, AuthResult>{};
    final prefix = '${_tokenPrefix}$providerId';
    
    // Collect keys from both sources
    final allKeys = <String>{};
    
    // From SharedPreferences
    final prefsKeys = _prefs!.getKeys().where((k) => k.startsWith(prefix));
    allKeys.addAll(prefsKeys);
    
    // From file storage
    if (_fileData != null) {
      final fileKeys = _fileData!.keys.where((k) => k.startsWith(prefix));
      allKeys.addAll(fileKeys);
    }
    
    print('🔍 [Hybrid] Chaves encontradas: SharedPrefs=${prefsKeys.length}, File=${_fileData?.keys.where((k) => k.startsWith(prefix)).length ?? 0}, Total unique=${allKeys.length}');
    
    for (final key in allKeys) {
      // Extract userId from key: "file_drive_token_providerId_userId"
      final userId = key.substring(prefix.length + 1);
      print('🔍 [Hybrid] Carregando token para userId: $userId');
      final token = await getToken(providerId, userId);
      if (token != null) {
        tokens[userId] = token;
        print('✅ [Hybrid] Token carregado para $userId');
      } else {
        print('❌ [Hybrid] Falha ao carregar token para $userId');
      }
    }
    
    print('🔍 [Hybrid] Total de tokens carregados: ${tokens.length}');
    return tokens;
  }
  
  @override
  Future<void> removeToken(String providerId, String userId) async {
    await _ensureInitialized();
    
    final key = _getTokenKey(providerId, userId);
    
    // Remove from both storages
    await _prefs!.remove(key);
    _fileData?.remove(key);
    await _saveToFile();
    
    // If this was the active user, clear it
    final activeUser = await getActiveUser(providerId);
    if (activeUser == userId) {
      await clearActiveUser(providerId);
    }
  }
  
  @override
  Future<void> removeAllTokens(String providerId) async {
    await _ensureInitialized();
    
    final prefix = '${_tokenPrefix}$providerId';
    
    // Remove from SharedPreferences
    final prefsKeys = _prefs!.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in prefsKeys) {
      await _prefs!.remove(key);
    }
    
    // Remove from file storage
    if (_fileData != null) {
      final keysToRemove = _fileData!.keys.where((k) => k.startsWith(prefix)).toList();
      for (final key in keysToRemove) {
        _fileData!.remove(key);
      }
      await _saveToFile();
    }
    
    // Clear active user
    await clearActiveUser(providerId);
  }
  
  @override
  Future<bool> hasToken(String providerId, String userId) async {
    await _ensureInitialized();
    
    final key = _getTokenKey(providerId, userId);
    
    // Check both storages
    final inPrefs = _prefs!.containsKey(key);
    final inFile = _fileData?.containsKey(key) ?? false;
    
    return inPrefs || inFile;
  }
  
  @override
  Future<String?> getActiveUser(String providerId) async {
    await _ensureInitialized();
    
    final key = _getActiveUserKey(providerId);
    print('🔍 [Hybrid] Buscando usuário ativo para provider: $providerId');
    print('🔍 [Hybrid] Chave do usuário ativo: $key');
    
    // Try SharedPreferences first
    String? activeUser = _prefs!.getString(key);
    String source = 'SharedPreferences';
    
    // If not found, try file storage
    if (activeUser == null && _fileData != null && _fileData!.containsKey(key)) {
      activeUser = _fileData![key] as String?;
      source = 'File Storage';
      print('🔍 [Hybrid] Usuário ativo não encontrado em SharedPreferences, usando file storage');
    }
    
    print('🔍 [Hybrid] Usuário ativo encontrado em $source: $activeUser');
    return activeUser;
  }
  
  @override
  Future<void> setActiveUser(String providerId, String userId) async {
    await _ensureInitialized();
    
    final key = _getActiveUserKey(providerId);
    print('💾 [Hybrid] Salvando usuário ativo: $providerId -> $userId');
    print('💾 [Hybrid] Chave do usuário ativo: $key');
    
    // Store in both places
    try {
      await _prefs!.setString(key, userId);
      print('💾 [Hybrid] Usuário ativo salvo em SharedPreferences');
    } catch (e) {
      print('❌ [Hybrid] Falha ao salvar usuário ativo em SharedPreferences: $e');
    }
    
    try {
      _fileData![key] = userId;
      await _saveToFile();
      print('💾 [Hybrid] Usuário ativo salvo em file storage');
    } catch (e) {
      print('❌ [Hybrid] Falha ao salvar usuário ativo em file storage: $e');
    }
  }
  
  @override
  Future<void> clearActiveUser(String providerId) async {
    await _ensureInitialized();
    
    final key = _getActiveUserKey(providerId);
    
    // Clear from both storages
    await _prefs!.remove(key);
    _fileData?.remove(key);
    await _saveToFile();
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
    final prefix = '${_tokenPrefix}$providerId';
    
    // Count and remove from SharedPreferences
    final prefsKeys = _prefs!.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in prefsKeys) {
      await _prefs!.remove(key);
      deletedCount++;
    }
    
    // Remove from file storage
    if (_fileData != null) {
      final keysToRemove = _fileData!.keys.where((k) => k.startsWith(prefix)).toList();
      for (final key in keysToRemove) {
        _fileData!.remove(key);
      }
      await _saveToFile();
    }
    
    // Clear active user
    await clearActiveUser(providerId);
    
    return deletedCount;
  }
  
  @override
  Future<List<String>> getUserIdsForProvider(String providerId) async {
    await _ensureInitialized();
    
    final userIds = <String>{};
    final prefix = '${_tokenPrefix}$providerId';
    
    // From SharedPreferences
    final prefsKeys = _prefs!.getKeys().where((k) => k.startsWith(prefix));
    for (final key in prefsKeys) {
      final userId = key.substring(prefix.length + 1);
      userIds.add(userId);
    }
    
    // From file storage
    if (_fileData != null) {
      final fileKeys = _fileData!.keys.where((k) => k.startsWith(prefix));
      for (final key in fileKeys) {
        final userId = key.substring(prefix.length + 1);
        userIds.add(userId);
      }
    }
    
    return userIds.toList();
  }
  
  @override
  Future<bool> userAccountExists(String providerId, String userId) async {
    return await hasToken(providerId, userId);
  }
}