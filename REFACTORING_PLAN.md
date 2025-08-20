# 📋 PLANO DE REFATORAÇÃO - FILE_DRIVE

## 📅 Data: 2025-08-20
## 🎯 Objetivo: Adequar o projeto às especificações em RULES.md

---

## 🔍 ANÁLISE DAS DISCREPÂNCIAS PRINCIPAIS

### 1. **Configuração de Provedores Inflexível**
**Problema:** Widget recebe apenas um `OAuthConfig` único, provedores são hardcoded no método `_initializeProviders()`
**Esperado:** Widget deve receber lista de configurações de provedores como parâmetro

### 2. **Parâmetros do Widget Inadequados**
```dart
// ❌ ATUAL (inflexível):
FileCloudWidget(
  oauthConfig: OAuthConfig(...),  // Único provedor
  accountStorage: storage,
  selectionConfig: ...,
  cropConfig: ...,
)

// ✅ ESPERADO (flexível):
FileCloudWidget(
  providers: [                    // Lista de provedores configuráveis
    ProviderConfiguration(...),
    ProviderConfiguration(...),
  ],
  accountStorage: storage,
  selectionConfig: ...,
  onSelectionConfirm: ...,      // Callback obrigatório para modo seleção
)
```

### 3. **Métodos Abstratos Incompletos em BaseCloudProvider**
**Faltando:**
- `getUserProfile()` - está em AccountBasedProvider, deveria estar na base
- `refreshAuth()` - está em AccountBasedProvider, deveria estar na base
- Métodos não padronizados entre providers

### 4. **Client Secret no App**
**Violação crítica:** `OniCloudProviderConfig` tem campo `clientSecret`
**RULES.md:** "O app não pode em hipótese alguma ter o client secret"

### 5. **Funcionalidades Não Implementadas**
- ❌ Busca global com debounce (400ms)
- ❌ Infinite scroll configurado (50 itens/página)
- ❌ SelectionConfig sem filtro por mime-types
- ❌ Capabilities não usado para adaptar UI dinamicamente
- ❌ Traduções hardcoded (sem Intl.message centralizado)

---

## 🏗️ PLANO DE REFATORAÇÃO DETALHADO

### **FASE 1: REESTRUTURAÇÃO DA ARQUITETURA BASE** 
*Prioridade: CRÍTICA | Estimativa: 2-3 dias*

#### 1.1 Criar Nova Estrutura de Configuração Unificada

**Arquivo:** `lib/src/models/provider_configuration.dart`
```dart
class ProviderConfiguration {
  final CloudProviderType type;
  final String displayName;
  final Widget? logoWidget;           // Widget customizado para logo
  final String? logoAssetPath;        // Ou caminho para asset
  
  // Funções para gerar URLs OAuth (sem client secret!)
  final String Function(String state) generateAuthUrl;
  final String Function(String state) generateTokenUrl;
  final String redirectScheme;
  
  // Configurações
  final Set<OAuthScope> requiredScopes;
  final ProviderCapabilities capabilities;
  final bool requiresAccountManagement;
  
  // Métodos opcionais para customização
  final BaseCloudProvider Function()? createProvider;
}
```

**Ações:**
- ✅ Criar nova classe `ProviderConfiguration`
- ✅ Migrar lógica de `OAuthConfig` para dentro desta estrutura
- ❌ REMOVER `OniCloudProviderConfig` (tem client_secret)
- ✅ Atualizar todos imports e usos

#### 1.2 Refatorar BaseCloudProvider

**Arquivo:** `lib/src/providers/base_cloud_provider.dart`
```dart
abstract class BaseCloudProvider {
  // Configuração do provider
  ProviderConfiguration? _configuration;
  CloudAccount? _currentAccount;
  
  // Métodos de configuração
  void initialize({
    required ProviderConfiguration configuration,
    CloudAccount? account,
  });
  
  // TODOS os métodos obrigatórios (RULES.md linha 6)
  Future<FileListPage> listFolder(...);
  Future<FileEntry> createFolder(...);
  Future<void> deleteEntry(...);
  Stream<List<int>> downloadFile(...);
  Stream<UploadProgress> uploadFile(...);
  Future<FileListPage> searchByName(...);
  Future<UserProfile> getUserProfile();
  Future<CloudAccount> refreshAuth(CloudAccount account);
  ProviderCapabilities getCapabilities();
}
```

