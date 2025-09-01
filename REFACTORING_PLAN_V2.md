# 📋 PLANO DE REFATORAÇÃO V2 - FILE_DRIVE

## 📅 Data: 2025-09-01
## 🎯 Objetivo: Adequar o projeto às especificações RULES.md com arquitetura flexível e compatível com Flutter Web

---

## 🏗️ NOVA ARQUITETURA DE CONFIGURAÇÃO

### **Hierarquia de Classes de Configuração**

```dart
// 1. Configuração base para todos os provedores
abstract class BaseProviderConfiguration {
  final CloudProviderType type;
  final String displayName;
  final Widget? logoWidget;
  final String? logoAssetPath;
  final ProviderCapabilities capabilities;
  final bool requiresAccountManagement;
  
  const BaseProviderConfiguration({
    required this.type,
    required this.displayName,
    this.logoWidget,
    this.logoAssetPath,
    required this.capabilities,
    required this.requiresAccountManagement,
  });
}

// 2. Configuração para provedores locais (sem auth)
class LocalProviderConfiguration extends BaseProviderConfiguration {
  final String serverBaseUrl;
  final Map<String, String> customHeaders;
  
  const LocalProviderConfiguration({
    required super.type,
    required super.displayName,
    super.logoWidget,
    super.logoAssetPath,
    required super.capabilities,
    super.requiresAccountManagement = false,
    required this.serverBaseUrl,
    this.customHeaders = const {},
  });
}

// 3. Configuração para provedores OAuth
class OAuthProviderConfiguration extends BaseProviderConfiguration {
  final String Function(String state) generateAuthUrl;
  final String Function(String state) generateTokenUrl;
  final String redirectScheme;
  final Set<OAuthScope> requiredScopes;
  
  const OAuthProviderConfiguration({
    required super.type,
    required super.displayName,
    super.logoWidget,
    super.logoAssetPath,
    required super.capabilities,
    super.requiresAccountManagement = true,
    required this.generateAuthUrl,
    required this.generateTokenUrl,
    required this.redirectScheme,
    required this.requiredScopes,
  });
}
```

### **Sistema de Factory Compatível com Flutter Web**

```dart
// Registry pattern para evitar Function() references
class CloudProviderFactory {
  static final Map<CloudProviderType, Type> _providerClasses = {
    CloudProviderType.googleDrive: GoogleDriveCloudProvider,
    CloudProviderType.oneDrive: OneDriveCloudProvider,
    CloudProviderType.dropbox: DropboxCloudProvider,
    CloudProviderType.localServer: LocalServerCloudProvider,
    CloudProviderType.custom: CustomCloudProvider,
  };
  
  static BaseCloudProvider create(CloudProviderType type) {
    final providerClass = _providerClasses[type];
    if (providerClass == null) {
      throw UnsupportedError('Provider type $type not registered');
    }
    
    // Flutter Web safe instantiation
    switch (type) {
      case CloudProviderType.googleDrive:
        return GoogleDriveCloudProvider();
      case CloudProviderType.oneDrive:
        return OneDriveCloudProvider();
      case CloudProviderType.dropbox:
        return DropboxCloudProvider();
      case CloudProviderType.localServer:
        return LocalServerCloudProvider();
      case CloudProviderType.custom:
        return CustomCloudProvider();
      default:
        throw UnsupportedError('Provider type $type not supported');
    }
  }
  
  static void registerProvider(CloudProviderType type, Type providerClass) {
    _providerClasses[type] = providerClass;
  }
}
```

---

## 🚀 FASES DE IMPLEMENTAÇÃO DETALHADAS

### **FASE 1: REESTRUTURAÇÃO ARQUITETURAL CRÍTICA**
*Prioridade: CRÍTICA | Estimativa: 3-4 dias*

#### 1.1 Criar Sistema de Configuração Hierárquico

**Arquivo:** `lib/src/models/configurations/`

```
├── base_provider_configuration.dart     (classe abstrata base)
├── local_provider_configuration.dart    (sem auth)
├── oauth_provider_configuration.dart    (com auth)
└── provider_factory.dart               (factory flutter-web-safe)
```

**Implementação específica:**

**base_provider_configuration.dart:**
```dart
import 'package:flutter/widgets.dart';
import '../enums/cloud_provider_type.dart';
import '../capabilities/provider_capabilities.dart';

abstract class BaseProviderConfiguration {
  final CloudProviderType type;
  final String displayName;
  final Widget? logoWidget;
  final String? logoAssetPath;
  final ProviderCapabilities capabilities;
  final bool requiresAccountManagement;
  
  const BaseProviderConfiguration({
    required this.type,
    required this.displayName,
    this.logoWidget,
    this.logoAssetPath,
    required this.capabilities,
    required this.requiresAccountManagement,
  });
  
  // Template method para validação
  bool validate() {
    return displayName.isNotEmpty && 
           (logoWidget != null || logoAssetPath != null);
  }
}
```

