import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

// Tente importar config.dart, senão use o exemplo
import 'config.dart' deferred as config;

/// Servidor OAuth e de Arquivos de exemplo para desenvolvimento do File Cloud widget
class OAuthServer {
  late final Router _router;
  final Map<String, OAuthState> _states = {};
  final Map<String, String> _tokens = {}; // Simple token storage
  final Random _random = Random.secure();
  final String _storageRoot;
  
  OAuthServer({String? storageRoot}) 
    : _storageRoot = storageRoot ?? './storage' {
    _setupStorageDirectory();
    _setupRoutes();
  }
  
  void _setupStorageDirectory() {
    final storageDir = Directory(_storageRoot);
    if (!storageDir.existsSync()) {
      storageDir.createSync(recursive: true);
      print('Created storage directory: $_storageRoot');
      
      // Create sample files for testing
      _createSampleFiles();
    }
  }
  
  void _createSampleFiles() {
    try {
      // Create Documents folder with sample files
      final docsDir = Directory(path.join(_storageRoot, 'Documents'));
      docsDir.createSync(recursive: true);
      
      File(path.join(docsDir.path, 'README.txt')).writeAsStringSync(
        'Welcome to Local File Server!\n\nThis is a sample text file for testing the file drive widget.\n\nYou can:\n- Upload new files\n- Download existing files\n- Create folders\n- Delete files and folders\n\nEnjoy testing!'
      );
      
      File(path.join(docsDir.path, 'sample_data.json')).writeAsStringSync(
        json.encode({
          'server': 'Local File Server',
          'version': '1.0.0',
          'features': ['upload', 'download', 'create_folder', 'delete'],
          'created': DateTime.now().toIso8601String(),
        })
      );
      
      // Create Images folder with a sample text file (representing an image)
      final imagesDir = Directory(path.join(_storageRoot, 'Images'));
      imagesDir.createSync(recursive: true);
      
      File(path.join(imagesDir.path, 'placeholder.txt')).writeAsStringSync(
        'This folder is for images. Upload your PNG, JPG, or GIF files here!'
      );
      
      // Create a root level file
      File(path.join(_storageRoot, 'server_info.txt')).writeAsStringSync(
        'Local File Server - Running on ${Platform.localHostname}:${Platform.environment['PORT'] ?? '8080'}\n\nThis server simulates a cloud storage provider using your local file system.\nAll files are stored in: $_storageRoot\n\nHappy testing!'
      );
      
      print('✅ Sample files created in storage directory');
      
    } catch (e) {
      print('⚠️  Warning: Could not create sample files: $e');
    }
  }
  
  void _setupRoutes() {
    _router = Router()
      // OAuth endpoints
      ..get('/auth/google', _handleAuthStart)
      ..get('/auth/callback', _handleCallback)
      ..get('/auth/tokens/<state>', _handleGetTokens)
      ..post('/auth/refresh', _handleRefreshToken) // 🔑 Novo endpoint de refresh
      
      // File API endpoints
      ..get('/api/profile', _handleGetProfile)
      ..get('/api/files', _handleListFiles)
      ..post('/api/folders', _handleCreateFolder)
      ..delete('/api/files/<fileId>', _handleDeleteFile)
      ..post('/api/upload', _handleUploadFile)
      ..get('/api/download/<fileId>', _handleDownloadFile)
      
      // Health check
      ..get('/health', _handleHealth);
  }
  
