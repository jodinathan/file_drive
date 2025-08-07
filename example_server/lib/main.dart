/// 🖥️ SERVIDOR OAUTH PARA GOOGLE DRIVE
/// Servidor simples que faz OAuth com Google e redireciona para o app
library;

import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:http/http.dart' as http;
import 'config.dart';

void main() async {
  print('🚀 Iniciando servidor OAuth...');
  
  final app = Router();
  
  // CORS middleware simples
  Middleware corsMiddleware = (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        });
      }

      final response = await handler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      });
    };
  };

  // 📍 ENDPOINT: Iniciar OAuth
  app.get('/auth/google', (Request request) async {
    print('🔗 Iniciando OAuth flow...');
    
    final state = request.url.queryParameters['state'] ?? 'default_state';
    
    // Redirecionar para Google OAuth
    final googleAuthUrl = Uri.parse(ServerConfig.googleAuthUrl).replace(
      queryParameters: {
        'client_id': ServerConfig.googleClientId,
        'redirect_uri': '${ServerConfig.baseUrl}/auth/callback',
        'response_type': 'code',
        'scope': ServerConfig.defaultScopes.join(' '),
        'state': state,
        'access_type': 'offline',
        'prompt': 'select_account',
        'include_granted_scopes': 'true',
      },
    );
    
    print('🚀 Redirecionando para: $googleAuthUrl');
    return Response.found(googleAuthUrl.toString());
  });

  // 📍 ENDPOINT: Callback do Google
  app.get('/auth/callback', (Request request) async {
    print('📞 Recebendo callback do Google...');
    
    final params = request.url.queryParameters;
    final code = params['code'];
    final state = params['state'];
    final error = params['error'];
    
    print('📞 Code: ${code?.substring(0, 10)}...');
    print('📞 State: $state');
    print('📞 Error: $error');

    if (error != null) {
      print('❌ Erro OAuth: $error');
      final errorUri = Uri.parse(ServerConfig.defaultClientRedirectUri).replace(
        queryParameters: {'error': error, 'error_description': 'OAuth error'},
      );
      return Response.found(errorUri.toString());
    }

    if (code == null || state == null) {
      print('❌ Código ou state ausente');
      final errorUri = Uri.parse(ServerConfig.defaultClientRedirectUri).replace(
        queryParameters: {'error': 'invalid_request', 'error_description': 'Missing code or state'},
      );
      return Response.found(errorUri.toString());
    }

    // Trocar código por tokens
    print('🔄 Trocando código por tokens...');
    final tokenResponse = await _exchangeCodeForTokens(code);
    
    if (tokenResponse == null) {
      print('❌ Falha na troca de tokens');
      final errorUri = Uri.parse(ServerConfig.defaultClientRedirectUri).replace(
        queryParameters: {'error': 'server_error', 'error_description': 'Failed to exchange code for tokens'},
      );
      return Response.found(errorUri.toString());
    }

    print('✅ Tokens obtidos com sucesso!');
    
    // Redirecionar de volta para o app com sucesso
    final successUri = Uri.parse(ServerConfig.defaultClientRedirectUri).replace(
      queryParameters: {
        'code': code,
        'state': state,
      },
    );
    
    print('🔄 Redirecionando para app: $successUri');
    return Response.found(successUri.toString());
  });

  // 📍 ENDPOINT: Refresh token
  app.post('/auth/refresh', (Request request) async {
    print('🔄 Refresh token solicitado...');
    
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final refreshToken = data['refresh_token'];
    
    if (refreshToken == null) {
      return Response.badRequest(body: 'Missing refresh_token');
    }
    
    final response = await http.post(
      Uri.parse(ServerConfig.googleTokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': ServerConfig.googleClientId,
        'client_secret': ServerConfig.googleClientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );
    
    if (response.statusCode == 200) {
      print('✅ Token refreshed');
      return Response.ok(response.body, headers: {'Content-Type': 'application/json'});
    } else {
      print('❌ Falha no refresh: ${response.statusCode}');
      return Response.internalServerError(body: 'Failed to refresh token');
    }
  });

  // 📍 ENDPOINT: Revoke token
  app.post('/auth/revoke', (Request request) async {
    print('🗑️ Revoke token solicitado...');
    
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final token = data['token'];
    
    if (token == null) {
      return Response.badRequest(body: 'Missing token');
    }
    
    final response = await http.post(
      Uri.parse(ServerConfig.googleRevokeUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'token': token},
    );
    
    if (response.statusCode == 200) {
      print('✅ Token revoked');
      return Response.ok('Token revoked');
    } else {
      print('❌ Falha no revoke: ${response.statusCode}');
      return Response.internalServerError(body: 'Failed to revoke token');
    }
  });

  // Middleware CORS
  final handler = Pipeline()
      .addMiddleware(corsMiddleware)
      .addMiddleware(logRequests())
      .addHandler(app);

  // Iniciar servidor
  final server = await serve(handler, ServerConfig.host, ServerConfig.port);
  print('✅ Servidor rodando em ${server.address.host}:${server.port}');
  print('🔗 OAuth URL: ${ServerConfig.baseUrl}/auth/google');
}

/// Trocar código por tokens com Google
Future<Map<String, dynamic>?> _exchangeCodeForTokens(String code) async {
  try {
    print('🔄 Iniciando troca de código por tokens...');
    
    final response = await http.post(
      Uri.parse(ServerConfig.googleTokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': ServerConfig.googleClientId,
        'client_secret': ServerConfig.googleClientSecret,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': '${ServerConfig.baseUrl}/auth/callback',
      },
    );
    
    print('🔄 Response status: ${response.statusCode}');
    print('🔄 Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Tokens obtidos com sucesso!');
      return data;
    } else {
      print('❌ Falha na troca: ${response.statusCode}');
      print('❌ Error body: ${response.body}');
      return null;
    }
  } catch (e) {
    print('❌ Erro na troca de tokens: $e');
    return null;
  }
}