**local_provider_configuration.dart:**
```dart
import 'base_provider_configuration.dart';
import '../enums/cloud_provider_type.dart';
import '../capabilities/provider_capabilities.dart';

class LocalProviderConfiguration extends BaseProviderConfiguration {
  final String serverBaseUrl;
  final Map<String, String> customHeaders;
  final Duration timeout;
  final bool useHttps;
  
  const LocalProviderConfiguration({
    required super.type,
    required super.displayName,
    super.logoWidget,
    super.logoAssetPath,
    required super.capabilities,
    super.requiresAccountManagement = false,
    required this.serverBaseUrl,
    this.customHeaders = const {},
    this.timeout = const Duration(seconds: 30),
    this.useHttps = true,
  });
  
  @override
  bool validate() {
    return super.validate() && 
           serverBaseUrl.isNotEmpty && 
           Uri.tryParse(serverBaseUrl) != null;
  }
}
```

**oauth_provider_configuration.dart:**
```dart
import 'base_provider_configuration.dart';
import '../enums/cloud_provider_type.dart';
import '../enums/oauth_scope.dart';
import '../capabilities/provider_capabilities.dart';

class OAuthProviderConfiguration extends BaseProviderConfiguration {
  final String Function(String state) generateAuthUrl;
  final String Function(String state) generateTokenUrl;
  final String redirectScheme;
  final Set<OAuthScope> requiredScopes;
  final Map<String, String> extraParams;
  
  const OAuthProviderConfiguration({
    required super.type,
    required super.displayName,
    super.logoWidget,
    super.logoAssetPath,
    required super.capabilities,
    super.requiresAccountManagement = true,
    required this.generateAuthUrl,
    required this.generateTokenUrl,
    required this.redirectScheme,
    required this.requiredScopes,
    this.extraParams = const {},
  });
  
  @override
  bool validate() {
    return super.validate() && 
           redirectScheme.isNotEmpty && 
           requiredScopes.isNotEmpty;
  }
}
```

**provider_factory.dart:**
```dart
import '../providers/base_cloud_provider.dart';
import '../enums/cloud_provider_type.dart';
import '../providers/google_drive_cloud_provider.dart';
import '../providers/onedrive_cloud_provider.dart';
import '../providers/dropbox_cloud_provider.dart';
import '../providers/local_server_cloud_provider.dart';
import '../providers/custom_cloud_provider.dart';

class CloudProviderFactory {
  // Registry estático para compatibilidade Flutter Web
  static final Map<CloudProviderType, BaseCloudProvider Function()> _builders = {
    CloudProviderType.googleDrive: () => GoogleDriveCloudProvider(),
    CloudProviderType.oneDrive: () => OneDriveCloudProvider(),
    CloudProviderType.dropbox: () => DropboxCloudProvider(),
    CloudProviderType.localServer: () => LocalServerCloudProvider(),
    CloudProviderType.custom: () => CustomCloudProvider(),
  };
  
  static BaseCloudProvider createProvider(CloudProviderType type) {
    final builder = _builders[type];
    if (builder == null) {
      throw UnsupportedError('Provider type $type não está registrado');
    }
    return builder();
  }
  
  static void registerCustomProvider(
    CloudProviderType type, 
    BaseCloudProvider Function() builder
  ) {
    _builders[type] = builder;
  }
  
  static bool isProviderSupported(CloudProviderType type) {
    return _builders.containsKey(type);
  }
  
  static List<CloudProviderType> getSupportedTypes() {
    return _builders.keys.toList();
  }
}
```

#### 1.2 Refatorar BaseCloudProvider Completamente

**Arquivo:** `lib/src/providers/base_cloud_provider.dart`

```dart
import '../models/configurations/base_provider_configuration.dart';
import '../models/cloud_account.dart';
import '../models/file_entry.dart';
import '../models/file_list_page.dart';
import '../models/user_profile.dart';
import '../models/upload_progress.dart';
import '../capabilities/provider_capabilities.dart';

abstract class BaseCloudProvider {
  BaseProviderConfiguration? _configuration;
  CloudAccount? _currentAccount;
  
  // Getters para configuração
  BaseProviderConfiguration get configuration {
    if (_configuration == null) {
      throw StateError('Provider não foi inicializado. Chame initialize() primeiro.');
    }
    return _configuration!;
  }
  
  CloudAccount? get currentAccount => _currentAccount;
  bool get isAuthenticated => _currentAccount != null;
  
  // Método de inicialização obrigatório
  void initialize({
    required BaseProviderConfiguration configuration,
    CloudAccount? account,
  }) {
    if (!configuration.validate()) {
      throw ArgumentError('Configuração inválida para provider ${configuration.type}');
    }
    _configuration = configuration;
    _currentAccount = account;
    onInitialized();
  }
  
  // Hook para providers customizarem inicialização
  @protected
  void onInitialized() {}
  
  // TODOS os métodos abstratos obrigatórios (RULES.md)
  Future<FileListPage> listFolder({
    String? parentId,
    int limit = 50,
    String? pageToken,
  });
  
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  });
  
  Future<void> deleteEntry(String entryId);
  
  Stream<List<int>> downloadFile(String fileId);
  
  Stream<UploadProgress> uploadFile({
    required String name,
    required Stream<List<int>> fileStream,
    required int fileSize,
    String? parentId,
    String? mimeType,
  });
  
  Future<FileListPage> searchByName({
    required String query,
    String? parentId,
    int limit = 50,
    String? pageToken,
  });
  
  // Métodos movidos de AccountBasedProvider para base
  Future<UserProfile> getUserProfile();
  Future<CloudAccount> refreshAuth(CloudAccount account);
  ProviderCapabilities getCapabilities();
  
  // Método template para determinar se provider suporta auth
  bool get supportsAuthentication => _configuration?.requiresAccountManagement ?? false;
  
  // Validações
  void _validateInitialized() {
    if (_configuration == null) {
      throw StateError('Provider não inicializado');
    }
  }
  
  void _validateAuthenticated() {
    _validateInitialized();
    if (supportsAuthentication && !isAuthenticated) {
      throw StateError('Provider requer autenticação mas não está autenticado');
    }
  }
}
```