  /// Gera um state único para o fluxo OAuth
  String _generateState() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      Iterable.generate(32, (_) => chars.codeUnitAt(_random.nextInt(chars.length))),
    );
  }
  
  /// Inicia o fluxo de autenticação OAuth
  Future<Response> _handleAuthStart(Request request) async {
    try {
      await config.loadLibrary();
      
      final state = _generateState();
      final now = DateTime.now();
      
      // Armazena o state temporariamente
      _states[state] = OAuthState(
        createdAt: now,
        expiresAt: now.add(Duration(minutes: config.ServerConfig.stateExpirationMinutes)),
      );
      
      // Limpa states expirados
      _cleanExpiredStates();
      
      // Constrói URL de autorização do Google
      final authUrl = Uri.parse(config.ServerConfig.googleAuthUrl).replace(
        queryParameters: {
          'client_id': config.ServerConfig.googleClientId,
          'redirect_uri': config.ServerConfig.redirectUri,
          'response_type': 'code',
          'scope': config.ServerConfig.requiredScopes.join(' '),
          'state': state,
          'access_type': 'offline', // Para obter refresh token
          'prompt': 'consent', // Força mostrar tela de consentimento
        },
      );
      
      print('🔐 Auth iniciado - State: $state');
      print('🌐 Redirecionando para: $authUrl');
      
      // Redireciona para o Google
      return Response.found(authUrl.toString());
      
    } catch (e) {
      print('❌ Erro ao iniciar auth: $e');
      return Response.internalServerError(
        body: json.encode({
          'error': 'internal_error',
          'error_description': 'Erro interno do servidor: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Trata o callback do Google OAuth
  Future<Response> _handleCallback(Request request) async {
    try {
      await config.loadLibrary();
      
      final code = request.url.queryParameters['code'];
      final state = request.url.queryParameters['state'];
      final error = request.url.queryParameters['error'];
      
      if (error != null) {
        print('❌ Erro do Google: $error');
        return _returnToApp(error: error);
      }
      
      if (code == null || state == null) {
        print('❌ Código ou state ausente');
        return _returnToApp(error: 'invalid_request');
      }
      
      // Verifica se o state é válido
      final stateData = _states[state];
      if (stateData == null) {
        print('❌ State inválido: $state');
        return _returnToApp(error: 'invalid_state');
      }
      
      if (DateTime.now().isAfter(stateData.expiresAt)) {
        print('❌ State expirado: $state');
        _states.remove(state);
        return _returnToApp(error: 'expired_state');
      }
      
      print('✅ Callback recebido - State: $state, Code: ${code.substring(0, 10)}...');
      
      // Troca o código pelos tokens
      final tokenResponse = await _exchangeCodeForTokens(code);
      
      if (tokenResponse == null) {
        return _returnToApp(error: 'token_exchange_failed');
      }
      
      // Armazena os tokens no state
      _states[state] = stateData.copyWith(tokens: tokenResponse);
      
      // Armazena o token para uso nas APIs subsequentes
      final accessToken = tokenResponse['access_token'] as String;
      final refreshToken = tokenResponse['refresh_token'] as String?;
      _tokens[state] = accessToken;
      
      print('🎉 Tokens obtidos com sucesso para state: $state');
      print('💾 Token armazenado para APIs: ${accessToken.substring(0, 10)}...');
      print('🔄 Refresh Token exists: ${refreshToken != null}');
      if (refreshToken != null) {
        print('🔄 Refresh Token (last 10 chars): ${refreshToken.substring(refreshToken.length - 10)}');
      }
      
      // Retorna para o app com tokens completos via query params
      return _returnToApp(
        success: true, 
        accessToken: accessToken,
        refreshToken: refreshToken,
        state: state, // Inclui state para buscar tokens completos se necessário
      );
      
    } catch (e) {
      print('❌ Erro no callback: $e');
      return _returnToApp(error: 'internal_error');
    }
  }
  
  /// Troca o código de autorização pelos tokens
  Future<Map<String, dynamic>?> _exchangeCodeForTokens(String code) async {
    try {
      await config.loadLibrary();
      
      final response = await http.post(
        Uri.parse(config.ServerConfig.googleTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': config.ServerConfig.googleClientId,
          'client_secret': config.ServerConfig.googleClientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': config.ServerConfig.redirectUri,
        },
      );
      
      if (response.statusCode != 200) {
        print('❌ Erro ao trocar tokens: ${response.statusCode} ${response.body}');
        return null;
      }
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      
      if (data.containsKey('error')) {
        print('❌ Erro nos tokens: ${data['error']}');
        return null;
      }
      
      return data;
      
    } catch (e) {
      print('❌ Exceção ao trocar tokens: $e');
      return null;
    }
  }
  
  /// Retorna tokens para o app Flutter
  Future<Response> _handleGetTokens(Request request, String state) async {
    try {
      final stateData = _states[state];
      
      if (stateData == null) {
        return Response.notFound(
          json.encode({
            'error': 'invalid_state',
            'error_description': 'Estado não encontrado ou expirado',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      if (stateData.tokens == null) {
        return Response(400,
          body: json.encode({
            'error': 'tokens_not_ready',
            'error_description': 'Tokens ainda não foram obtidos',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      print('📱 Tokens enviados para o app - State: $state');
      
      // Remove o state após uso (consumo único)
      _states.remove(state);
      
      return Response.ok(
        json.encode(stateData.tokens),
        headers: {'Content-Type': 'application/json'},
      );
      
    } catch (e) {
      print('❌ Erro ao enviar tokens: $e');
      return Response.internalServerError(
        body: json.encode({
          'error': 'internal_error',
          'error_description': 'Erro interno do servidor',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Refresh access token using refresh token
  Future<Response> _handleRefreshToken(Request request) async {
    try {
      await config.loadLibrary();
      
      // Parse request body
      final body = await request.readAsString();
      final formData = Uri.splitQueryString(body);
      
      final grantType = formData['grant_type'];
      final refreshToken = formData['refresh_token'];
      
      print('🔄 Refresh Token Request:');
      print('   Grant Type: $grantType');
      print('   Refresh Token (last 10 chars): ${refreshToken?.substring((refreshToken?.length ?? 0) - 10)}');
      
      // Validate request
      if (grantType != 'refresh_token' || refreshToken == null || refreshToken.isEmpty) {
        print('❌ Invalid refresh token request');
        return Response.badRequest(
          body: json.encode({
            'error': 'invalid_request',
            'error_description': 'Missing or invalid grant_type or refresh_token',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      // Call Google's token endpoint to refresh
      final response = await http.post(
        Uri.parse(config.ServerConfig.googleTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': config.ServerConfig.googleClientId,
          'client_secret': config.ServerConfig.googleClientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );
      
      print('🔄 Google Refresh Response:');
      print('   Status: ${response.statusCode}');
      print('   Body: ${response.body}');
      
      if (response.statusCode != 200) {
        print('❌ Google refresh failed: ${response.statusCode}');
        return Response(response.statusCode,
          body: json.encode({
            'error': 'invalid_grant',
            'error_description': 'Refresh token is invalid or expired',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      
      if (data.containsKey('error')) {
        print('❌ Google refresh error: ${data['error']}');
        return Response.badRequest(
          body: json.encode(data),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      print('✅ Token refreshed successfully');
      print('   New Access Token (last 10 chars): ${(data['access_token'] as String).substring((data['access_token'] as String).length - 10)}');
      
      // Return the refreshed tokens
      return Response.ok(
        json.encode(data),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
      
    } catch (e) {
      print('❌ Exception during refresh: $e');
      return Response.internalServerError(
        body: json.encode({
          'error': 'server_error',
          'error_description': 'Internal server error during token refresh',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Health check endpoint
  /// Get user profile
  Future<Response> _handleGetProfile(Request request) async {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.unauthorized('Bearer token required');
    }

    final token = authHeader.substring(7);
    if (!_tokens.containsValue(token)) {
      return Response.unauthorized('Invalid token');
    }

    return Response.ok(json.encode({
      'id': 'local_user',
      'name': 'Local Server User',
      'email': 'user@localhost',
      'photo_url': null,
    }), headers: {'Content-Type': 'application/json'});
  }

  /// List files in a folder
  Future<Response> _handleListFiles(Request request) async {
    if (!_isAuthenticated(request)) {
      return Response.unauthorized('Authentication required');
    }

    final folderId = request.url.queryParameters['folder'];
    final folderPath = _getStoragePath(folderId);
    
    try {
      final dir = Directory(folderPath);
      if (!dir.existsSync()) {
        return Response.ok(json.encode({
          'files': [],
          'has_next_page': false,
        }), headers: {'Content-Type': 'application/json'});
      }

      final entries = <Map<String, dynamic>>[];
      
      await for (final entity in dir.list()) {
        final stat = await entity.stat();
        final isFolder = entity is Directory;
        final name = path.basename(entity.path);
        
        // Skip hidden files and directories
        if (name.startsWith('.')) continue;

        entries.add({
          'id': _generateFileId(entity.path),
          'name': name,
          'is_folder': isFolder,
          'size': isFolder ? 0 : stat.size,
          'modified_at': stat.modified.toIso8601String(),
          'mime_type': isFolder ? null : _getMimeType(name),
          'download_url': isFolder ? null : '/api/download/${_generateFileId(entity.path)}',
          'metadata': {},
        });
      }

      return Response.ok(json.encode({
        'files': entries,
        'has_next_page': false,
      }), headers: {'Content-Type': 'application/json'});
      
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Failed to list files: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Create a new folder
  Future<Response> _handleCreateFolder(Request request) async {
    if (!_isAuthenticated(request)) {
      return Response.unauthorized('Authentication required');
    }

    try {
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;
      final name = data['name'] as String?;
      final parentId = data['parent_id'] as String?;

      if (name == null || name.isEmpty) {
        return Response.badRequest(
          body: json.encode({'error': 'Folder name is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final parentPath = _getStoragePath(parentId);
      final folderPath = path.join(parentPath, name);
      
      final dir = Directory(folderPath);
      if (dir.existsSync()) {
        return Response(409, 
          body: json.encode({'error': 'Folder already exists'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await dir.create(recursive: true);
      final stat = await dir.stat();

      final result = {
        'id': _generateFileId(folderPath),
        'name': name,
        'is_folder': true,
        'size': 0,
        'modified_at': stat.modified.toIso8601String(),
        'metadata': data['metadata'] ?? {},
      };

      return Response(201,
        body: json.encode(result),
        headers: {'Content-Type': 'application/json'},
      );
      
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Failed to create folder: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Delete a file or folder
  Future<Response> _handleDeleteFile(Request request) async {
    if (!_isAuthenticated(request)) {
      return Response.unauthorized('Authentication required');
    }

    final fileId = request.params['fileId'];
    if (fileId == null) {
      return Response.badRequest(
        body: json.encode({'error': 'File ID is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final filePath = _getFilePathFromId(fileId);
      final entity = await FileSystemEntity.type(filePath);
      
      if (entity == FileSystemEntityType.notFound) {
        return Response.notFound(
          json.encode({'error': 'File not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (entity == FileSystemEntityType.directory) {
        await Directory(filePath).delete(recursive: true);
      } else {
        await File(filePath).delete();
      }

      return Response(204);
      
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Failed to delete file: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Upload a file
  Future<Response> _handleUploadFile(Request request) async {
    if (!_isAuthenticated(request)) {
      return Response.unauthorized('Authentication required');
    }

    try {
      // This is a simplified upload handler
      // In a real implementation, you'd parse multipart/form-data
      final parentId = request.url.queryParameters['parent_id'];
      final fileName = request.url.queryParameters['file_name'] ?? 'uploaded_file';
      
      final parentPath = _getStoragePath(parentId);
      final filePath = path.join(parentPath, fileName);
      
      final file = File(filePath);
      final bytes = await request.read().expand((chunk) => chunk).toList();
      await file.writeAsBytes(bytes);
      
      final stat = await file.stat();
      
      final result = {
        'id': _generateFileId(filePath),
        'name': fileName,
        'is_folder': false,
        'size': stat.size,
        'modified_at': stat.modified.toIso8601String(),
        'mime_type': _getMimeType(fileName),
      };

      return Response(201,
        body: json.encode(result),
        headers: {'Content-Type': 'application/json'},
      );
      
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Failed to upload file: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Download a file
  Future<Response> _handleDownloadFile(Request request) async {
    if (!_isAuthenticated(request)) {
      return Response.unauthorized('Authentication required');
    }

    final fileId = request.params['fileId'];
    if (fileId == null) {
      return Response.badRequest(
        body: json.encode({'error': 'File ID is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final filePath = _getFilePathFromId(fileId);
      final file = File(filePath);
      
      if (!file.existsSync()) {
        return Response.notFound(
          json.encode({'error': 'File not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final fileName = path.basename(filePath);
      final mimeType = _getMimeType(fileName) ?? 'application/octet-stream';
      final fileSize = await file.length();
      
      return Response.ok(
        file.openRead(),
        headers: {
          'Content-Type': mimeType,
          'Content-Length': fileSize.toString(),
          'Content-Disposition': 'attachment; filename="$fileName"',
          'Access-Control-Allow-Origin': '*',
        },
      );
      
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Failed to download file: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Helper methods
  
  bool _isAuthenticated(Request request) {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return false;
    }
    final token = authHeader.substring(7);
    return _tokens.containsValue(token);
  }

  String _getStoragePath(String? folderId) {
    if (folderId == null || folderId.isEmpty) {
      return _storageRoot;
    }
    // Simple mapping: folder ID to relative path
    // In a real implementation, you'd have a proper mapping
    return path.join(_storageRoot, folderId.replaceAll('_', '/'));
  }

  String _generateFileId(String filePath) {
    // Simple ID generation based on path
    final relativePath = path.relative(filePath, from: _storageRoot);
    return relativePath.replaceAll('/', '_').replaceAll('\\', '_');
  }

  String _getFilePathFromId(String fileId) {
    final relativePath = fileId.replaceAll('_', '/');
    return path.join(_storageRoot, relativePath);
  }

  String? _getMimeType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.txt': return 'text/plain';
      case '.json': return 'application/json';
      case '.pdf': return 'application/pdf';
      case '.png': return 'image/png';
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.gif': return 'image/gif';
      case '.docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.zip': return 'application/zip';
      case '.rar': return 'application/x-rar-compressed';
      case '.mp4': return 'video/mp4';
      case '.mp3': return 'audio/mpeg';
      default: return 'application/octet-stream';
    }
  }

  Response _handleHealth(Request request) {
    // Add a test token for development/testing
    if (!_tokens.containsValue('test_token_dev')) {
      _tokens['test_state'] = 'test_token_dev';
      print('🧪 Token de teste adicionado: test_token_dev');
    }
    
    return Response.ok(
      json.encode({
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'active_states': _states.length,
        'stored_tokens': _tokens.length,
        'storage_root': _storageRoot,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
  
  /// Retorna para o app (web ou mobile)
  Response _returnToApp({
    bool success = false, 
    String? error, 
    String? accessToken,
    String? refreshToken,
    String? state,
  }) {
    final queryParams = <String, String>{};
    
    if (success && accessToken != null) {
      queryParams['hid'] = accessToken; // Mantém compatibilidade
      
      // Inclui refresh token se disponível
      if (refreshToken != null) {
        queryParams['refresh_token'] = refreshToken;
      }
      
      // Inclui state para fallback
      if (state != null) {
        queryParams['state'] = state;
      }
    } else if (success) {
      queryParams['success'] = 'true';
    }
    
    if (error != null) {
      queryParams['error'] = error;
    }
    
    // Redireciona diretamente para o custom scheme (como no exemplo funcional)
    final appUri = Uri(scheme: 'my-custom-app', queryParameters: queryParams);
    
    print('📱 Redirecionando para app: $appUri');
    
    return Response.found(appUri.toString());
  }
  
  /// Remove states expirados
  void _cleanExpiredStates() {
    final now = DateTime.now();
    _states.removeWhere((key, value) => now.isAfter(value.expiresAt));
  }
  
  /// Inicia o servidor
  Future<void> start() async {
    try {
      await config.loadLibrary();
      
      final pipeline = Pipeline()
          .addMiddleware(logRequests())
          .addHandler(_router.call);
      
      await serve(
        pipeline,
        config.ServerConfig.host,
        config.ServerConfig.port,
      );
      
      print('🚀 Servidor OAuth iniciado!');
      print('📍 URL: ${config.ServerConfig.baseUrl}');
      print('🔧 Health check: ${config.ServerConfig.baseUrl}/health');
      print('🔐 Auth endpoint: ${config.ServerConfig.baseUrl}/auth/google');
      print('💡 Configure o Google Console com redirect URI: ${config.ServerConfig.redirectUri}');
      print('');
      print('Pressione Ctrl+C para parar o servidor');
      
    } catch (e) {
      if (e.toString().contains('config.dart')) {
        print('❌ Arquivo config.dart não encontrado!');
        print('📝 Por favor:');
        print('   1. Copie lib/config.example.dart para lib/config.dart');
        print('   2. Configure suas credenciais do Google OAuth2');
        print('   3. Execute novamente');
        exit(1);
      } else {
        print('❌ Erro ao iniciar servidor: $e');
        exit(1);
      }
    }
  }
}

/// Estado do OAuth armazenado temporariamente
class OAuthState {
  final DateTime createdAt;
  final DateTime expiresAt;
  final Map<String, dynamic>? tokens;
  
  OAuthState({
    required this.createdAt,
    required this.expiresAt,
    this.tokens,
  });
  
  OAuthState copyWith({
    DateTime? createdAt,
    DateTime? expiresAt,
    Map<String, dynamic>? tokens,
  }) {
    return OAuthState(
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      tokens: tokens ?? this.tokens,
    );
  }
}