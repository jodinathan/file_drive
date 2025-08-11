/// 🔐 CONFIGURAÇÃO DO FRONTEND
/// Frontend só precisa saber onde está o servidor!
library;

/// 📱 CONFIGURAÇÃO SIMPLES DO FRONTEND
class AppConfig {
  /// 🖥️ SERVIDOR OAuth (onde buscar autenticação)
  static const String serverHost = 'localhost';
  static const int serverPort = 8080;
  static const String serverBaseUrl = 'http://$serverHost:$serverPort';
  
  /// 📍 ENDPOINT de autenticação
  static const String authEndpoint = '/auth/google';
}
