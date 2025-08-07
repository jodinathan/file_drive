# File Drive - Etapa 1: Autenticação OAuth e Interface Base

## Objetivo da Etapa 1
Criar a estrutura base do widget com foco na **autenticação OAuth do Google Drive**. Ao final desta etapa, o usuário deve conseguir:
- Ver a interface de duas colunas
- Selecionar o provedor Google Drive
- Realizar login OAuth e obter token válido
- Ver confirmação visual de autenticação bem-sucedida

## Escopo Específico da Etapa 1

### ✅ O que SERÁ implementado:
- Layout de duas colunas responsivo
- Sistema de abas para provedores (inicialmente só Google Drive)
- Fluxo completo de OAuth para Google Drive
- Servidor de exemplo para testes
- Estados visuais: não autenticado, autenticando, autenticado
- Tipos sólidos para OAuth
- Configuração básica do widget

### ❌ O que NÃO será implementado:
- Listagem de arquivos/pastas
- Upload de arquivos
- Download de arquivos
- Operações de arquivo (delete, rename, etc.)
- Barra de progresso de upload
- Navegação por diretórios
- Seleção de arquivos

## Arquitetura da Etapa 1

### 1. Estrutura de Classes Base

#### 1.1 CloudProvider (Simplificado para OAuth)
```dart
abstract class CloudProvider {
  // Apenas métodos de autenticação para Etapa 1
  Future<bool> authenticate();
  Future<void> logout();
  bool get isAuthenticated;
  
  // Metadados do provedor
  String get providerName;
  String get providerIcon;
  Color get providerColor;
  
  // Status de conexão
  ProviderStatus get status;
}

enum ProviderStatus {
  disconnected,
  connecting,
  connected,
  error,
}
```

#### 1.2 OAuthCloudProvider (Foco em Autenticação)
```dart
abstract class OAuthCloudProvider extends CloudProvider {
  final Function(OAuthParams) urlGenerator;
  
  OAuthCloudProvider({required this.urlGenerator});
  
  Future<String> generateOAuthUrl(OAuthParams params);
  Future<AuthResult> handleOAuthCallback(OAuthCallback callback);
  Future<bool> validateToken();
  Future<void> refreshToken();
}
```

#### 1.3 GoogleDriveProvider (Apenas OAuth)
```dart
class GoogleDriveProvider extends OAuthCloudProvider {
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  
  GoogleDriveProvider({
    required Function(OAuthParams) urlGenerator,
  }) : super(urlGenerator: urlGenerator);
  
  @override
  String get providerName => 'Google Drive';
  
  @override
  String get providerIcon => 'assets/icons/google_drive.svg';
  
  @override
  Color get providerColor => const Color(0xFF4285F4);
  
  // Implementação específica do OAuth Google Drive
}
```

### 2. Modelos de Dados (Etapa 1)

#### 2.1 OAuth Types
```dart
class OAuthParams {
  final String clientId;
  final String redirectUri;
  final List<String> scopes;
  final String? state;
  final String? codeChallenge;
  final String? codeChallengeMethod;
  
  OAuthParams({
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    this.state,
    this.codeChallenge,
    this.codeChallengeMethod,
  });
}

class OAuthCallback {
  final String? code;
  final String? error;
  final String? errorDescription;
  final String? state;
  
  OAuthCallback({this.code, this.error, this.errorDescription, this.state});
  
  bool get isSuccess => code != null && error == null;
  bool get hasError => error != null;
}

class AuthResult {
  final bool success;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? error;
  
  AuthResult({
    required this.success,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.error,
  });
}
```

#### 2.2 Widget Configuration (Simplificado)
```dart
class FileDriveConfig {
  final List<CloudProvider> providers;
  final FileDriveTheme? theme;
  
  FileDriveConfig({
    required this.providers,
    this.theme,
  });
}

class FileDriveTheme {
  final ColorScheme colorScheme;
  final TypographyTheme typography;
  final LayoutTheme layout;
  
  FileDriveTheme({
    required this.colorScheme,
    required this.typography,
    this.layout = const LayoutTheme(),
  });
}
```

### 3. Interface da Etapa 1

#### 3.1 Layout Principal
```dart
class FileDriveWidget extends StatefulWidget {
  final FileDriveConfig config;
  
  const FileDriveWidget({Key? key, required this.config}) : super(key: key);
}

class _FileDriveWidgetState extends State<FileDriveWidget> {
  CloudProvider? selectedProvider;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Coluna esquerda - Lista de provedores (30%)
        Expanded(
          flex: 3,
          child: ProviderSidebar(
            providers: widget.config.providers,
            selectedProvider: selectedProvider,
            onProviderSelected: (provider) {
              setState(() => selectedProvider = provider);
            },
          ),
        ),
        // Coluna direita - Conteúdo do provedor (70%)
        Expanded(
          flex: 7,
          child: ProviderContent(provider: selectedProvider),
        ),
      ],
    );
  }
}
```

