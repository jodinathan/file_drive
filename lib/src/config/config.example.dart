/// 🔧 CONFIGURAÇÃO DE EXEMPLO DO FRONTEND
/// Copie para config.dart e preencha com suas credenciais
library;

/// 🔐 CONFIGURAÇÃO OAUTH PARA O FRONTEND
class OAuthConfig {
  /// 🔑 CLIENT ID DO GOOGLE
  /// Obtenha em: https://console.cloud.google.com/apis/credentials
  static const String clientId = 'YOUR_CLIENT_ID.apps.googleusercontent.com';
  
  /// 🔒 CLIENT SECRET DO GOOGLE (se necessário)
  static const String clientSecret = 'YOUR_CLIENT_SECRET';
  
  /// 🔗 REDIRECT URIs
  static const String webRedirectUri = 'http://localhost:8080/auth/callback';
  
  /// 🔗 CUSTOM SCHEME REDIRECT URI
  /// Extraído automaticamente do clientId
  static String get customSchemeRedirectUri {
    final parts = clientId.split('-');
    if (parts.isNotEmpty && clientId != 'YOUR_CLIENT_ID.apps.googleusercontent.com') {
      final number = parts.first;
      return 'com.googleusercontent.apps.$number';
    }
    return 'com.googleusercontent.apps.YOUR_CLIENT_ID_NUMBER';
  }
  
  /// 🎯 ESCOPOS DO GOOGLE DRIVE
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/userinfo.profile',
    'https://www.googleapis.com/auth/userinfo.email',
  ];
  
  /// 🌐 URLs DA API GOOGLE OAUTH
  static const String authBaseUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String tokenInfoUrl = 'https://oauth2.googleapis.com/tokeninfo';
  static const String revokeUrl = 'https://oauth2.googleapis.com/revoke';
}