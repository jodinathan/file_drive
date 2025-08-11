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

// TODO: Widget principal será implementado em breve
// FileCloudWidget(
//   providers: [
//     GoogleDriveProvider(),
//   ],
//   accountStorage: SharedPreferencesAccountStorage(),
//   onSelectionConfirm: (files) {
//     print('Arquivos selecionados: ${files.length}');
//   },
// )
```

## 🏗️ Arquitetura Implementada

### ✅ Componentes Prontos

- **Modelos Base**: FileEntry, CloudAccount, ProviderCapabilities
- **OAuth2**: Fluxo seguro sem client secrets
- **Google Drive**: Provider completo com API v3
- **Armazenamento**: SharedPreferences para contas
- **Tema**: Material 3 completo
- **i18n**: Inglês e Português

### 🚧 Em Desenvolvimento

- **Widget Principal**: FileCloudWidget (Task 9)
- **UI Components**: Lista de provedores, navegação de arquivos
- **Modo Seleção**: Filtros por mime-type
- **Exemplos**: Servidor OAuth e app demonstração

## 📁 Estrutura do Projeto

```
lib/
├── src/
│   ├── models/          # Modelos de dados
│   ├── providers/       # Provedores de nuvem
│   ├── storage/         # Armazenamento de contas
│   ├── auth/           # Sistema OAuth2
│   ├── theme/          # Material 3 + constantes
│   └── l10n/           # Internacionalização
├── file_cloud.dart    # API pública
│
example/
├── server/             # Servidor OAuth de exemplo
├── app/               # App Flutter de exemplo  
├── README.md          # Guia de configuração
└── run.sh            # Script de execução
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

## 📋 Roadmap

- [x] **Tasks 1-8**: Arquitetura base, OAuth2, Google Drive, tema
- [ ] **Tasks 9-14**: Widgets UI, navegação, seleção de arquivos  
- [ ] **Tasks 15-20**: Testes, documentação, outros provedores

Veja o plano completo: [`plans/2025-08-11-implementacao-proposta-readme-v1.md`](plans/2025-08-11-implementacao-proposta-readme-v1.md)

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

**Status atual**: 🚧 Desenvolvimento ativo - Arquitetura base implementada