#### 1.3 Atualizar FileCloudWidget

**Arquivo:** `lib/src/widgets/file_cloud_widget.dart`

```dart
class FileCloudWidget extends StatefulWidget {
  // ❌ REMOVER
  // final OAuthConfig oauthConfig;
  
  // ✅ NOVA API
  final List<BaseProviderConfiguration> providers;
  final AccountStorage accountStorage;
  final SelectionConfig? selectionConfig;
  
  // Callback obrigatório quando em modo seleção
  final Function(List<FileEntry>)? onSelectionConfirm;
  
  // Configurações opcionais
  final bool showProviderSwitcher;
  final bool enableGlobalSearch;
  final String? initialFolderId;
  
  const FileCloudWidget({
    Key? key,
    required this.providers,
    required this.accountStorage,
    this.selectionConfig,
    this.onSelectionConfirm,
    this.showProviderSwitcher = true,
    this.enableGlobalSearch = true,
    this.initialFolderId,
  }) : assert(
         (selectionConfig == null) || (onSelectionConfirm != null),
         'onSelectionConfirm é obrigatório quando selectionConfig é fornecido'
       ),
       super(key: key);
}

class _FileCloudWidgetState extends State<FileCloudWidget> {
  final Map<CloudProviderType, BaseCloudProvider> _providers = {};
  CloudProviderType? _selectedProviderType;
  
  @override
  void initState() {
    super.initState();
    _initializeProvidersFromConfiguration();
    _loadAccountsForProviders();
  }
  
  void _initializeProvidersFromConfiguration() {
    for (final config in widget.providers) {
      try {
        // Factory pattern compatível com Flutter Web
        final provider = CloudProviderFactory.createProvider(config.type);
        provider.initialize(configuration: config);
        _providers[config.type] = provider;
      } catch (e) {
        debugPrint('Erro ao inicializar provider ${config.type}: $e');
        // Continua com outros providers
      }
    }
    
    // Seleciona primeiro provider disponível
    if (_providers.isNotEmpty) {
      _selectedProviderType = _providers.keys.first;
    }
  }
  
  Future<void> _loadAccountsForProviders() async {
    for (final entry in _providers.entries) {
      final provider = entry.value;
      if (provider.configuration.requiresAccountManagement) {
        final account = await widget.accountStorage.getAccount(entry.key);
        if (account != null) {
          provider._currentAccount = account;
        }
      }
    }
    if (mounted) setState(() {});
  }
}
```

---

## 🔄 IMPLEMENTAÇÃO DE PROVEDORES ESPECÍFICOS

### **Local Server Provider (Sem Auth)**

**Arquivo:** `lib/src/providers/local_server_cloud_provider.dart`

```dart
class LocalServerCloudProvider extends BaseCloudProvider {
  late http.Client _httpClient;
  
  @override
  void onInitialized() {
    super.onInitialized();
    _httpClient = http.Client();
  }
  
  LocalProviderConfiguration get localConfig => 
    configuration as LocalProviderConfiguration;
  
  @override
  bool get supportsAuthentication => false;
  
  @override
  Future<FileListPage> listFolder({
    String? parentId,
    int limit = 50,
    String? pageToken,
  }) async {
    _validateInitialized();
    
    final url = Uri.parse('${localConfig.serverBaseUrl}/api/files');
    final response = await _httpClient.get(
      url.replace(queryParameters: {
        if (parentId != null) 'parent_id': parentId,
        'limit': limit.toString(),
        if (pageToken != null) 'page_token': pageToken,
      }),
      headers: {
        'Content-Type': 'application/json',
        ...localConfig.customHeaders,
      },
    );
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Erro ao listar arquivos: ${response.statusCode}');
    }
    
    return FileListPage.fromJson(jsonDecode(response.body));
  }
  
  @override
  Future<UserProfile> getUserProfile() async {
    // Local provider não tem perfil de usuário
    return UserProfile(
      id: 'local-user',
      name: 'Local Server User',
      email: null,
    );
  }
  
  @override
  Future<CloudAccount> refreshAuth(CloudAccount account) async {
    // Local provider não precisa refresh de auth
    return account;
  }
  
  // ... resto dos métodos implementados
}
```

### **OAuth Provider Base**

**Arquivo:** `lib/src/providers/oauth_cloud_provider.dart`