**Ações:**
- ✅ Mover métodos de `AccountBasedProvider` para `BaseCloudProvider`
- ❌ REMOVER classe `AccountBasedProvider` (fundir com base)
- ✅ Padronizar assinatura de todos métodos
- ✅ Adicionar validações e logs apropriados

#### 1.3 Atualizar FileCloudWidget

**Arquivo:** `lib/src/widgets/file_cloud_widget.dart`

**Mudanças principais:**
```dart
class FileCloudWidget extends StatefulWidget {
  // ❌ REMOVER
  // final OAuthConfig oauthConfig;
  
  // ✅ ADICIONAR
  final List<ProviderConfiguration> providers;
  
  // Resto mantém...
  final AccountStorage accountStorage;
  final SelectionConfig? selectionConfig;
  final Function(List<FileEntry>)? onSelectionConfirm; // Obrigatório se selectionConfig != null
}
```

**Método _initState():**
```dart
void initState() {
  super.initState();
  _initializeProvidersFromConfiguration(); // Novo método dinâmico
  _loadAccounts();
}

void _initializeProvidersFromConfiguration() {
  for (final config in widget.providers) {
    final provider = _createProviderInstance(config);
    provider.initialize(configuration: config);
    _providers[config.type] = provider;
  }
  
  // Selecionar primeiro provider disponível
  if (widget.providers.isNotEmpty) {
    _selectedProvider = widget.providers.first.type;
  }
}
```

**Ações:**
- ❌ REMOVER método `_initializeProviders()` hardcoded
- ✅ Criar método `_initializeProvidersFromConfiguration()`
- ✅ Adaptar toda lógica de OAuth para usar configuração do provider
- ✅ Atualizar _addAccount() para usar provider configuration

---

### **FASE 2: IMPLEMENTAÇÃO DE FUNCIONALIDADES FALTANTES**
*Prioridade: ALTA | Estimativa: 2 dias*

#### 2.1 Implementar Busca Global com Debounce

**Local:** NavigationBarWidget ou novo SearchBarWidget

```dart
class SearchBarWidget extends StatefulWidget {
  final Function(String query)? onSearch;
  final Duration debounce = const Duration(milliseconds: 400);
}
```

**Funcionalidades:**
- Timer para debounce de 400ms
- Botão X para limpar campo
- Integração com provider.searchByName()
- Loading indicator durante busca

#### 2.2 Configurar Infinite Scroll

**Local:** _buildFileNavigation() em FileCloudWidget

```dart
ListView.builder(
  controller: _scrollController,
  itemCount: _currentFiles.length + (_hasMore ? 1 : 0),
  itemBuilder: (context, index) {
    if (index == _currentFiles.length) {
      _loadMoreFiles(); // Trigger pagination
      return CircularProgressIndicator();
    }
    return _buildFileItem(_currentFiles[index]);
  },
)
```

**Implementar:**
- ScrollController com listener
- Método _loadMoreFiles() usando pageToken
- Loading indicator no final
- Configuração de 50 itens por página

#### 2.3 Melhorar SelectionConfig

**Arquivo:** `lib/src/models/selection_config.dart`

```dart
class SelectionConfig {
  final int minSelection;
  final int maxSelection;
  final bool allowFolders;
  
  // ✅ ADICIONAR
  final List<String> allowedMimeTypes; // ex: ['image/*', 'application/pdf']
  final String? mimeTypeHint;           // Texto explicativo para usuário
  
  // Callback obrigatório
  final Function(List<FileEntry>) onSelectionConfirm;
}
```

**UI para mostrar filtros:**
- Chips mostrando tipos permitidos
- Validação ao selecionar arquivo
- Mensagem quando arquivo não é permitido

---

### **FASE 3: PADRONIZAÇÃO E CAPABILITIES**
*Prioridade: MÉDIA | Estimativa: 1-2 dias*

#### 3.1 Usar Capabilities para Adaptar UI

**Local:** Vários widgets

```dart
// Em NavigationBarWidget
if (provider.getCapabilities().canUpload) {
  IconButton(icon: Icon(Icons.upload), onPressed: _uploadFiles)
}

if (provider.getCapabilities().canCreateFolders) {
  IconButton(icon: Icon(Icons.create_new_folder), onPressed: _createFolder)
}

if (provider.getCapabilities().canSearch) {
  SearchBarWidget(...)
}
```

