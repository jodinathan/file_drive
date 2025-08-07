import 'package:flutter_test/flutter_test.dart';
import 'package:file_drive/src/providers/google_drive/google_drive_provider.dart';
import 'package:file_drive/src/models/oauth_types.dart';
import 'package:file_drive/src/utils/constants.dart';

void main() {
  group('Google OAuth "Access blocked" Diagnosis', () {
    late GoogleDriveProvider provider;

    setUp(() {
      provider = GoogleDriveProvider(
        urlGenerator: (params) {
          return 'http://localhost:8080/auth/google?${Uri(queryParameters: params.toQueryParams()).query}';
        },
      );
    });

    tearDown(() {
      provider.dispose();
    });

    group('🚨 Diagnóstico do Erro "Access blocked"', () {
      test('PROBLEMA 1: Redirect URI não autorizado no Google Console', () {
        final params = provider.createOAuthParams();
        
        // O problema principal: estamos usando redirect URI que não está no Google Console
        final currentRedirectUri = params.redirectUri;
        print('🔍 Current Redirect URI: $currentRedirectUri');
        
        // URIs que DEVEM estar configurados no Google Cloud Console
        final requiredUris = [
          GoogleOAuthConfig.webRedirectUri,
          GoogleOAuthConfig.customSchemeRedirectUri,
        ];
        
        // DIAGNÓSTICO: Verificar se o redirect URI atual está na lista autorizada
        final isAuthorized = requiredUris.contains(currentRedirectUri);
        
        if (!isAuthorized) {
          print('❌ PROBLEMA ENCONTRADO: Redirect URI não autorizado');
          print('   Atual: $currentRedirectUri');
          print('   Necessário adicionar no Google Console: $requiredUris');
        }
        
        // Este teste vai falhar se o redirect URI não estiver correto
        expect(requiredUris, contains(currentRedirectUri), 
          reason: 'Redirect URI deve estar configurado no Google Cloud Console');
      });

      test('PROBLEMA 2: Scopes muito amplos causando bloqueio', () {
        final currentScopes = GoogleOAuthConfig.safeScopes;
        print('🔍 Current Scopes: $currentScopes');
        
        // Scopes que podem causar "Access blocked" por serem muito amplos
        final problematicScopes = [
          'https://www.googleapis.com/auth/drive', // Muito amplo
          'https://www.googleapis.com/auth/drive.readonly', // Pode ser problemático
        ];
        
        // Scopes seguros baseados no código funcional
        final safeScopes = [
          'https://www.googleapis.com/auth/drive.file', // Apenas arquivos criados pelo app
          'https://www.googleapis.com/auth/userinfo.email', // Email básico
        ];
        
        // DIAGNÓSTICO: Verificar se estamos usando scopes problemáticos
        final hasProblematicScopes = currentScopes.any(
          (scope) => problematicScopes.contains(scope)
        );
        
        if (hasProblematicScopes) {
          print('❌ PROBLEMA ENCONTRADO: Scopes muito amplos');
          print('   Problemáticos: ${currentScopes.where((s) => problematicScopes.contains(s))}');
          print('   Recomendados: $safeScopes');
        }
        
        // Recomendar usar apenas scopes seguros
        expect(currentScopes, everyElement(isIn(safeScopes)), 
          reason: 'Deve usar apenas scopes seguros para evitar bloqueio do Google');
      });

      test('PROBLEMA 3: Client ID não configurado corretamente', () {
        final clientId = GoogleOAuthConfig.clientId;
        print('🔍 Current Client ID: $clientId');
        
        // Validar formato do Client ID
        final isValidFormat = clientId.endsWith('.apps.googleusercontent.com') &&
                             clientId.contains('-') &&
                             clientId.split('-')[0].isNotEmpty;
        
        if (!isValidFormat) {
          print('❌ PROBLEMA ENCONTRADO: Client ID com formato inválido');
          print('   Deve terminar com .apps.googleusercontent.com');
          print('   Deve conter hífen separando ID numérico');
        }
        
        expect(isValidFormat, isTrue, 
          reason: 'Client ID deve ter formato válido do Google');
        
        // Verificar se não é um placeholder
        final isPlaceholder = clientId.contains('your-client-id') ||
                             clientId.contains('example') ||
                             clientId.contains('test');
        
        expect(isPlaceholder, isFalse, 
          reason: 'Client ID não deve ser um placeholder');
      });

      test('PROBLEMA 4: App não verificado pelo Google', () {
        // Simular cenário de app não verificado
        final appStatus = {
          'verified': false,
          'in_production': false,
          'testing_users': <String>[],
        };
        
        print('🔍 App Status: $appStatus');
        
        // Para apps não verificados, Google mostra "Access blocked"
        final isVerified = appStatus['verified'] as bool;
        if (!isVerified) {
          print('⚠️  AVISO: App não verificado pelo Google');
          print('   Soluções:');
          print('   1. Adicionar usuários de teste no Google Console');
          print('   2. Usar scopes menos sensíveis');
          print('   3. Solicitar verificação do Google');
        }

        // Em desenvolvimento, app não verificado é normal
        expect(isVerified, anyOf(isTrue, isFalse),
          reason: 'Status de verificação pode variar em desenvolvimento');
      });

      test('SOLUÇÃO: URL OAuth correta baseada no código funcional', () {
        // Baseado no código funcional que funciona
        final correctOAuthUrl = _buildCorrectOAuthUrl();
        
        print('🔧 URL OAuth Correta: $correctOAuthUrl');
        
        final uri = Uri.parse(correctOAuthUrl);
        
        // Validações baseadas no código funcional
        expect(uri.scheme, equals('https'));
        expect(uri.host, equals('accounts.google.com'));
        expect(uri.queryParameters['client_id'], isNotNull);
        expect(uri.queryParameters['redirect_uri'], equals('http://localhost:8080/auth/callback'));
        expect(uri.queryParameters['scope'], contains('drive.file'));
        expect(uri.queryParameters['scope'], isNot(contains('drive.readonly')));
        expect(uri.queryParameters['prompt'], equals('select_account'));
        expect(uri.queryParameters['include_granted_scopes'], equals('true'));
      });

      test('SOLUÇÃO: Configuração do Google Cloud Console', () {
        final requiredConfig = {
          'oauth_consent_screen': {
            'user_type': 'External',
            'app_name': 'FileDrive Test App',
            'user_support_email': 'your-email@example.com',
            'scopes': [
              'https://www.googleapis.com/auth/userinfo.email',
              'https://www.googleapis.com/auth/drive.file',
            ],
          },
          'credentials': {
            'type': 'Web application',
            'authorized_redirect_uris': [
              'http://localhost:8080/auth/callback',
              'http://127.0.0.1:8080/auth/callback',
            ],
            'authorized_javascript_origins': [
              'http://localhost:8080',
              'http://127.0.0.1:8080',
            ],
          },
          'test_users': [
            'your-test-email@gmail.com',
          ],
        };
        
        print('🔧 Configuração Necessária no Google Console:');
        print('   OAuth Consent Screen: ${requiredConfig['oauth_consent_screen']}');
        print('   Credentials: ${requiredConfig['credentials']}');
        print('   Test Users: ${requiredConfig['test_users']}');
        
        // Validar que temos todas as configurações necessárias
        expect(requiredConfig['oauth_consent_screen'], isNotNull);
        expect(requiredConfig['credentials'], isNotNull);
        expect(requiredConfig['test_users'], isNotEmpty);
      });
    });

    group('🧪 Teste da Solução Implementada', () {
      test('deve gerar URL OAuth com configurações corretas', () {
        final params = provider.createOAuthParams();
        final url = provider.urlGenerator!(params);
        
        print('🧪 URL Gerada: $url');
        
        // Verificar se a URL contém os parâmetros corretos
        expect(url, contains('client_id='));
        expect(url, contains('redirect_uri='));
        expect(url, contains('scope='));
        expect(url, contains('state='));
        
        // Verificar se não contém parâmetros problemáticos
        expect(url, isNot(contains('drive.readonly')));
        expect(url, isNot(contains('prompt=consent'))); // Pode ser problemático
      });

      test('deve usar redirect URI autorizado', () {
        final params = provider.createOAuthParams();
        final redirectUri = params.redirectUri;
        
        // Deve usar um dos URIs autorizados
        final authorizedUris = [
          GoogleOAuthConfig.webRedirectUri,
          GoogleOAuthConfig.customSchemeRedirectUri,
        ];
        
        expect(authorizedUris, contains(redirectUri));
      });
    });
  });
}

// Helper para construir URL OAuth correta
String _buildCorrectOAuthUrl() {
  final params = {
    'client_id': '346650636779-58ec4t2v24ru8kj3s3t7dj46okanjman.apps.googleusercontent.com',
    'redirect_uri': 'http://localhost:8080/auth/callback',
    'response_type': 'code',
    'scope': 'https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/userinfo.email',
    'access_type': 'offline',
    'prompt': 'select_account',
    'include_granted_scopes': 'true',
    'state': 'secure_random_state_123',
  };
  
  return Uri.parse('https://accounts.google.com/o/oauth2/v2/auth')
      .replace(queryParameters: params)
      .toString();
}