```dart
abstract class OAuthCloudProvider extends BaseCloudProvider {
  OAuthProviderConfiguration get oauthConfig => 
    configuration as OAuthProviderConfiguration;
  
  @override
  bool get supportsAuthentication => true;
  
  // Métodos OAuth comuns
  Future<String> startOAuthFlow() async {
    _validateInitialized();
    
    final state = _generateState();
    final authUrl = oauthConfig.generateAuthUrl(state);
    
    // Aqui implementaria launch_url para abrir browser
    await _launchAuthUrl(authUrl);
    return state;
  }
  
  Future<CloudAccount> exchangeCodeForToken({
    required String code,
    required String state,
  }) async {
    final tokenUrl = oauthConfig.generateTokenUrl(state);
    
    // Implementação específica para trocar code por token
    final response = await _httpClient.post(
      Uri.parse(tokenUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'state': state,
      }),
    );
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Erro no OAuth: ${response.statusCode}');
    }
    
    return CloudAccount.fromJson(jsonDecode(response.body));
  }
  
  String _generateState() => 
    DateTime.now().millisecondsSinceEpoch.toString() + 
    (Random().nextInt(10000)).toString();
    
  Future<void> _launchAuthUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw CloudProviderException('Não foi possível abrir URL de autenticação');
    }
  }
}
```

---

### **FASE 2: FUNCIONALIDADES AVANÇADAS**
*Prioridade: ALTA | Estimativa: 2-3 dias*

#### 2.1 Busca Global com Debounce Inteligente

**Arquivo:** `lib/src/widgets/search_bar_widget.dart`

```dart
class SearchBarWidget extends StatefulWidget {
  final Function(String query)? onSearch;
  final Function()? onClear;
  final Duration debounce;
  final String? placeholder;
  final bool isLoading;
  
  const SearchBarWidget({
    Key? key,
    this.onSearch,
    this.onClear,
    this.debounce = const Duration(milliseconds: 400),
    this.placeholder,
    this.isLoading = false,
  }) : super(key: key);
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  String _lastQuery = '';
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }
  
  void _onTextChanged() {
    final query = _controller.text.trim();
    
    // Cancela timer anterior
    _debounceTimer?.cancel();
    
    // Se query está vazia, executa imediatamente
    if (query.isEmpty) {
      _executeSearch('');
      return;
    }
    
    // Se query muito curta, não busca
    if (query.length < 2) return;
    
    // Se query igual à anterior, não busca
    if (query == _lastQuery) return;
    
    // Agenda nova busca com debounce
    _debounceTimer = Timer(widget.debounce, () {
      _executeSearch(query);
    });
  }
  
  void _executeSearch(String query) {
    _lastQuery = query;
    widget.onSearch?.call(query);
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.placeholder ?? 'Buscar arquivos...',
          prefixIcon: widget.isLoading 
            ? SizedBox(
                width: 20, 
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)
              )
            : Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: _clearSearch,
              )
            : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
  
  void _clearSearch() {
    _controller.clear();
    _executeSearch('');
    widget.onClear?.call();
  }
}
```

#### 2.2 Infinite Scroll Robusto com Cache

**Arquivo:** `lib/src/widgets/infinite_scroll_file_list.dart`

