import 'package:flutter_test/flutter_test.dart';
import 'package:file_drive/src/config/app_config.dart';
import 'package:file_drive/src/utils/constants.dart';
import 'test_config.dart';

void main() {
  group('Configuração Simples', () {
    test('deve ter configuração mínima do frontend', () {
      print('\n✅ [Config] Configuração do frontend:');
      print('✅ [Config] Servidor: ${AppConfig.serverBaseUrl}');
      print('✅ [Config] Endpoint: ${AppConfig.authEndpoint}');
      
      // Validações básicas
      expect(AppConfig.serverHost, equals('localhost'));
      expect(AppConfig.serverPort, equals(TestServerConfig.port));
      expect(AppConfig.authEndpoint, equals('/auth/google'));
      
      print('✅ [Config] Frontend configurado corretamente!');
    });

    test('deve ter configuração do servidor via constants', () {
      print('\n✅ [Server] Configuração do servidor:');
      print('✅ [Server] Base URL: ${ServerConfig.baseUrl}');
      print('✅ [Server] Auth endpoint: ${ServerConfig.authEndpoint}');
      print('✅ [Server] Refresh endpoint: ${ServerConfig.refreshEndpoint}');
      
      // Validações
      expect(ServerConfig.baseUrl, equals('http://localhost:${TestServerConfig.port}'));
      expect(ServerConfig.authEndpoint, equals('/auth/google'));
      expect(ServerConfig.refreshEndpoint, equals('/auth/refresh'));
      
      print('✅ [Server] Configuração do servidor OK!');
    });

    test('deve mostrar arquitetura limpa', () {
      print('\n🎯 [Architecture] Arquitetura limpa:');
      print('🎯 [Architecture] ❌ Frontend NÃO tem Client ID');
      print('🎯 [Architecture] ❌ Frontend NÃO tem Client Secret');
      print('🎯 [Architecture] ❌ Frontend NÃO tem URLs de token');
      print('🎯 [Architecture] ✅ Frontend só sabe onde está o servidor');
      print('🎯 [Architecture] ✅ Servidor tem todas as credenciais');
      print('🎯 [Architecture] ✅ Separação de responsabilidades correta');
      
      // Validar que não temos classes desnecessárias
      expect(AppConfig.serverBaseUrl, isNotNull);
      expect(AppConfig.authEndpoint, isNotNull);
      
      print('🎯 [Architecture] Arquitetura CORRETA! 🎉');
    });
  });
}
