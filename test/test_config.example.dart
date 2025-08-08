/// Template de configuração para testes
/// 
/// IMPORTANTE: 
/// 1. Copie este arquivo para test_config.dart
/// 2. Preencha com suas credenciais reais do Google OAuth
/// 3. O arquivo test_config.dart NÃO deve ser commitado no git
library;

/// Configuração OAuth para Google Drive (usar em testes)
class GoogleOAuthConfig {
  /// Client ID do Google OAuth Console
  /// Obtenha em: https://console.cloud.google.com/apis/credentials
  static const String clientId = 'YOUR_GOOGLE_CLIENT_ID_HERE.apps.googleusercontent.com';
  
  /// Client Secret do Google OAuth Console
  static const String clientSecret = 'YOUR_GOOGLE_CLIENT_SECRET_HERE';
  
  /// Redirect URIs para diferentes plataformas
  static const String webRedirectUri = 'http://localhost:8080/auth/callback';
  static const String customSchemeRedirectUri = 'com.googleusercontent.apps.YOUR_CLIENT_ID_NUMBER';
  
  /// Escopos do Google Drive
  static const List<String> safeScopes = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/userinfo.profile',
    'https://www.googleapis.com/auth/userinfo.email',
  ];
  
  /// URL base para autenticação
  static const String authBaseUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  
  /// URL para troca de tokens
  static const String tokenUrl = 'https://oauth2.googleapis.com/token';
  
  /// URL para validação de tokens
  static const String tokenInfoUrl = 'https://oauth2.googleapis.com/tokeninfo';
  
  /// URL para revogar tokens
  static const String revokeUrl = 'https://oauth2.googleapis.com/revoke';
}

/// Configuração do servidor de teste
class TestServerConfig {
  static const String host = 'localhost';
  static const int port = 8080;
  static const String baseUrl = 'http://$host:$port';
  
  /// Endpoints do servidor de teste
  static const String authEndpoint = '/auth/google';
  static const String callbackEndpoint = '/auth/callback';
  static const String refreshEndpoint = '/auth/refresh';
  static const String validateEndpoint = '/auth/validate';
  static const String revokeEndpoint = '/auth/revoke';
}

/// Configurações para testes
class TestConfig {
  /// Timeout para requisições HTTP em testes
  static const Duration httpTimeout = Duration(seconds: 10);
  
  /// Delay entre testes para evitar rate limiting
  static const Duration testDelay = Duration(milliseconds: 100);
  
  /// Mock data para testes
  static const String mockAccessToken = 'mock_access_token_for_tests';
  static const String mockRefreshToken = 'mock_refresh_token_for_tests';
  static const String mockAuthCode = 'mock_auth_code_for_tests';
  static const String mockState = 'mock_state_for_tests';
  
  /// User info mock para testes
  static const Map<String, dynamic> mockUserInfo = {
    'id': 'mock_user_id',
    'email': 'test@example.com',
    'name': 'Test User',
    'picture': 'https://example.com/avatar.jpg',
  };
}