```dart
class InfiniteScrollFileList extends StatefulWidget {
  final BaseCloudProvider provider;
  final String? currentFolderId;
  final String? searchQuery;
  final SelectionConfig? selectionConfig;
  final Function(List<FileEntry>) onSelectionChanged;
  
  const InfiniteScrollFileList({
    Key? key,
    required this.provider,
    this.currentFolderId,
    this.searchQuery,
    this.selectionConfig,
    required this.onSelectionChanged,
  }) : super(key: key);
}

class _InfiniteScrollFileListState extends State<InfiniteScrollFileList> {
  final ScrollController _scrollController = ScrollController();
  final List<FileEntry> _files = [];
  final Set<String> _selectedFileIds = {};
  
  bool _isLoading = false;
  bool _hasMore = true;
  String? _nextPageToken;
  String? _lastQuery;
  String? _lastFolderId;
  
  static const int _pageSize = 50;
  static const double _scrollThreshold = 0.8; // 80% da tela
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }
  
  @override
  void didUpdateWidget(InfiniteScrollFileList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reset se mudou query ou folder
    if (widget.searchQuery != _lastQuery || 
        widget.currentFolderId != _lastFolderId) {
      _resetAndReload();
    }
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * _scrollThreshold) {
      _loadMoreFiles();
    }
  }
  
  Future<void> _loadInitialData() async {
    _lastQuery = widget.searchQuery;
    _lastFolderId = widget.currentFolderId;
    
    await _loadFiles(reset: true);
  }
  
  Future<void> _resetAndReload() async {
    setState(() {
      _files.clear();
      _selectedFileIds.clear();
      _hasMore = true;
      _nextPageToken = null;
    });
    
    await _loadInitialData();
  }
  
  Future<void> _loadMoreFiles() async {
    if (_isLoading || !_hasMore) return;
    
    await _loadFiles(reset: false);
  }
  
  Future<void> _loadFiles({required bool reset}) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      FileListPage page;
      
      if (widget.searchQuery?.isNotEmpty == true) {
        // Modo busca
        page = await widget.provider.searchByName(
          query: widget.searchQuery!,
          parentId: widget.currentFolderId,
          limit: _pageSize,
          pageToken: reset ? null : _nextPageToken,
        );
      } else {
        // Modo navegação
        page = await widget.provider.listFolder(
          parentId: widget.currentFolderId,
          limit: _pageSize,
          pageToken: reset ? null : _nextPageToken,
        );
      }
      
      setState(() {
        if (reset) {
          _files.clear();
        }
        _files.addAll(page.files);
        _hasMore = page.hasMore;
        _nextPageToken = page.nextPageToken;
      });
      
    } catch (e) {
      debugPrint('Erro ao carregar arquivos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar arquivos: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _loadFiles(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _files.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _files.length) {
            return _buildLoadingIndicator();
          }
          
          final file = _files[index];
          return _buildFileItem(file);
        },
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      alignment: Alignment.center,
      child: CircularProgressIndicator(),
    );
  }
  
  Widget _buildFileItem(FileEntry file) {
    final isSelected = _selectedFileIds.contains(file.id);
    
    return ListTile(
      leading: _buildFileIcon(file),
      title: Text(file.name),
      subtitle: _buildFileSubtitle(file),
      trailing: widget.selectionConfig != null 
        ? Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleSelection(file),
          ) 
        : null,
      onTap: () => _handleFileTap(file),
    );
  }
  
  void _toggleSelection(FileEntry file) {
    final config = widget.selectionConfig;
    if (config == null) return;
    
    // Validar mime-type se especificado
    if (config.allowedMimeTypes.isNotEmpty && !_isFileTypeAllowed(file)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(config.mimeTypeHint ?? 'Tipo de arquivo não permitido')),
      );
      return;
    }
    
    setState(() {
      if (_selectedFileIds.contains(file.id)) {
        _selectedFileIds.remove(file.id);
      } else {
        // Verificar limites de seleção
        if (_selectedFileIds.length >= config.maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Máximo de ${config.maxSelection} arquivos')),
          );
          return;
        }
        
        _selectedFileIds.add(file.id);
      }
    });
    
    // Notificar mudança na seleção
    final selectedFiles = _files.where((f) => _selectedFileIds.contains(f.id)).toList();
    widget.onSelectionChanged(selectedFiles);
  }
  
  bool _isFileTypeAllowed(FileEntry file) {
    final allowedTypes = widget.selectionConfig!.allowedMimeTypes;
    if (allowedTypes.isEmpty) return true;
    
    for (final allowedType in allowedTypes) {
      if (allowedType.contains('*')) {
        // Suporte para wildcards como 'image/*'
        final pattern = allowedType.replaceAll('*', '.*');
        if (RegExp(pattern).hasMatch(file.mimeType ?? '')) {
          return true;
        }
      } else {
        // Match exato
        if (file.mimeType == allowedType) {
          return true;
        }
      }
    }
    return false;
  }
}
```

---

### **FASE 3: MELHORIAS DE SELECTIONCONFIG**
*Prioridade: ALTA | Estimativa: 1 dia*

#### 3.1 SelectionConfig Aprimorado

**Arquivo:** `lib/src/models/selection_config.dart`

```dart
class SelectionConfig {
  final int minSelection;
  final int maxSelection;
  final bool allowFolders;
  final List<String> allowedMimeTypes;
  final String? mimeTypeHint;
  final bool showFileTypeFilter;
  final Function(List<FileEntry>) onSelectionConfirm;
  
  const SelectionConfig({
    this.minSelection = 1,
    this.maxSelection = 1,
    this.allowFolders = false,
    this.allowedMimeTypes = const [],
    this.mimeTypeHint,
    this.showFileTypeFilter = true,
    required this.onSelectionConfirm,
  }) : assert(minSelection >= 0),
       assert(maxSelection >= minSelection),
       assert(maxSelection > 0);
  
  bool isFileAllowed(FileEntry file) {
    // Verifica se pastas são permitidas
    if (file.isFolder && !allowFolders) return false;
    
    // Se não há filtros de tipo, permite tudo
    if (allowedMimeTypes.isEmpty) return true;
    
    // Verifica mime-type
    for (final allowedType in allowedMimeTypes) {
      if (_matchesMimeType(file.mimeType ?? '', allowedType)) {
        return true;
      }
    }
    
    return false;
  }
  
  bool _matchesMimeType(String fileMimeType, String allowedPattern) {
    if (allowedPattern.contains('*')) {
      final regex = RegExp(allowedPattern.replaceAll('*', '.*'));
      return regex.hasMatch(fileMimeType);
    }
    return fileMimeType == allowedPattern;
  }
  
  List<String> get mimeTypeCategories {
    // Retorna categorias amigáveis para exibir na UI
    return allowedMimeTypes.map((type) {
      if (type.startsWith('image/')) return 'Imagens';
      if (type.startsWith('video/')) return 'Vídeos';
      if (type.startsWith('audio/')) return 'Áudios';
      if (type == 'application/pdf') return 'PDFs';
      if (type.startsWith('text/')) return 'Textos';
      return type;
    }).toSet().toList();
  }
}
```

#### 3.2 Widget de Filtros de Tipo

**Arquivo:** `lib/src/widgets/file_type_filter_widget.dart`

