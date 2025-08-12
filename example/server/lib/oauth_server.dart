import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

// Tente importar config.dart, senão use o exemplo
import 'config.dart' deferred as config;

/// Servidor OAuth de exemplo para desenvolvimento do File Cloud widget
class OAuthServer {
  late final Router _router;
  final Map<String, OAuthState> _states = {};
  final Random _random = Random.secure();
  
  OAuthServer() {
    _setupRoutes();
  }
  
  void _setupRoutes() {
    _router = Router()
      // Endpoint para iniciar autenticação OAuth
      ..get('/auth/google', _handleAuthStart)
      // Callback do Google OAuth
      ..get('/auth/callback', _handleCallback)
      // Endpoint para recuperar tokens pelo state
      ..get('/auth/tokens/<state>', _handleGetTokens)
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
      
      print('🎉 Tokens obtidos com sucesso para state: $state');
      
      // Retorna para o app com o access token no parâmetro hid (igual ao exemplo funcional)
      return _returnToApp(success: true, accessToken: tokenResponse['access_token']);
      
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
  
  /// Health check endpoint
  Response _handleHealth(Request request) {
    return Response.ok(
      json.encode({
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'active_states': _states.length,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
  
  /// Retorna para o app (web ou mobile)
  Response _returnToApp({bool success = false, String? error, String? accessToken}) {
    final queryParams = <String, String>{};
    
    if (success && accessToken != null) {
      queryParams['hid'] = accessToken; // Passa o access token via hid (igual ao exemplo funcional)
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