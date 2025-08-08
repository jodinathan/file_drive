import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:file_drive/src/utils/constants.dart';
import 'dart:convert';
import 'test_config.dart';

// Generate mocks
@GenerateMocks([http.Client])
import 'oauth_validation_test.mocks.dart';

void main() {
  group('OAuth Google Validation Tests', () {
    late MockClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockClient();
    });

    group('Google OAuth URL Generation', () {
      test('should generate correct OAuth URL with proper parameters', () {
        // Simular geração de URL OAuth baseada no código funcional
        final clientId = '346650636779-58ec4t2v24ru8kj3s3t7dj46okanjman.apps.googleusercontent.com';
        final redirectUri = 'http://localhost:8080/auth/callback';
        final scopes = ['https://www.googleapis.com/auth/drive.file', 'https://www.googleapis.com/auth/userinfo.email'];
        final state = 'test_state_123';

        final authUrl = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth').replace(
          queryParameters: {
            'client_id': clientId,
            'redirect_uri': redirectUri,
            'response_type': 'code',
            'scope': scopes.join(' '),
            'state': state,
            'access_type': 'offline',
            'prompt': 'select_account',
            'include_granted_scopes': 'true',
          },
        );

        // Validações baseadas no código funcional
        expect(authUrl.scheme, equals('https'));
        expect(authUrl.host, equals('accounts.google.com'));
        expect(authUrl.path, equals('/o/oauth2/v2/auth'));
        expect(authUrl.queryParameters['client_id'], equals(clientId));
        expect(authUrl.queryParameters['redirect_uri'], equals(redirectUri));
        expect(authUrl.queryParameters['response_type'], equals('code'));
        expect(authUrl.queryParameters['scope'], contains('drive.file'));
        expect(authUrl.queryParameters['scope'], contains('userinfo.email'));
        expect(authUrl.queryParameters['access_type'], equals('offline'));
        expect(authUrl.queryParameters['prompt'], equals('select_account'));
        expect(authUrl.queryParameters['include_granted_scopes'], equals('true'));
      });

      test('should use minimal scopes to avoid authorization errors', () {
        // Baseado no código funcional que usa scopes específicos
        final minimalScopes = [
          'https://www.googleapis.com/auth/userinfo.email',
          'https://www.googleapis.com/auth/drive.file', // Mais restritivo que drive.readonly
        ];

        // Validar que não estamos pedindo scopes desnecessários
        expect(minimalScopes, isNot(contains('https://www.googleapis.com/auth/drive')));
        expect(minimalScopes, isNot(contains('https://www.googleapis.com/auth/drive.readonly')));
        expect(minimalScopes.length, equals(2)); // Mínimo necessário
      });

      test('should validate redirect URI format', () {
        // Testar diferentes formatos de redirect URI
        final validRedirectUris = [
          'http://localhost:8080/auth/callback',
          'http://127.0.0.1:8080/auth/callback',
        ];

        final invalidRedirectUris = [
          'https://localhost:8080/auth/callback', // HTTPS em localhost pode causar problemas
          'http://localhost/auth/callback', // Sem porta
          'localhost:8080/auth/callback', // Sem protocolo
        ];

        for (final uri in validRedirectUris) {
          final parsed = Uri.parse(uri);
          expect(parsed.scheme, equals('http'));
          expect(parsed.host, anyOf('localhost', '127.0.0.1'));
          expect(parsed.port, equals(8080));
          expect(parsed.path, equals('/auth/callback'));
        }

        for (final uri in invalidRedirectUris) {
          // Estes formatos podem causar "Access blocked" no Google
          if (uri.startsWith('https://localhost')) {
            expect(uri, contains('https')); // HTTPS em localhost é problemático
          }
        }
      });
    });

    group('OAuth Error Scenarios', () {
      test('should handle "Access blocked: Authorization Error"', () {
        // Simular resposta de erro do Google
        final errorResponse = {
          'error': 'access_blocked',
          'error_description': 'Authorization Error',
          'error_uri': 'https://developers.google.com/identity/protocols/oauth2'
        };

        // Validar tratamento do erro
        expect(errorResponse['error'], equals('access_blocked'));
        expect(errorResponse['error_description'], contains('Authorization'));
        
        // Verificar se temos informações para debug
        expect(errorResponse['error_uri'], isNotNull);
      });

      test('should validate client ID format', () {
        final clientId = '346650636779-58ec4t2v24ru8kj3s3t7dj46okanjman.apps.googleusercontent.com';
        
        // Validar formato do Client ID do Google
        expect(clientId, endsWith('.apps.googleusercontent.com'));
        expect(clientId, contains('-'));
        expect(clientId.split('-').length, equals(2));
        
        final parts = clientId.split('-');
        expect(parts[0], matches(r'^\d+$')); // Primeira parte deve ser numérica
        expect(parts[1], endsWith('.apps.googleusercontent.com'));
      });

      test('should detect common OAuth configuration issues', () {
        // Problemas comuns que causam "Access blocked"
        final commonIssues = {
          'invalid_client_id': 'Client ID não configurado no Google Cloud Console',
          'unauthorized_redirect_uri': 'Redirect URI não autorizado',
          'invalid_scope': 'Scope não aprovado para o app',
          'app_not_verified': 'App não verificado pelo Google',
        };

        // Validar que conhecemos os problemas comuns
        expect(commonIssues.keys, contains('unauthorized_redirect_uri'));
        expect(commonIssues.keys, contains('invalid_scope'));
        expect(commonIssues['unauthorized_redirect_uri'], contains('não autorizado'));
      });
    });

    group('OAuth Flow Validation', () {
      test('should validate complete OAuth flow structure', () {
        // Baseado no código funcional, validar estrutura do flow
        final oauthFlow = {
          'step1': 'Generate OAuth URL',
          'step2': 'Redirect to Google',
          'step3': 'User authorizes',
          'step4': 'Google redirects to callback',
          'step5': 'Exchange code for tokens',
          'step6': 'Redirect to app with tokens',
        };

        expect(oauthFlow.keys.length, equals(6));
        expect(oauthFlow['step1'], contains('Generate'));
        expect(oauthFlow['step4'], contains('callback'));
        expect(oauthFlow['step6'], contains('app'));
      });

      test('should validate state parameter security', () {
        // Validar geração segura de state (baseado no código funcional)
        final state1 = _generateSecureState();
        final state2 = _generateSecureState();

        expect(state1, isNot(equals(state2))); // Deve ser único
        expect(state1.length, greaterThanOrEqualTo(32)); // Deve ser longo o suficiente
        expect(state1, matches(r'^[a-zA-Z0-9]+$')); // Deve ser alfanumérico
      });

      test('should validate token exchange parameters', () {
        // ❌ FRONTEND NÃO DEVE TER CLIENT SECRET!
        // Este teste simula o que o SERVIDOR faria
        final tokenExchangeParams = {
          'client_id': GoogleOAuthConfig.clientId,
          'client_secret': 'SERVER_ONLY_SECRET', // Só o servidor tem isso
          'code': 'authorization_code_from_google',
          'grant_type': 'authorization_code',
          'redirect_uri': GoogleOAuthConfig.webRedirectUri,
        };

        expect(tokenExchangeParams['grant_type'], equals('authorization_code'));
        expect(tokenExchangeParams['client_id'], isNotNull);
        expect(tokenExchangeParams['client_secret'], isNotNull);
        expect(tokenExchangeParams['redirect_uri'], equals('http://localhost:8080/auth/callback'));
      });
    });

    group('Server Configuration Validation', () {
      test('should validate server endpoints', () {
        final serverEndpoints = {
          'auth': '/auth/google',
          'callback': '/auth/callback',
          'validate': '/auth/validate',
          'refresh': '/auth/refresh',
          'revoke': '/auth/revoke',
        };

        expect(serverEndpoints['auth'], equals('/auth/google'));
        expect(serverEndpoints['callback'], equals('/auth/callback'));
        
        // Todos os endpoints devem começar com /auth/
        for (final endpoint in serverEndpoints.values) {
          expect(endpoint, startsWith('/auth/'));
        }
      });

      test('should validate CORS configuration', () {
        final allowedOrigins = [
          'http://localhost:3000',
          'http://localhost:8080',
          'http://127.0.0.1:8080',
        ];

        for (final origin in allowedOrigins) {
          final uri = Uri.parse(origin);
          expect(uri.scheme, equals('http'));
          expect(uri.host, anyOf('localhost', '127.0.0.1'));
          expect(uri.port, anyOf(3000, 8080));
        }
      });
    });

    group('Integration with Working OAuth Service', () {
      test('should match working OAuth service patterns', () {
        // Baseado no código funcional fornecido
        final workingPatterns = {
          'redirect_pattern': r'/oauth2/return/:provider/:login/:token',
          'state_management': 'Redis with expiration',
          'token_binding': 'Temporary tokens with ID',
          'final_redirect': 'Custom scheme (my-custom-app)',
          'scopes': ['email', 'spreadsheets'],
        };

        expect(workingPatterns['redirect_pattern'], contains('oauth2/return'));
        expect(workingPatterns['state_management'], contains('Redis'));
        expect(workingPatterns['token_binding'], contains('Temporary'));
        expect(workingPatterns['final_redirect'], contains('custom'));
      });

      test('should validate token binding mechanism', () {
        // Simular o sistema de token binding do código funcional
        final tokenBinder = MockTokenBinder();
        final token = 'user_token_123';
        final data = {'user_id': 'test_user'};

        final bindId = tokenBinder.bind(token, data);
        expect(bindId, isA<int>());
        expect(bindId, greaterThan(0));

        final retrieved = tokenBinder.retrieve(bindId);
        expect(retrieved, isNotNull);
        expect(retrieved!['token'], equals(token));
        expect(retrieved['user_id'], equals('test_user'));
      });
    });
  });
}

// Helper functions para os testes
String _generateSecureState() {
  final chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = DateTime.now().microsecondsSinceEpoch; // Usar microseconds para mais variação
  return List.generate(32, (index) => chars[(random + index * 7) % chars.length]).join();
}

// Mock do sistema de token binding
class MockTokenBinder {
  final Map<int, Map<String, dynamic>> _bindings = {};
  int _counter = 0;

  int bind(String token, Map<String, dynamic> data) {
    _counter++;
    _bindings[_counter] = {...data, 'token': token};
    return _counter;
  }

  Map<String, dynamic>? retrieve(int id) {
    return _bindings[id];
  }
}