```dart
class FileTypeFilterWidget extends StatelessWidget {
  final SelectionConfig selectionConfig;
  
  const FileTypeFilterWidget({
    Key? key,
    required this.selectionConfig,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (!selectionConfig.showFileTypeFilter || 
        selectionConfig.allowedMimeTypes.isEmpty) {
      return SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: selectionConfig.mimeTypeCategories.map((category) {
          return Chip(
            label: Text(category),
            avatar: _getCategoryIcon(category),
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          );
        }).toList(),
      ),
    );
  }
  
  Icon _getCategoryIcon(String category) {
    switch (category) {
      case 'Imagens':
        return Icon(Icons.image, size: 16);
      case 'Vídeos':
        return Icon(Icons.videocam, size: 16);
      case 'Áudios':
        return Icon(Icons.audiotrack, size: 16);
      case 'PDFs':
        return Icon(Icons.picture_as_pdf, size: 16);
      case 'Textos':
        return Icon(Icons.text_snippet, size: 16);
      default:
        return Icon(Icons.insert_drive_file, size: 16);
    }
  }
}
```

---

### **FASE 4: CAPABILITIES E UI ADAPTATIVA**
*Prioridade: MÉDIA | Estimativa: 1-2 dias*

#### 4.1 Capabilities Aprimorado

**Arquivo:** `lib/src/capabilities/provider_capabilities.dart`

```dart
class ProviderCapabilities {
  final bool canUpload;
  final bool canDownload;
  final bool canCreateFolders;
  final bool canDeleteFiles;
  final bool canDeleteFolders;
  final bool canSearch;
  final bool canRename;
  final bool canMove;
  final bool canShare;
  final bool supportsVersioning;
  final bool supportsThumbnails;
  final Set<String> supportedMimeTypes;
  final int maxFileSize; // em bytes, -1 para ilimitado
  final int maxFilesPerUpload;
  
  const ProviderCapabilities({
    this.canUpload = true,
    this.canDownload = true,
    this.canCreateFolders = true,
    this.canDeleteFiles = true,
    this.canDeleteFolders = false,
    this.canSearch = true,
    this.canRename = false,
    this.canMove = false,
    this.canShare = false,
    this.supportsVersioning = false,
    this.supportsThumbnails = false,
    this.supportedMimeTypes = const {},
    this.maxFileSize = -1,
    this.maxFilesPerUpload = 10,
  });
  
  bool canUploadFile(String? mimeType, int fileSize) {
    if (!canUpload) return false;
    if (maxFileSize > 0 && fileSize > maxFileSize) return false;
    if (supportedMimeTypes.isNotEmpty && mimeType != null) {
      return supportedMimeTypes.any((type) => 
        _matchesMimeType(mimeType, type));
    }
    return true;
  }
  
  bool _matchesMimeType(String fileMimeType, String supportedPattern) {
    if (supportedPattern.contains('*')) {
      final regex = RegExp(supportedPattern.replaceAll('*', '.*'));
      return regex.hasMatch(fileMimeType);
    }
    return fileMimeType == supportedPattern;
  }
}
```

#### 4.2 UI Adaptativa Baseada em Capabilities

**Arquivo:** `lib/src/widgets/adaptive_navigation_bar.dart`

```dart
class AdaptiveNavigationBar extends StatelessWidget {
  final BaseCloudProvider provider;
  final Function()? onUpload;
  final Function()? onCreateFolder;
  final Function()? onRefresh;
  final bool showSearch;
  
  const AdaptiveNavigationBar({
    Key? key,
    required this.provider,
    this.onUpload,
    this.onCreateFolder,
    this.onRefresh,
    this.showSearch = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final capabilities = provider.getCapabilities();
    
    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          // Busca (se suportada e habilitada)
          if (capabilities.canSearch && showSearch) ...[
            Expanded(
              child: SearchBarWidget(
                onSearch: (query) => _handleSearch(context, query),
                placeholder: 'Buscar em ${provider.configuration.displayName}',
              ),
            ),
            SizedBox(width: 8),
          ],
          
          // Botões de ação adaptativos
          ...._buildActionButtons(context, capabilities),
        ],
      ),
    );
  }
  
  List<Widget> _buildActionButtons(BuildContext context, ProviderCapabilities capabilities) {
    final buttons = <Widget>[];
    
    // Upload
    if (capabilities.canUpload && onUpload != null) {
      buttons.add(
        IconButton(
          icon: Icon(Icons.upload),
          tooltip: 'Upload arquivos',
          onPressed: onUpload,
        ),
      );
    }
    
    // Criar pasta
    if (capabilities.canCreateFolders && onCreateFolder != null) {
      buttons.add(
        IconButton(
          icon: Icon(Icons.create_new_folder),
          tooltip: 'Nova pasta',
          onPressed: onCreateFolder,
        ),
      );
    }
    
    // Refresh
    if (onRefresh != null) {
      buttons.add(
        IconButton(
          icon: Icon(Icons.refresh),
          tooltip: 'Atualizar',
          onPressed: onRefresh,
        ),
      );
    }
    
    return buttons;
  }
  
  void _handleSearch(BuildContext context, String query) {
    // Implementar busca
    final widget = context.findAncestorStateOfType<_FileCloudWidgetState>();
    widget?._handleGlobalSearch(query);
  }
}
```

---

### **FASE 5: INTERNACIONALIZAÇÃO E POLIMENTO**
*Prioridade: BAIXA | Estimativa: 1 dia*

#### 5.1 Sistema de Traduções Centralizado

