/// 🔧 CONFIGURAÇÃO DO APP DE EXEMPLO - ATUALIZADA
/// Copie para config/config.dart e configure com suas credenciais reais
library;

/// 📱 CONFIGURAÇÃO DO CLIENTE
class AppConfig {
  /// 🖥️ SERVIDOR OAUTH LOCAL
  /// Configure o servidor OAuth primeiro e mantenha esta URL
  static const String serverBaseUrl = 'http://localhost:8080';
  
  /// 🔐 GOOGLE CLIENT ID (para mobile/web)
  /// Configure no Google Cloud Console > APIs & Services > Credentials
  /// Para mobile: Android/iOS OAuth 2.0 Client ID
  /// Para web: Web application OAuth 2.0 Client ID
  static const String googleClientId = 'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
  
  /// 📱 CUSTOM URL SCHEME para mobile/desktop
  /// Configure no pubspec.yaml e no Google Console como redirect URI
  /// Formato: com.seudominio.nomeapp://oauth
  static const String customScheme = 'com.example.filecloud://oauth';
  
  /// 🌐 REDIRECT URI para Web
  /// Para desenvolvimento local: http://localhost:3000
  /// Para produção: https://yourdomain.com/oauth/callback
  static const String webRedirectUri = 'http://localhost:3000';
  
  /// ⚙️ CONFIGURAÇÕES DO WIDGET
  static const int minFileSelection = 1;
  static const int maxFileSelection = 5;
  
  /// 🎨 CONFIGURAÇÕES DE TEMA
  static const bool useDarkTheme = false;
  static const bool useSystemTheme = true;
}

/// 📝 INSTRUÇÕES COMPLETAS DE CONFIGURAÇÃO:
/// 
/// 🏗️ 1. CONFIGURAR GOOGLE CLOUD CONSOLE:
///    a) Vá em: https://console.cloud.google.com/
///    b) Crie um projeto ou selecione um existente
///    c) Ative a API do Google Drive:
///       - APIs & Services > Library
///       - Procure "Google Drive API" e ative
///    d) Configure OAuth consent screen:
///       - OAuth consent screen > External
///       - Preencha nome do app, email, etc.
///       - Adicione scopes: drive.readonly, drive.file
///    e) Crie credenciais OAuth 2.0:
///       - Credentials > Create Credentials > OAuth 2.0 Client ID
///       - Para Web: Authorized redirect URIs = http://localhost:3000
///       - Para Android: SHA-1 fingerprint + package name
///       - Para iOS: Bundle ID
/// 
/// 🖥️ 2. CONFIGURAR SERVIDOR OAUTH:
///    a) Vá para: ../server/lib/config.dart
///    b) Configure as credenciais do servidor:
///       - googleClientId: Web application client ID
///       - googleClientSecret: Web application client secret
///       - redirectUri: http://localhost:8080/auth/callback
///    c) Inicie o servidor: dart run ../server/lib/main.dart
///    d) Teste em: http://localhost:8080/health
/// 
/// 📱 3. CONFIGURAR ESTE ARQUIVO:
///    a) Copie para config/config.dart
///    b) Substitua YOUR_GOOGLE_CLIENT_ID pelas credenciais reais
///    c) Para mobile, use o Client ID específico da plataforma
///    d) Para web, pode usar o mesmo Client ID do servidor
/// 
/// 🧪 4. TESTAR:
///    a) flutter run -d chrome (para web)
///    b) flutter run -d android (para Android)
///    c) flutter run -d ios (para iOS, apenas macOS)
/// 
/// ⚠️ IMPORTANTE - SEGURANÇA:
/// - Nunca commite config/config.dart com credenciais reais
/// - Mantenha config/config.dart no .gitignore
/// - Use credenciais diferentes para dev/prod
/// - Para produção, use HTTPS everywhere
/// 
/// 🔧 TROUBLESHOOTING:
/// - OAuth error: Verifique redirect URIs no Google Console
/// - Server error: Confirme que servidor está rodando na porta 8080
/// - Network error: Verifique firewall/proxy
/// - Token error: Confirme scopes no Google Console