#### 3.2 Centralizar Traduções

**Criar:** `lib/src/l10n/file_cloud_messages.dart`

```dart
class FileCloudMessages {
  static String get rootFolder => Intl.message(
    'Root Folder',
    name: 'rootFolder',
    desc: 'Name for the root folder',
  );
  
  static String get noFilesFound => Intl.message(
    'No files found',
    name: 'noFilesFound',
  );
  
  // ... todas outras strings
}
```

**Ações:**
- Identificar TODAS strings hardcoded
- Criar métodos Intl.message para cada uma
- Substituir em todo código
- Gerar arquivos .arb

---

### **FASE 4: LIMPEZA E VALIDAÇÃO**
*Prioridade: BAIXA | Estimativa: 1 dia*

#### 4.1 Remover Código Obsoleto

**Para remover:**
- `OniCloudProviderConfig` (tem client_secret)
- `AccountBasedProvider` (fundido com base)
- Métodos e classes não utilizados
- Imports desnecessários
- TODOs antigos e código comentado

#### 4.2 Atualizar Exemplo e Documentação

**Arquivo:** `example/app/lib/main.dart`

```dart
FileCloudWidget(
  providers: [
    ProviderConfiguration(
      type: CloudProviderType.googleDrive,
      displayName: 'Google Drive',
      generateAuthUrl: (state) => 'http://server/auth/google?state=$state',
      generateTokenUrl: (state) => 'http://server/auth/tokens/$state',
      redirectScheme: 'myapp://oauth',
      requiredScopes: {OAuthScope.readFiles, OAuthScope.writeFiles},
      capabilities: ProviderCapabilities(...),
    ),
    ProviderConfiguration(
      type: CloudProviderType.custom,
      displayName: 'Minha Galeria',
      logoWidget: Icon(Icons.photo_library),
      // ...
    ),
  ],
  accountStorage: SharedPreferencesAccountStorage(),
  selectionConfig: SelectionConfig(
    minSelection: 1,
    maxSelection: 5,
    allowedMimeTypes: ['image/*', 'application/pdf'],
    onSelectionConfirm: (files) => print('Selected: $files'),
  ),
)
```

---

## 📊 MÉTRICAS DE SUCESSO

### Critérios de Aceitação:
- ✅ Widget 100% configurável via parâmetros
- ✅ Suporte a múltiplos provedores simultâneos
- ✅ Nenhum client_secret no código do app
- ✅ Todas funcionalidades do RULES.md implementadas
- ✅ UI adaptativa baseada em capabilities
- ✅ Traduções centralizadas com Intl
- ✅ Exemplo funcional com múltiplos provedores

### Testes Necessários:
1. Adicionar múltiplas contas de diferentes provedores
2. Navegar, criar pastas, fazer upload/download
3. Busca com debounce funcionando
4. Modo seleção com filtros de mime-type
5. Infinite scroll carregando páginas corretamente
6. UI se adaptando às capabilities

---

## 🚀 ORDEM DE EXECUÇÃO

1. **Semana 1:** Fase 1 (Arquitetura Base)
   - Criar ProviderConfiguration
   - Refatorar BaseCloudProvider
   - Atualizar FileCloudWidget

2. **Semana 2:** Fase 2 (Funcionalidades)
   - Implementar busca com debounce
   - Configurar infinite scroll
   - Melhorar SelectionConfig

3. **Semana 3:** Fase 3 e 4 (Refinamento)
   - Aplicar capabilities na UI
   - Centralizar traduções
   - Limpeza de código
   - Atualizar exemplos

---

## ⚠️ RISCOS E MITIGAÇÕES

### Risco 1: Breaking Changes
**Mitigação:** Criar branch separado, testar extensivamente antes de merge

### Risco 2: Compatibilidade com código existente
**Mitigação:** Manter temporariamente adaptadores para API antiga

### Risco 3: Complexidade da migração
**Mitigação:** Fazer mudanças incrementais, uma fase por vez

---

## 📝 NOTAS ADICIONAIS

- Priorizar qualidade sobre velocidade
- Cada fase deve ser testada antes de prosseguir
- Documentar todas mudanças de API
- Manter CHANGELOG atualizado
- Considerar versionamento semântico para release

---

**Status:** PLANEJADO
**Última atualização:** 2025-08-20
**Responsável:** Claude (Opus 4)