**Arquivo:** `lib/src/l10n/file_cloud_messages.dart`

```dart
import 'package:intl/intl.dart';

class FileCloudMessages {
  // Navegação
  static String get rootFolder => Intl.message(
    'Pasta raiz',
    name: 'rootFolder',
    desc: 'Nome para a pasta raiz',
  );
  
  static String get noFilesFound => Intl.message(
    'Nenhum arquivo encontrado',
    name: 'noFilesFound',
    desc: 'Mensagem quando não há arquivos na pasta',
  );
  
  static String get searchPlaceholder => Intl.message(
    'Buscar arquivos...',
    name: 'searchPlaceholder',
    desc: 'Placeholder do campo de busca',
  );
  
  // Seleção
  static String selectionLimit(int max) => Intl.message(
    'Máximo de $max arquivos permitidos',
    name: 'selectionLimit',
    args: [max],
    desc: 'Mensagem de limite de seleção',
  );
  
  static String fileTypeNotAllowed(String hint) => Intl.message(
    'Tipo de arquivo não permitido. $hint',
    name: 'fileTypeNotAllowed',
    args: [hint],
    desc: 'Mensagem para tipo de arquivo não permitido',
  );
  
  // Upload/Download
  static String get uploadFiles => Intl.message(
    'Upload de arquivos',
    name: 'uploadFiles',
    desc: 'Texto do botão de upload',
  );
  
  static String get downloading => Intl.message(
    'Baixando...',
    name: 'downloading',
    desc: 'Status de download',
  );
  
  static String uploadProgress(int current, int total) => Intl.message(
    'Enviando $current de $total arquivos',
    name: 'uploadProgress',
    args: [current, total],
    desc: 'Progresso de upload',
  );
  
  // Erros
  static String get connectionError => Intl.message(
    'Erro de conexão. Verifique sua internet.',
    name: 'connectionError',
    desc: 'Erro de conexão',
  );
  
  static String authenticationRequired(String providerName) => Intl.message(
    'Autenticação necessária para $providerName',
    name: 'authenticationRequired',
    args: [providerName],
    desc: 'Mensagem de autenticação necessária',
  );
  
  static String providerError(String providerName, String error) => Intl.message(
    'Erro em $providerName: $error',
    name: 'providerError',
    args: [providerName, error],
    desc: 'Mensagem de erro do provider',
  );
}
```

#### 5.2 Gerar Arquivos de Tradução

**Comandos para executar:**
```bash
# Gerar arquivo .arb
flutter gen-l10n --arb-dir=lib/src/l10n/arb

# Estrutura esperada:
lib/src/l10n/
├── arb/
│   ├── app_pt.arb    # Português (padrão)
│   ├── app_en.arb    # Inglês
│   └── app_es.arb    # Espanhol
├── file_cloud_messages.dart
└── generated/        # Arquivos gerados automaticamente
```

---

## 📋 EXEMPLO DE USO FINAL

### **Configuração de Múltiplos Provedores**

```dart
FileCloudWidget(
  providers: [
    // Servidor local (sem auth)
    LocalProviderConfiguration(
      type: CloudProviderType.localServer,
      displayName: 'Meu Servidor',
      logoWidget: Icon(Icons.storage, color: Colors.blue),
      serverBaseUrl: 'https://meuservidor.com',
      capabilities: ProviderCapabilities(
        canUpload: true,
        canDownload: true,
        canCreateFolders: true,
        canSearch: true,
        maxFileSize: 100 * 1024 * 1024, // 100MB
        supportedMimeTypes: {'image/*', 'application/pdf'},
      ),
    ),
    
    // Google Drive (com auth)
    OAuthProviderConfiguration(
      type: CloudProviderType.googleDrive,
      displayName: 'Google Drive',
      logoAssetPath: 'assets/logos/google_drive.png',
      generateAuthUrl: (state) => 'https://meuback.com/auth/google?state=$state',
      generateTokenUrl: (state) => 'https://meuback.com/auth/tokens/$state',
      redirectScheme: 'meuapp://oauth',
      requiredScopes: {OAuthScope.readFiles, OAuthScope.writeFiles},
      capabilities: ProviderCapabilities(
        canUpload: true,
        canDownload: true,
        canCreateFolders: true,
        canSearch: true,
        canShare: true,
        supportsThumbnails: true,
        maxFileSize: -1, // Ilimitado
      ),
    ),
  ],
  accountStorage: SharedPreferencesAccountStorage(),
  selectionConfig: SelectionConfig(
    minSelection: 1,
    maxSelection: 3,
    allowFolders: false,
    allowedMimeTypes: ['image/jpeg', 'image/png', 'application/pdf'],
    mimeTypeHint: 'Apenas imagens JPEG/PNG e arquivos PDF são aceitos',
    onSelectionConfirm: (files) {
      print('Arquivos selecionados: ${files.map((f) => f.name).join(', ')}');
    },
  ),
  showProviderSwitcher: true,
  enableGlobalSearch: true,
)
```

---

## 🔍 VALIDAÇÕES E TESTES CRÍTICOS

### **Cenários de Teste Obrigatórios**

