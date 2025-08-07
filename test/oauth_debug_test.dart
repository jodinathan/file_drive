import 'package:flutter_test/flutter_test.dart';
import 'package:file_drive/src/providers/google_drive/google_drive_provider.dart';
import 'package:file_drive/src/models/oauth_types.dart';
import 'package:file_drive/src/providers/base/cloud_provider.dart';

void main() {
  group('OAuth Debug Tests', () {
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

    test('deve gerar URL OAuth correta com logs', () {
      print('\n🧪 [Test] Testando geração de URL OAuth...');
      
      final params = provider.createOAuthParams();
      print('🧪 [Test] Parâmetros OAuth: ${params.toQueryParams()}');
      
      final url = provider.urlGenerator!(params);
      print('🧪 [Test] URL gerada: $url');
      
      // Validações
      expect(url, contains('client_id='));
      expect(url, contains('redirect_uri='));
      expect(url, contains('scope='));
      expect(url, contains('state='));
      
      // Verificar se não contém scopes problemáticos
      expect(url, isNot(contains('drive.readonly')));
      
      print('✅ [Test] URL OAuth válida gerada');
    });

    test('deve simular callback OAuth com logs', () {
      print('\n🧪 [Test] Testando parsing de callback OAuth...');
      
      // Simular diferentes tipos de callback
      final successCallback = 'com.googleusercontent.apps.346650636779-58ec4t2v24ru8kj3s3t7dj46okanjman://oauth?code=test_code_123&state=test_state';
      final errorCallback = 'com.googleusercontent.apps.346650636779-58ec4t2v24ru8kj3s3t7dj46okanjman://oauth?error=access_denied&error_description=User+denied+access';
      
      print('🧪 [Test] Callback de sucesso: $successCallback');
      final successUri = Uri.parse(successCallback);
      final successOAuthCallback = OAuthCallback.fromQueryParams(successUri.queryParameters);
      print('🧪 [Test] Callback parseado: success=${successOAuthCallback.isSuccess}, code=${successOAuthCallback.code}');
      
      print('🧪 [Test] Callback de erro: $errorCallback');
      final errorUri = Uri.parse(errorCallback);
      final errorOAuthCallback = OAuthCallback.fromQueryParams(errorUri.queryParameters);
      print('🧪 [Test] Callback de erro parseado: hasError=${errorOAuthCallback.hasError}, error=${errorOAuthCallback.error}');
      
      // Validações
      expect(successOAuthCallback.isSuccess, isTrue);
      expect(successOAuthCallback.code, equals('test_code_123'));
      expect(errorOAuthCallback.hasError, isTrue);
      expect(errorOAuthCallback.error, equals('access_denied'));
      
      print('✅ [Test] Parsing de callbacks funcionando');
    });

    test('deve validar configuração do provider', () {
      print('\n🧪 [Test] Validando configuração do provider...');
      
      print('🧪 [Test] Provider name: ${provider.providerName}');
      print('🧪 [Test] Provider icon: ${provider.providerIcon}');
      print('🧪 [Test] Provider color: ${provider.providerColor}');
      print('🧪 [Test] Is authenticated: ${provider.isAuthenticated}');
      print('🧪 [Test] Status: ${provider.status}');
      
      final capabilities = provider.capabilities;
      print('🧪 [Test] Capabilities: upload=${capabilities.supportsUpload}, download=${capabilities.supportsDownload}');
      
      // Validações
      expect(provider.providerName, equals('Google Drive'));
      expect(provider.isAuthenticated, isFalse);
      expect(provider.status, equals(ProviderStatus.disconnected));
      
      print('✅ [Test] Configuração do provider válida');
    });

    test('deve mostrar informações de debug do OAuth', () {
      print('\n🧪 [Test] Informações de debug do OAuth...');
      
      final params = provider.createOAuthParams();
      
      print('🧪 [Test] === CONFIGURAÇÃO OAUTH ===');
      print('🧪 [Test] Client ID: ${params.clientId}');
      print('🧪 [Test] Redirect URI: ${params.redirectUri}');
      print('🧪 [Test] Scopes: ${params.scopes}');
      print('🧪 [Test] State: ${params.state}');
      
      print('🧪 [Test] === URL COMPLETA ===');
      final url = provider.urlGenerator!(params);
      print('🧪 [Test] $url');
      
      print('🧪 [Test] === CALLBACK ESPERADO ===');
      print('🧪 [Test] Scheme: com.googleusercontent.apps.346650636779-58ec4t2v24ru8kj3s3t7dj46okanjman');
      print('🧪 [Test] Formato: scheme://oauth?code=...&state=...');
      
      print('🧪 [Test] === POSSÍVEIS PROBLEMAS ===');
      if (params.redirectUri.contains('localhost:8080')) {
        print('⚠️  [Test] Redirect URI usa localhost - deve estar no Google Console');
      }
      if (params.scopes.any((s) => s.contains('readonly'))) {
        print('⚠️  [Test] Scope readonly detectado - pode causar bloqueio');
      }
      
      print('✅ [Test] Debug completo');
    });

    test('deve simular fluxo OAuth completo com logs', () async {
      print('\n🧪 [Test] Simulando fluxo OAuth completo...');
      
      // Não vamos realmente executar o OAuth, apenas validar a estrutura
      print('🧪 [Test] 1. Gerando parâmetros OAuth...');
      final params = provider.createOAuthParams();
      expect(params.clientId, isNotNull);
      
      print('🧪 [Test] 2. Gerando URL de autenticação...');
      final url = provider.urlGenerator!(params);
      expect(url, contains('accounts.google.com'));
      
      print('🧪 [Test] 3. Simulando callback de sucesso...');
      final callbackUrl = 'com.googleusercontent.apps.346650636779-58ec4t2v24ru8kj3s3t7dj46okanjman://oauth?code=test_code&state=${params.state}';
      final uri = Uri.parse(callbackUrl);
      final callback = OAuthCallback.fromQueryParams(uri.queryParameters);
      expect(callback.isSuccess, isTrue);
      
      print('🧪 [Test] 4. Validando código recebido...');
      expect(callback.code, equals('test_code'));
      expect(callback.state, equals(params.state));
      
      print('✅ [Test] Fluxo OAuth estruturalmente correto');
    });
  });
}
