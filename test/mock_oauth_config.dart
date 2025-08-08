/// Configuração OAuth MOCK para testes unitários
/// Esta configuração é usada apenas em testes e usa valores seguros
library;

/// Configuração OAuth mock para testes
class MockOAuthConfig {
  /// 🔑 CLIENT ID MOCK para testes
  static const String clientId = '123456789-abc123defgh456ijklmno789pqrstuv.apps.googleusercontent.com';
  
  /// 🔒 CLIENT SECRET MOCK para testes
  static const String clientSecret = 'MOCK_CLIENT_SECRET_FOR_TESTS';
  
  /// 🔗 REDIRECT URIs MOCK
  static const String webRedirectUri = 'http://localhost:8080/auth/callback';
  
  /// 🔗 CUSTOM SCHEME REDIRECT URI MOCK
  static String get customSchemeRedirectUri {
    return 'com.googleusercontent.apps.123456789';
  }
  
  /// 🎯 ESCOPOS MOCK para testes
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/userinfo.profile',
    'https://www.googleapis.com/auth/userinfo.email',
  ];
  
  /// 🌐 URLs DA API GOOGLE OAUTH MOCK
  static const String authBaseUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String tokenInfoUrl = 'https://oauth2.googleapis.com/tokeninfo';
  static const String revokeUrl = 'https://oauth2.googleapis.com/revoke';
}