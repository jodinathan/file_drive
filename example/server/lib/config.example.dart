/// 🔧 CONFIGURAÇÃO DO SERVIDOR OAUTH - EXEMPLO
/// Copie para config.dart e preencha com suas credenciais do Google Cloud Console
library;

/// 🖥️ CONFIGURAÇÃO DO SERVIDOR
class ServerConfig {
  /// 🖥️ SERVIDOR LOCAL
  static const String host = 'localhost';
  static const int port = 8080;
  static const String baseUrl = 'http://$host:$port';
  
  /// 📍 ENDPOINTS
  static const String authEndpoint = '/auth/google';
  static const String callbackEndpoint = '/auth/callback';
  static const String tokensEndpoint = '/auth/tokens';
  
  /// 🔐 CREDENCIAIS GOOGLE OAUTH2 (SUBSTITUA COM SUAS!)
  /// Obtenha em: https://console.cloud.google.com/apis/credentials
  static const String googleClientId = 'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
  static const String googleClientSecret = 'YOUR_GOOGLE_CLIENT_SECRET';
  
  /// 🌐 URLs DA API GOOGLE OAUTH2
  static const String googleAuthUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String googleTokenUrl = 'https://oauth2.googleapis.com/token';
  
  /// 🎯 ESCOPOS NECESSÁRIOS PARA GOOGLE DRIVE
  static const List<String> requiredScopes = [
    'https://www.googleapis.com/auth/drive', // Acesso completo ao Drive
    'https://www.googleapis.com/auth/userinfo.profile', // Perfil do usuário
    'https://www.googleapis.com/auth/userinfo.email', // Email do usuário
  ];
  
  /// 🔗 REDIRECT URI CONFIGURADO NO GOOGLE CONSOLE
  /// Para desenvolvimento local, configure no Google Console:
  /// - Web: http://localhost:8080/auth/callback
  /// - Mobile: com.example.filecloud://oauth (configure no pubspec do app)
  static const String redirectUri = 'http://localhost:8080/auth/callback';
  
  /// 📱 CUSTOM SCHEME PARA MOBILE (deve coincidir com o app Flutter)
  static const String mobileScheme = 'com.example.filecloud';
  
  /// ⏰ TEMPO DE EXPIRAÇÃO DO STATE (em minutos)
  static const int stateExpirationMinutes = 10;
}

/// 📝 INSTRUÇÕES DE CONFIGURAÇÃO:
/// 
/// 1. Acesse: https://console.cloud.google.com/
/// 2. Crie um novo projeto ou selecione um existente
/// 3. Ative a Google Drive API:
///    - Vá em APIs & Services > Library
///    - Procure por "Google Drive API" e ative
/// 4. Crie credenciais OAuth 2.0:
///    - Vá em APIs & Services > Credentials
///    - Click "Create Credentials" > "OAuth 2.0 Client IDs"
///    - Tipo de aplicação: "Web application"
///    - Name: "File Cloud Example"
///    - Authorized redirect URIs: http://localhost:8080/auth/callback
/// 5. Copie o Client ID e Client Secret para este arquivo
/// 6. Para mobile, crie também credenciais do tipo "Android" ou "iOS"
///    e configure o esquema personalizado
///
/// ⚠️ IMPORTANTE: 
/// - Nunca commite o arquivo config.dart com suas credenciais!
/// - Mantenha sempre o config.dart no .gitignore
/// - Use este arquivo como template apenas