#### Teste 1: Múltiplos Provedores
```dart
testWidgets('deve suportar múltiplos provedores simultaneamente', (tester) async {
  final widget = FileCloudWidget(
    providers: [
      LocalProviderConfiguration(/* ... */),
      OAuthProviderConfiguration(/* ... */),
    ],
    // ...
  );
  
  await tester.pumpWidget(makeApp(widget));
  
  // Verificar que ambos provedores estão disponíveis
  expect(find.text('Meu Servidor'), findsOneWidget);
  expect(find.text('Google Drive'), findsOneWidget);
});
```

#### Teste 2: Filtros de Mime-Type
```dart
testWidgets('deve filtrar arquivos por mime-type', (tester) async {
  final selectionConfig = SelectionConfig(
    allowedMimeTypes: ['image/*'],
    onSelectionConfirm: (files) {},
  );
  
  // Simular arquivos de diferentes tipos
  final files = [
    FileEntry(id: '1', name: 'foto.jpg', mimeType: 'image/jpeg'),
    FileEntry(id: '2', name: 'doc.pdf', mimeType: 'application/pdf'),
  ];
  
  // Verificar que apenas imagem é selecionável
  expect(selectionConfig.isFileAllowed(files[0]), true);
  expect(selectionConfig.isFileAllowed(files[1]), false);
});
```

#### Teste 3: Flutter Web Compatibility
```dart
testWidgets('deve funcionar no Flutter Web sem dart:io', (tester) async {
  // Verificar que todos providers podem ser criados
  final factory = CloudProviderFactory();
  
  expect(() => factory.createProvider(CloudProviderType.googleDrive), 
         returnsNormally);
  expect(() => factory.createProvider(CloudProviderType.localServer), 
         returnsNormally);
});
```

---

## 📊 MÉTRICAS DE SUCESSO ATUALIZADAS

### **Checklist de Validação:**

#### Arquitetura:
- ✅ Hierarquia clara: Base → Local/OAuth Configuration
- ✅ Factory pattern compatível com Flutter Web
- ✅ Nenhum `Function()` parameter em configurações
- ✅ Zero client_secret no código do app
- ✅ BaseCloudProvider com todos métodos abstratos

#### Funcionalidades:
- ✅ Busca global com debounce de 400ms
- ✅ Infinite scroll configurado (50 itens/página)
- ✅ SelectionConfig com filtros de mime-types funcionais
- ✅ UI adaptativa baseada em capabilities reais
- ✅ Traduções 100% centralizadas com Intl.message

#### Compatibilidade:
- ✅ Funciona perfeitamente no Flutter Web
- ✅ Suporte a provedores locais SEM auth
- ✅ Suporte a provedores OAuth COM auth
- ✅ Configuração através de parâmetros do widget
- ✅ Múltiplos provedores simultâneos funcionando

### **Cenários de Uso Validados:**
1. **App Local**: Apenas LocalProviderConfiguration com servidor interno
2. **App Cloud**: Apenas OAuthProviderConfiguration para Google Drive
3. **App Híbrido**: Mix de local + múltiplos OAuth providers
4. **Flutter Web**: Todos cenários funcionando sem dart:io
5. **Seleção de Arquivos**: Filtros funcionando perfeitamente

---

## ⚡ BREAKING CHANGES E MIGRAÇÃO

### **Mudanças Incompatíveis:**

#### API Anterior → Nova API:
```dart
// ❌ API ANTIGA (não funciona mais)
FileCloudWidget(
  oauthConfig: OAuthConfig(...),
  accountStorage: storage,
)

// ✅ NOVA API (obrigatória)
FileCloudWidget(
  providers: [
    OAuthProviderConfiguration(...), // ou LocalProviderConfiguration
  ],
  accountStorage: storage,
)
```

### **Guia de Migração:**

1. **Substituir OAuthConfig:**
   - Encontrar todos usos de `OAuthConfig`
   - Converter para `OAuthProviderConfiguration`
   - Adicionar `List<BaseProviderConfiguration>` no widget

2. **Atualizar providers existentes:**
   - Remover herança de `AccountBasedProvider`
   - Implementar `BaseCloudProvider` diretamente
   - Implementar métodos abstratos faltantes

3. **Testar compatibilidade:**
   - Verificar que funciona no Flutter Web
   - Testar com diferentes configurações de provider
   - Validar que seleção funciona corretamente

---

## 🎯 RESULTADOS ESPERADOS

Após a implementação completa:

1. **Flexibilidade Total:**
   - Configuração de qualquer número de provedores
   - Mix de provedores locais e OAuth
   - Customização completa de capabilities

2. **Compatibilidade Garantida:**
   - 100% compatível com Flutter Web
   - Nenhuma dependência de dart:io no core
   - Funciona em todas as plataformas Flutter

3. **Funcionalidades Completas:**
   - Busca avançada com debounce
   - Infinite scroll performático
   - Seleção com filtros inteligentes
   - UI que se adapta automaticamente

4. **Manutenibilidade:**
   - Código limpo e bem estruturado
   - Traduções centralizadas
   - Testes abrangentes
   - Documentação atualizada

---

**Status:** PLANEJADO V2  
**Última atualização:** 2025-09-01  
**Responsável:** Claude (Opus 4.1)
**Revisão:** Arquitetura reformulada considerando Flutter Web e separação auth/local