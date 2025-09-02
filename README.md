# File Cloud Widget

Um widget Flutter para facilitar o acesso aos arquivos de provedores de serviços de nuvem (Google Drive, Dropbox, OneDrive, etc.) com autenticação OAuth2 segura, navegação de arquivos, upload/download com progresso, e modo de seleção de arquivos.

## 🚀 Início Rápido

### 1. Executar o Exemplo

```bash
# Configuração inicial
cd example
./run.sh setup

# Configure suas credenciais Google em example/server/lib/config.dart
# Veja instruções em example/README.md

# Executar servidor OAuth
./run.sh server

# Em outro terminal, executar o app
./run.sh app
```

### 2. Configuração do Google Drive

1. **Google Cloud Console**: https://console.cloud.google.com/
2. **Ativar**: Google Drive API
3. **Criar**: Credenciais OAuth 2.0 (Web Application)
4. **Redirect URI**: `http://localhost:8080/auth/callback`
5. **Configurar**: `example/server/lib/config.dart`

Instruções detalhadas: [`example/README.md`](example/README.md)

## 📦 Instalação

Adicione ao seu `pubspec.yaml`:

```yaml
dependencies:
  file_cloud:
    git: https://github.com/seu-usuario/file_cloud.git
```

## 💡 Uso Básico

```dart
import 'package:file_cloud/file_cloud.dart';

FileCloudWidget(
  providers: [
    // Google Drive configuration
    ProviderConfigurationFactories.googleDrive(
      generateAuthUrl: (state) => 'https://your-server.com/auth/google?state=$state',
      generateTokenUrl: (state) => 'https://your-server.com/auth/tokens/$state',
      redirectScheme: 'myapp://oauth',
      requiredScopes: {
        OAuthScope.readFiles,
        OAuthScope.writeFiles,
        OAuthScope.createFolders,
      },
    ),
    // Local server for development
    ProviderConfigurationFactories.localServer(
      generateAuthUrl: (state) => 'http://localhost:8080/auth/local?state=$state',
      generateTokenUrl: (state) => 'http://localhost:8080/auth/tokens/$state',
      redirectScheme: 'myapp://oauth',
      displayName: 'Local Storage',
    ),
  ],
  accountStorage: SharedPreferencesAccountStorage(),
  selectionConfig: SelectionConfig(
    minSelection: 1,
    maxSelection: 5,
    allowedMimeTypes: ['image/*', 'application/pdf'],
    onSelectionConfirm: (files) {
      print('${files.length} arquivos selecionados');
    },
  ),
)
```

### Funcionalidades Disponíveis

- **Multi-Provider**: Suporte a múltiplos provedores simultâneos
- **Busca com Debounce**: Busca inteligente com 400ms de debounce
- **Infinite Scroll**: Paginação automática com 50 itens por página  
- **Filtros MIME**: Seleção de arquivos por tipo (images/*, application/pdf, etc.)
- **Adaptação por Capabilities**: UI se adapta às funcionalidades do provider
- **Seguro**: Zero client secrets no código do app

## 🏗️ Arquitetura Implementada

### ✅ Componentes Completos

- **Widget Principal**: FileCloudWidget totalmente funcional
- **Multi-Provider**: Configuração flexível via ProviderConfiguration  
- **OAuth2**: Fluxo seguro sem client secrets no app
- **Google Drive**: Provider completo com API v3
- **Local Server**: Provider para desenvolvimento/testes
- **Navegação**: Sistema completo com histórico e breadcrumbs
- **Upload/Download**: Com progresso e gestão de queue
- **Busca**: Com debounce inteligente de 400ms
- **Infinite Scroll**: Paginação automática
- **Seleção de Arquivos**: Com filtros MIME type
- **Adaptação UI**: Baseada em capabilities dos providers
- **Armazenamento**: SharedPreferences para contas
- **Tema**: Material 3 completo  
- **i18n**: Inglês e Português
- **Testes**: Cobertura dos modelos principais

### 🎯 Funcionalidades Avançadas

- **Capabilities Adaptation**: UI se adapta automaticamente às funcionalidades
- **MIME Filtering**: Filtros inteligentes (image/*, application/pdf, etc.)
- **Account Management**: Múltiplas contas por provider
- **Error Handling**: Tratamento robusto de erros de rede
- **Retry Logic**: Reativação automática de tokens expirados

## 📁 Estrutura do Projeto

```
lib/
├── src/
│   ├── models/          # FileEntry, ProviderConfiguration, SelectionConfig
│   ├── providers/       # Google Drive, Local Server, Custom providers
│   ├── widgets/         # FileCloudWidget, SearchBar, NavigationBar
│   ├── managers/        # Upload, Navigation, DragDrop managers
│   ├── storage/         # Account storage (SharedPreferences)
│   ├── auth/           # OAuth2 flow sem client secrets
│   ├── theme/          # Material 3 + constantes
│   ├── utils/          # Logging, image utils
│   └── l10n/           # Inglês e Português (i18n)
├── file_cloud.dart    # API pública exportada
│
example/
├── server/             # Servidor OAuth de exemplo (Dart)
├── app/               # App Flutter demonstração completa
├── README.md          # Guia de configuração detalhado
└── run.sh            # Scripts de execução
```

## 🔧 Desenvolvimento

### Executar Testes

```bash
flutter test
```

### Análise de Código

```bash
dart analyze lib/src --fatal-infos
```

### Gerar Localizações

```bash
flutter gen-l10n
```

## 📋 Status do Projeto

- [x] **Fase 1**: Reestruturação da arquitetura base (ProviderConfiguration)
- [x] **Fase 2**: Implementação de funcionalidades (busca, infinite scroll, filtros)
- [x] **Fase 3**: Padronização e capabilities adaptation
- [x] **Fase 4**: Limpeza, migração de APIs e integração

### ✅ Concluído (Agosto 2025)

- Refatoração completa seguindo RULES.md
- API unificada com ProviderConfiguration  
- Remoção de client secrets do código
- Widget totalmente funcional com todas as features
- Exemplos e documentação atualizados

### 🎯 Próximos Passos

- [ ] **Novos Providers**: OneDrive, Dropbox, AWS S3
- [ ] **Performance**: Otimizações de carregamento e cache
- [ ] **Testes E2E**: Testes de integração completos
- [ ] **CI/CD**: Pipeline automatizado

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch: `git checkout -b feature/nova-funcionalidade`
3. Commit: `git commit -m 'Add nova funcionalidade'`
4. Push: `git push origin feature/nova-funcionalidade`
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja [LICENSE](LICENSE) para detalhes.

## 🆘 Suporte

- **Configuração**: Veja [`example/README.md`](example/README.md)
- **Issues**: Use o GitHub Issues
- **Discussões**: Use o GitHub Discussions

---

**Status atual**: ✅ Pronto para produção - Refatoração completa finalizada (Agosto 2025)