#### 3.2 Sidebar de Provedores
```dart
class ProviderSidebar extends StatelessWidget {
  final List<CloudProvider> providers;
  final CloudProvider? selectedProvider;
  final Function(CloudProvider) onProviderSelected;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            child: Text('Provedores', style: Theme.of(context).textTheme.headline6),
          ),
          // Lista de provedores
          Expanded(
            child: ListView.builder(
              itemCount: providers.length,
              itemBuilder: (context, index) {
                final provider = providers[index];
                return ProviderTab(
                  provider: provider,
                  isSelected: provider == selectedProvider,
                  onTap: () => onProviderSelected(provider),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 3.3 Tab do Provedor
```dart
class ProviderTab extends StatelessWidget {
  final CloudProvider provider;
  final bool isSelected;
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : null,
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: Colors.blue) : null,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: provider.providerColor,
          child: Icon(Icons.cloud, color: Colors.white),
        ),
        title: Text(provider.providerName),
        subtitle: _buildStatusIndicator(),
        onTap: onTap,
      ),
    );
  }
  
  Widget _buildStatusIndicator() {
    switch (provider.status) {
      case ProviderStatus.connected:
        return Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 4),
            Text('Conectado', style: TextStyle(color: Colors.green)),
          ],
        );
      case ProviderStatus.connecting:
        return Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 4),
            Text('Conectando...'),
          ],
        );
      case ProviderStatus.error:
        return Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 16),
            SizedBox(width: 4),
            Text('Erro', style: TextStyle(color: Colors.red)),
          ],
        );
      default:
        return Text('Desconectado');
    }
  }
}
```

#### 3.4 Conteúdo do Provedor
```dart
class ProviderContent extends StatelessWidget {
  final CloudProvider? provider;
  
  @override
  Widget build(BuildContext context) {
    if (provider == null) {
      return _buildEmptyState();
    }
    
    if (provider!.isAuthenticated) {
      return _buildAuthenticatedState();
    }
    
    return _buildAuthenticationScreen();
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Selecione um provedor para começar'),
        ],
      ),
    );
  }
  
  Widget _buildAuthenticatedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text('Conectado com sucesso!'),
          SizedBox(height: 8),
          Text('Token OAuth obtido e validado'),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => provider!.logout(),
            child: Text('Desconectar'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAuthenticationScreen() {
    return AuthenticationScreen(provider: provider!);
  }
}
```

## Servidor de Exemplo (Etapa 1)

### Estrutura do Servidor OAuth
```
example_server/
├── lib/
│   ├── main.dart              # Servidor principal
│   ├── oauth_handler.dart     # Lógica OAuth
│   ├── config.dart           # Configurações
│   └── cors_middleware.dart  # CORS para Flutter Web
├── web/
│   ├── index.html           # Página inicial
│   └── oauth_callback.html  # Callback OAuth
└── pubspec.yaml
```

### Funcionalidades do Servidor
1. **Endpoint de Autorização**: `/auth/google`
2. **Callback OAuth**: `/auth/google/callback`
3. **Validação de Token**: `/auth/validate`
4. **Refresh Token**: `/auth/refresh`
5. **CORS**: Configurado para Flutter Web

## Implementação por Fases (Etapa 1)

### Semana 1: Setup e Estrutura Base
1. **Setup do Projeto**
   - Configurar dependências básicas
   - Estrutura de pastas
   - Configuração Flutter Web

2. **Servidor de Exemplo**
   - Implementar servidor OAuth
   - Configurar endpoints básicos
   - Testar fluxo OAuth manualmente

3. **Modelos de Dados**
   - Implementar tipos OAuth
   - Criar classes de configuração
   - Definir enums e constantes

### Semana 2: Interface e Integração
1. **Layout Base**
   - Implementar layout de duas colunas
   - Criar sidebar de provedores
   - Implementar estados visuais

2. **Google Drive Provider**
   - Integração com fl_cloud_storage
   - Implementar fluxo OAuth completo
   - Validação e refresh de tokens

3. **Testes de Integração**
   - Testar fluxo completo
   - Validar estados da interface
   - Corrigir bugs encontrados

## Critérios de Sucesso da Etapa 1

### ✅ Funcionalidades Obrigatórias:
1. Interface de duas colunas responsiva
2. Seleção de provedor Google Drive
3. Fluxo OAuth completo funcionando
4. Token válido obtido e armazenado
5. Estados visuais corretos (conectado/desconectado)
6. Servidor de exemplo funcionando
7. Logout funcionando

### 🧪 Testes Necessários:
1. Teste de fluxo OAuth completo
2. Teste de validação de token
3. Teste de refresh de token
4. Teste de logout
5. Teste de estados da interface
6. Teste de responsividade

### 📋 Entregáveis:
1. Widget funcional com autenticação
2. Servidor de exemplo configurado
3. Documentação de setup
4. Testes unitários e de integração
5. Exemplo de uso básico

## Próximos Passos para Etapa 2
Após completar a Etapa 1, a Etapa 2 focará em:
- Listagem de arquivos e pastas
- Upload com progresso
- Download de arquivos
- Operações de arquivo (delete, rename)
- Navegação por diretórios
- Seleção múltipla de arquivos
