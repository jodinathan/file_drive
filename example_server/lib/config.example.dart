/// 🔧 CONFIGURAÇÃO DE EXEMPLO DO SERVIDOR OAUTH
/// Copie para config.dart e preencha com suas credenciais
library;

/// 🖥️ CONFIGURAÇÃO DO SERVIDOR
class ServerConfig {
  /// 🖥️ SERVIDOR
  static const String host = 'localhost';
  static const int port = 8080;
  static const String baseUrl = 'http://$host:$port';
  
  /// 📍 ENDPOINTS
  static const String authEndpoint = '/auth/google';
  static const String callbackEndpoint = '/auth/callback';
  static const String validateEndpoint = '/auth/validate';
  static const String refreshEndpoint = '/auth/refresh';
  static const String revokeEndpoint = '/auth/revoke';
  
  /// 🔐 CREDENCIAIS GOOGLE (SUBSTITUA!)
  static const String googleClientId = 'YOUR_CLIENT_ID.apps.googleusercontent.com';
  static const String googleClientSecret = 'YOUR_CLIENT_SECRET';
  
  /// 🌐 URLs GOOGLE OAUTH
  static const String googleAuthUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String googleTokenUrl = 'https://oauth2.googleapis.com/token';
  static const String googleRevokeUrl = 'https://oauth2.googleapis.com/revoke';
  
  /// 🎯 SCOPES SEGUROS
  static const List<String> defaultScopes = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/userinfo.email',
  ];
  
  /// 🔗 REDIRECT URI PADRÃO PARA CLIENTES
  static const String defaultClientRedirectUri = 'com.googleusercontent.apps.YOUR_CLIENT_ID://oauth';
}
