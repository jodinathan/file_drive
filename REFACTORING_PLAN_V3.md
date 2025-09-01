# 📋 PLANO DE REFATORAÇÃO V3 - FILE_DRIVE

## 📅 Data: 2025-09-01  
## 🎯 Objetivo: Arquitetura senior-level, Flutter Web compatible, com configuração elegante

---

## 🏗️ ARQUITETURA SENIOR DEFINITIVA

### **1. Sistema de Configuração Limpo**

```dart
// Base class - configuração comum
abstract class BaseProviderConfiguration {
  final CloudProviderType type;
  final String displayName;
  final Widget? logoWidget;
  final String? logoAssetPath;
  final ProviderCapabilities capabilities;
  
  const BaseProviderConfiguration({
    required this.type,
    required this.displayName,
    this.logoWidget,
    this.logoAssetPath,
    required this.capabilities,
  });
  
  bool validate() => displayName.isNotEmpty;
}

// OAuth providers - herda base + adiciona auth
class OAuthProviderConfiguration extends BaseProviderConfiguration {
  final Uri Function(String state) generateAuthUrl;
  final Uri Function(String state) generateTokenUrl;
  final String redirectScheme;
  final Set<OAuthScope> requiredScopes;
  
  const OAuthProviderConfiguration({
    required super.type,
    required super.displayName,
    super.logoWidget,
    super.logoAssetPath,
    required super.capabilities,
    required this.generateAuthUrl,
    required this.generateTokenUrl,
    required this.redirectScheme,
    required this.requiredScopes,
  });
  
  @override
  bool validate() => super.validate() && 
                     redirectScheme.isNotEmpty && 
                     requiredScopes.isNotEmpty;
}

// Custom providers - usuário passa provider instance
class CustomProviderConfiguration extends BaseProviderConfiguration {
  final BaseCloudProvider providerInstance;
  
  const CustomProviderConfiguration({
    required super.type,
    required super.displayName,
    super.logoWidget,
    super.logoAssetPath,
    required super.capabilities,
    required this.providerInstance,
  });
  
  @override
  bool validate() => super.validate();
}
```

### **2. Factory Pattern Inteligente**

```dart
class CloudProviderFactory {
  // Registry apenas para providers OAuth built-in
  static final Map<CloudProviderType, BaseCloudProvider Function()> _oauthBuilders = {
    CloudProviderType.googleDrive: () => GoogleDriveCloudProvider(),
    CloudProviderType.oneDrive: () => OneDriveCloudProvider(),
    CloudProviderType.dropbox: () => DropboxCloudProvider(),
  };
  
  static BaseCloudProvider createProvider(BaseProviderConfiguration config) {
    // Custom providers já vêm instanciados
    if (config is CustomProviderConfiguration) {
      return config.providerInstance;
    }
    
    // OAuth providers são criados pelo factory
    if (config is OAuthProviderConfiguration) {
      final builder = _oauthBuilders[config.type];
      if (builder == null) {
        throw UnsupportedError('OAuth provider ${config.type} não suportado');
      }
      return builder();
    }
    
    throw ArgumentError('Tipo de configuração não suportado: ${config.runtimeType}');
  }
  
  static void registerOAuthProvider(
    CloudProviderType type, 
    BaseCloudProvider Function() builder
  ) {
    _oauthBuilders[type] = builder;
  }
  
  static bool isOAuthProviderSupported(CloudProviderType type) => 
    _oauthBuilders.containsKey(type);
}
```

### **3. Hierarquia de Providers Correta**

```dart
// Provider base - todos métodos abstratos
abstract class BaseCloudProvider {
  BaseProviderConfiguration? _configuration;
  CloudAccount? _currentAccount;
  
  BaseProviderConfiguration get configuration {
    if (_configuration == null) {
      throw StateError('Provider não inicializado');
    }
    return _configuration!;
  }
  
  CloudAccount? get currentAccount => _currentAccount;
  
  // Detecção automática de tipo sem campo redundante
  bool get requiresAuthentication => _configuration is OAuthProviderConfiguration;
  bool get isAuthenticated => _currentAccount != null;
  
  void initialize({
    required BaseProviderConfiguration configuration,
    CloudAccount? account,
  }) {
    _configuration = configuration;
    _currentAccount = account;
    onConfigured();
  }
  
  @protected
  void onConfigured() {} // Hook para subclasses
  
  // TODOS métodos abstratos - implementação obrigatória
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
  
  Future<UserProfile> getUserProfile();
  Future<CloudAccount> refreshAuth(CloudAccount account);
  ProviderCapabilities getCapabilities() => configuration.capabilities;
}

// Provider OAuth base - implementação comum de auth
abstract class OAuthCloudProvider extends BaseCloudProvider {
  late http.Client _httpClient;
  
  OAuthProviderConfiguration get oauthConfig => 
    configuration as OAuthProviderConfiguration;
  
  @override
  void onConfigured() {
    super.onConfigured();
    _httpClient = http.Client();
  }
  
  // Implementação comum de OAuth
  Future<String> startOAuthFlow() async {
    final state = _generateSecureState();
    final authUri = oauthConfig.generateAuthUrl(state);
    await _launchAuthUrl(authUri);
    return state;
  }
  
  Future<CloudAccount> exchangeCodeForToken({
    required String code,
    required String state,
  }) async {
    final tokenUri = oauthConfig.generateTokenUrl(state);
    
    final response = await _httpClient.post(
      tokenUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'state': state}),
    );
    
    if (response.statusCode != 200) {
      throw CloudProviderException('OAuth failed: ${response.statusCode}');
    }
    
    final account = CloudAccount.fromJson(jsonDecode(response.body));
    _currentAccount = account;
    return account;
  }
  
  @override
  Future<CloudAccount> refreshAuth(CloudAccount account) async {
    // Implementação comum de refresh usando refresh_token
    final response = await _httpClient.post(
      Uri.parse('${account.tokenEndpoint}/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': account.refreshToken}),
    );
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Token refresh failed');
    }
    
    final newAccount = CloudAccount.fromJson(jsonDecode(response.body));
    _currentAccount = newAccount;
    return newAccount;
  }
  
  String _generateSecureState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
  
  Future<void> _launchAuthUrl(Uri authUri) async {
    if (await canLaunchUrl(authUri)) {
      await launchUrl(authUri, mode: LaunchMode.externalApplication);
    } else {
      throw CloudProviderException('Cannot launch auth URL');
    }
  }
}

// Local Server provider - ABSTRATO para usuário implementar
abstract class LocalServerCloudProvider extends BaseCloudProvider {
  // Base para implementação de servidor local
  // Usuário deve herdar e implementar métodos específicos
  
  @override
  Future<UserProfile> getUserProfile() async {
    // Default implementation para servidores locais
    return UserProfile(
      id: 'local-user',
      name: configuration.displayName,
      email: null,
    );
  }
  
  @override
  Future<CloudAccount> refreshAuth(CloudAccount account) async {
    // Local servers geralmente não precisam refresh
    return account;
  }
}
```

---

## 🔧 IMPLEMENTAÇÕES ESPECÍFICAS

### **Google Drive Provider**

```dart
class GoogleDriveCloudProvider extends OAuthCloudProvider {
  static const String _baseApiUrl = 'https://www.googleapis.com/drive/v3';
  
  @override
  Future<FileListPage> listFolder({
    String? parentId,
    int limit = 50,
    String? pageToken,
  }) async {
    final queryParams = <String, String>{
      'pageSize': limit.toString(),
      'fields': 'nextPageToken, files(id, name, mimeType, size, modifiedTime, parents)',
      'q': parentId != null ? "'$parentId' in parents" : "'root' in parents",
    };
    
    if (pageToken != null) {
      queryParams['pageToken'] = pageToken;
    }
    
    final uri = Uri.parse('$_baseApiUrl/files').replace(queryParameters: queryParams);
    final response = await _httpClient.get(
      uri,
      headers: _getAuthHeaders(),
    );
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Failed to list files: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body);
    return FileListPage(
      files: (data['files'] as List).map((f) => _mapToFileEntry(f)).toList(),
      hasMore: data['nextPageToken'] != null,
      nextPageToken: data['nextPageToken'],
    );
  }
  
  Map<String, String> _getAuthHeaders() => {
    'Authorization': 'Bearer ${currentAccount?.accessToken}',
    'Content-Type': 'application/json',
  };
  
  FileEntry _mapToFileEntry(Map<String, dynamic> driveFile) {
    return FileEntry(
      id: driveFile['id'],
      name: driveFile['name'],
      mimeType: driveFile['mimeType'],
      size: int.tryParse(driveFile['size'] ?? '0') ?? 0,
      isFolder: driveFile['mimeType'] == 'application/vnd.google-apps.folder',
      modifiedTime: DateTime.tryParse(driveFile['modifiedTime'] ?? ''),
      parentId: (driveFile['parents'] as List?)?.first,
    );
  }
  
  // ... resto dos métodos implementados
}
```

### **Example App Implementation**

**Arquivo:** `example/lib/providers/my_local_server_provider.dart`

```dart
class MyLocalServerProvider extends LocalServerCloudProvider {
  late http.Client _httpClient;
  late Uri _baseUri;
  
  @override
  void onConfigured() {
    super.onConfigured();
    _httpClient = http.Client();
    final config = configuration as MyLocalServerConfiguration;
    _baseUri = config.serverBaseUri;
  }
  
  @override
  Future<FileListPage> listFolder({
    String? parentId,
    int limit = 50,
    String? pageToken,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (parentId != null) 'parent_id': parentId,
      if (pageToken != null) 'page_token': pageToken,
    };
    
    final uri = _baseUri.replace(
      path: '${_baseUri.path}/api/files',
      queryParameters: queryParams,
    );
    
    final config = configuration as MyLocalServerConfiguration;
    final response = await _httpClient.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...config.customHeaders,
      },
    );
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Server error: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body);
    return FileListPage(
      files: (data['files'] as List).map((f) => FileEntry.fromJson(f)).toList(),
      hasMore: data['has_more'] ?? false,
      nextPageToken: data['next_page_token'],
    );
  }
  
  @override
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  }) async {
    final uri = _baseUri.replace(path: '${_baseUri.path}/api/folders');
    final config = configuration as MyLocalServerConfiguration;
    
    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...config.customHeaders,
      },
      body: jsonEncode({
        'name': name,
        if (parentId != null) 'parent_id': parentId,
      }),
    );
    
    if (response.statusCode != 201) {
      throw CloudProviderException('Failed to create folder: ${response.statusCode}');
    }
    
    return FileEntry.fromJson(jsonDecode(response.body));
  }
  
  @override
  Stream<List<int>> downloadFile(String fileId) async* {
    final uri = _baseUri.replace(path: '${_baseUri.path}/api/files/$fileId/download');
    final config = configuration as MyLocalServerConfiguration;
    
    final request = http.Request('GET', uri);
    request.headers.addAll({
      'Content-Type': 'application/json',
      ...config.customHeaders,
    });
    
    final response = await _httpClient.send(request);
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Download failed: ${response.statusCode}');
    }
    
    yield* response.stream;
  }
  
  @override
  Stream<UploadProgress> uploadFile({
    required String name,
    required Stream<List<int>> fileStream,
    required int fileSize,
    String? parentId,
    String? mimeType,
  }) async* {
    final uri = _baseUri.replace(path: '${_baseUri.path}/api/files/upload');
    final config = configuration as MyLocalServerConfiguration;
    
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(config.customHeaders);
    
    request.fields['name'] = name;
    if (parentId != null) request.fields['parent_id'] = parentId;
    if (mimeType != null) request.fields['mime_type'] = mimeType;
    
    // Stream file with progress tracking
    final multipartFile = http.MultipartFile(
      'file',
      fileStream,
      fileSize,
      filename: name,
    );
    request.files.add(multipartFile);
    
    final response = await request.send();
    int uploadedBytes = 0;
    
    await for (final chunk in response.stream) {
      uploadedBytes += chunk.length;
      yield UploadProgress(
        uploadedBytes: uploadedBytes,
        totalBytes: fileSize,
        isComplete: uploadedBytes >= fileSize,
      );
    }
    
    if (response.statusCode != 201) {
      throw CloudProviderException('Upload failed: ${response.statusCode}');
    }
  }
  
  @override
  Future<void> deleteEntry(String entryId) async {
    final uri = _baseUri.replace(path: '${_baseUri.path}/api/files/$entryId');
    final config = configuration as MyLocalServerConfiguration;
    
    final response = await _httpClient.delete(
      uri,
      headers: config.customHeaders,
    );
    
    if (response.statusCode != 204) {
      throw CloudProviderException('Delete failed: ${response.statusCode}');
    }
  }
  
  @override
  Future<FileListPage> searchByName({
    required String query,
    String? parentId,
    int limit = 50,
    String? pageToken,
  }) async {
    final queryParams = <String, String>{
      'q': query,
      'limit': limit.toString(),
      if (parentId != null) 'parent_id': parentId,
      if (pageToken != null) 'page_token': pageToken,
    };
    
    final uri = _baseUri.replace(
      path: '${_baseUri.path}/api/search',
      queryParameters: queryParams,
    );
    
    final config = configuration as MyLocalServerConfiguration;
    final response = await _httpClient.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...config.customHeaders,
      },
    );
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Search failed: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body);
    return FileListPage(
      files: (data['files'] as List).map((f) => FileEntry.fromJson(f)).toList(),
      hasMore: data['has_more'] ?? false,
      nextPageToken: data['next_page_token'],
    );
  }
}
```

### **4. Configuração Personalizada para Example**

**Arquivo:** `example/lib/providers/my_local_server_configuration.dart`

```dart
class MyLocalServerConfiguration extends BaseProviderConfiguration {
  final Uri serverBaseUri;
  final Map<String, String> customHeaders;
  final Duration timeout;
  final String? apiKey;
  
  const MyLocalServerConfiguration({
    required super.displayName,
    super.logoWidget,
    super.logoAssetPath,
    required super.capabilities,
    required this.serverBaseUri,
    this.customHeaders = const {},
    this.timeout = const Duration(seconds: 30),
    this.apiKey,
  }) : super(type: CloudProviderType.custom);
  
  @override
  bool validate() => super.validate() && serverBaseUri.isAbsolute;
  
  Map<String, String> get headersWithAuth {
    final headers = Map<String, String>.from(customHeaders);
    if (apiKey != null) {
      headers['X-API-Key'] = apiKey!;
    }
    return headers;
  }
}
```

---

## 🎯 FILECLOUD WIDGET FINAL

### **Widget Principal Refatorado**

```dart
class FileCloudWidget extends StatefulWidget {
  final List<BaseProviderConfiguration> providers;
  final AccountStorage accountStorage;
  final SelectionConfig? selectionConfig;
  final Function(List<FileEntry>)? onSelectionConfirm;
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
         providers.isNotEmpty,
         'Pelo menos um provider deve ser configurado'
       ),
       assert(
         (selectionConfig == null) || (onSelectionConfirm != null),
         'onSelectionConfirm obrigatório quando selectionConfig fornecido'
       ),
       super(key: key);
}

class _FileCloudWidgetState extends State<FileCloudWidget> {
  final Map<CloudProviderType, BaseCloudProvider> _providers = {};
  CloudProviderType? _selectedProviderType;
  
  @override
  void initState() {
    super.initState();
    _initializeProviders();
    _loadStoredAccounts();
  }
  
  void _initializeProviders() {
    for (final config in widget.providers) {
      try {
        final provider = CloudProviderFactory.createProvider(config);
        provider.initialize(configuration: config);
        _providers[config.type] = provider;
      } catch (e) {
        debugPrint('Failed to initialize ${config.type}: $e');
      }
    }
    
    if (_providers.isNotEmpty) {
      _selectedProviderType = _providers.keys.first;
    }
  }
  
  Future<void> _loadStoredAccounts() async {
    for (final entry in _providers.entries) {
      final provider = entry.value;
      
      // Só carregar conta se provider precisa de auth
      if (provider.requiresAuthentication) {
        final account = await widget.accountStorage.getAccount(entry.key);
        if (account != null) {
          provider._currentAccount = account;
        }
      }
    }
    
    if (mounted) setState(() {});
  }
  
  BaseCloudProvider? get _currentProvider => 
    _selectedProviderType != null ? _providers[_selectedProviderType] : null;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Provider switcher (se habilitado e múltiplos providers)
        if (widget.showProviderSwitcher && _providers.length > 1)
          _buildProviderSwitcher(),
        
        // Navigation bar adaptativa
        if (_currentProvider != null)
          AdaptiveNavigationBar(
            provider: _currentProvider!,
            showSearch: widget.enableGlobalSearch,
            onUpload: _handleUpload,
            onCreateFolder: _handleCreateFolder,
            onRefresh: _handleRefresh,
          ),
        
        // File type filter (se em modo seleção)
        if (widget.selectionConfig != null)
          FileTypeFilterWidget(selectionConfig: widget.selectionConfig!),
        
        // Lista de arquivos
        Expanded(
          child: _currentProvider != null
            ? InfiniteScrollFileList(
                provider: _currentProvider!,
                selectionConfig: widget.selectionConfig,
                onSelectionChanged: _handleSelectionChanged,
              )
            : _buildEmptyState(),
        ),
      ],
    );
  }
  
  Widget _buildProviderSwitcher() {
    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _providers.length,
        itemBuilder: (context, index) {
          final type = _providers.keys.elementAt(index);
          final config = widget.providers.firstWhere((c) => c.type == type);
          final isSelected = type == _selectedProviderType;
          
          return GestureDetector(
            onTap: () => _switchProvider(type),
            child: Container(
              margin: EdgeInsets.all(8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (config.logoWidget != null) ...[
                    config.logoWidget!,
                    SizedBox(width: 8),
                  ],
                  Text(
                    config.displayName,
                    style: TextStyle(
                      color: isSelected 
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  void _switchProvider(CloudProviderType type) {
    setState(() {
      _selectedProviderType = type;
    });
  }
  
  void _handleSelectionChanged(List<FileEntry> selectedFiles) {
    // Validar seleção mínima/máxima
    final config = widget.selectionConfig;
    if (config == null) return;
    
    if (selectedFiles.length >= config.minSelection) {
      widget.onSelectionConfirm?.call(selectedFiles);
    }
  }
}
```

---

## 📋 EXAMPLE APP USAGE

### **main.dart no Example App**

```dart
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('File Cloud Example')),
        body: FileCloudWidget(
          providers: [
            // Servidor local customizado
            CustomProviderConfiguration(
              type: CloudProviderType.custom,
              displayName: 'Meu Servidor Local',
              logoWidget: Icon(Icons.storage, color: Colors.blue),
              capabilities: ProviderCapabilities(
                canUpload: true,
                canDownload: true,
                canCreateFolders: true,
                canSearch: true,
                maxFileSize: 50 * 1024 * 1024, // 50MB
                supportedMimeTypes: {'image/*', 'application/pdf'},
              ),
              providerInstance: MyLocalServerProvider(),
            ),
            
            // Google Drive OAuth
            OAuthProviderConfiguration(
              type: CloudProviderType.googleDrive,
              displayName: 'Google Drive',
              logoAssetPath: 'assets/google_drive_logo.png',
              generateAuthUrl: (state) => Uri.parse(
                'https://meubackend.com/oauth/google/authorize?state=$state'
              ),
              generateTokenUrl: (state) => Uri.parse(
                'https://meubackend.com/oauth/google/token/$state'
              ),
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
            
            // OneDrive OAuth
            OAuthProviderConfiguration(
              type: CloudProviderType.oneDrive,
              displayName: 'OneDrive',
              logoAssetPath: 'assets/onedrive_logo.png',
              generateAuthUrl: (state) => Uri.parse(
                'https://meubackend.com/oauth/microsoft/authorize?state=$state'
              ),
              generateTokenUrl: (state) => Uri.parse(
                'https://meubackend.com/oauth/microsoft/token/$state'
              ),
              redirectScheme: 'meuapp://oauth',
              requiredScopes: {OAuthScope.readFiles, OAuthScope.writeFiles},
              capabilities: ProviderCapabilities(
                canUpload: true,
                canDownload: true,
                canCreateFolders: true,
                canSearch: false, // OneDrive search limitado
                maxFileSize: 250 * 1024 * 1024, // 250MB
              ),
            ),
          ],
          accountStorage: SharedPreferencesAccountStorage(),
          selectionConfig: SelectionConfig(
            minSelection: 1,
            maxSelection: 5,
            allowFolders: false,
            allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
            mimeTypeHint: 'Apenas imagens (JPEG, PNG, WebP) e PDFs são aceitos',
            onSelectionConfirm: (files) {
              Navigator.pop(context, files);
            },
          ),
          showProviderSwitcher: true,
          enableGlobalSearch: true,
        ),
      ),
    );
  }
}
```

### **Configuração Específica do Local Server**

```dart
// No example app: my_local_server_configuration.dart
class MyLocalServerConfiguration extends BaseProviderConfiguration {
  final Uri serverBaseUri;
  final Map<String, String> customHeaders;
  final Duration timeout;
  final String? apiKey;
  
  MyLocalServerConfiguration({
    required super.displayName,
    super.logoWidget,
    super.logoAssetPath,
    required super.capabilities,
    required this.serverBaseUri,
    this.customHeaders = const {},
    this.timeout = const Duration(seconds: 30),
    this.apiKey,
  }) : super(type: CloudProviderType.custom);
  
  @override
  bool validate() => super.validate() && serverBaseUri.isAbsolute;
  
  Map<String, String> get headersWithAuth {
    final headers = Map<String, String>.from(customHeaders);
    if (apiKey != null) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }
}

// Usage
CustomProviderConfiguration(
  type: CloudProviderType.custom,
  displayName: 'Meu Servidor',
  capabilities: ProviderCapabilities(/*...*/),
  providerInstance: MyLocalServerProvider()
    ..initialize(
      configuration: MyLocalServerConfiguration(
        displayName: 'Meu Servidor',
        serverBaseUri: Uri.parse('https://api.meuservidor.com'),
        apiKey: 'minha_api_key_secreta',
        capabilities: ProviderCapabilities(/*...*/),
      ),
    ),
)
```

---

## 🚀 FASES DE IMPLEMENTAÇÃO

### **FASE 1: REFATORAÇÃO ARQUITETURAL**
*Estimativa: 2-3 dias*

#### 1.1 Criar Nova Estrutura de Configurações
```
lib/src/models/configurations/
├── base_provider_configuration.dart      # Classe base abstrata
├── oauth_provider_configuration.dart     # OAuth + auth URLs como Uri
├── custom_provider_configuration.dart    # Custom com provider instance
└── provider_factory.dart                # Factory inteligente
```

#### 1.2 Refatorar Providers
```
lib/src/providers/
├── base_cloud_provider.dart             # Base abstrata
├── oauth_cloud_provider.dart            # Base OAuth com implementação comum
├── local_server_cloud_provider.dart     # ABSTRATO para herança
├── google_drive_cloud_provider.dart     # Herda OAuthCloudProvider
├── onedrive_cloud_provider.dart         # Herda OAuthCloudProvider
└── dropbox_cloud_provider.dart          # Herda OAuthCloudProvider
```

#### 1.3 Atualizar Example App
```
example/lib/providers/
├── my_local_server_provider.dart        # Implementação concreta local
├── my_local_server_configuration.dart   # Config específica
└── example_providers_setup.dart         # Setup dos providers
```

### **FASE 2: FUNCIONALIDADES AVANÇADAS**  
*Estimativa: 2 dias*

#### 2.1 Busca Inteligente
- SearchBarWidget com debounce de 400ms
- Cache de resultados de busca
- Loading states apropriados
- Clear functionality

#### 2.2 Infinite Scroll Robusto
- ScrollController com threshold de 80%
- Carregamento progressivo de 50 itens
- Loading indicator no final da lista
- Pull-to-refresh support

#### 2.3 Seleção Avançada
- Filtros de mime-type com wildcards
- Validação em tempo real
- UI para mostrar tipos aceitos
- Limits de seleção respeitados

### **FASE 3: UI ADAPTATIVA**
*Estimativa: 1 dia*

#### 3.1 Capabilities-Driven UI
- Botões aparecem baseado em capabilities
- Validações de upload por capabilities
- Mensagens específicas por limitação
- Tooltips informativos

#### 3.2 Provider Switcher
- Lista horizontal de providers
- Visual feedback para provider ativo
- Logos customizáveis
- Smooth transitions

### **FASE 4: POLIMENTO**
*Estimativa: 1 dia*

#### 4.1 Internacionalização
- Todas strings via Intl.message
- Arquivos .arb organizados
- Suporte multilíngue completo

#### 4.2 Error Handling
- CloudProviderException hierarchy
- User-friendly error messages
- Retry mechanisms
- Offline state handling

---

## 🧪 PLANO DE TESTES

### **Unit Tests**

```dart
// test/configurations_test.dart
group('Configurations', () {
  test('OAuthProviderConfiguration deve validar URLs', () {
    final config = OAuthProviderConfiguration(
      type: CloudProviderType.googleDrive,
      displayName: 'Test',
      generateAuthUrl: (state) => Uri.parse('https://auth.com?state=$state'),
      generateTokenUrl: (state) => Uri.parse('https://token.com/$state'),
      redirectScheme: 'app://oauth',
      requiredScopes: {OAuthScope.readFiles},
      capabilities: ProviderCapabilities(),
    );
    
    expect(config.validate(), true);
    expect(config.generateAuthUrl('test').toString(), contains('state=test'));
  });
  
  test('CustomProviderConfiguration deve aceitar provider instance', () {
    final provider = MyLocalServerProvider();
    final config = CustomProviderConfiguration(
      type: CloudProviderType.custom,
      displayName: 'Test',
      capabilities: ProviderCapabilities(),
      providerInstance: provider,
    );
    
    expect(config.validate(), true);
    expect(config.providerInstance, same(provider));
  });
});

// test/factory_test.dart
group('CloudProviderFactory', () {
  test('deve criar OAuth providers corretamente', () {
    final config = OAuthProviderConfiguration(/*...*/);
    final provider = CloudProviderFactory.createProvider(config);
    
    expect(provider, isA<GoogleDriveCloudProvider>());
    expect(provider.requiresAuthentication, true);
  });
  
  test('deve usar custom provider instance', () {
    final customProvider = MyLocalServerProvider();
    final config = CustomProviderConfiguration(
      type: CloudProviderType.custom,
      displayName: 'Test',
      capabilities: ProviderCapabilities(),
      providerInstance: customProvider,
    );
    
    final provider = CloudProviderFactory.createProvider(config);
    expect(provider, same(customProvider));
  });
});
```

### **Integration Tests**

```dart
// integration_test/multi_provider_test.dart
testWidgets('deve funcionar com múltiplos providers', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FileCloudWidget(
        providers: [
          CustomProviderConfiguration(/*local server*/),
          OAuthProviderConfiguration(/*google drive*/),
        ],
        accountStorage: MemoryAccountStorage(),
      ),
    ),
  );
  
  // Verificar que ambos providers estão na UI
  expect(find.text('Meu Servidor'), findsOneWidget);
  expect(find.text('Google Drive'), findsOneWidget);
  
  // Testar switch entre providers
  await tester.tap(find.text('Google Drive'));
  await tester.pumpAndSettle();
  
  // Verificar que UI se adaptou para OAuth provider
  expect(find.byIcon(Icons.login), findsOneWidget);
});
```

### **Flutter Web Tests**

```dart
// test/web_compatibility_test.dart
@TestOn('browser')
import 'package:flutter_test/flutter_test.dart';

group('Flutter Web Compatibility', () {
  test('deve criar todos providers sem dart:io', () {
    // Testar que factory funciona no web
    expect(() => CloudProviderFactory.createProvider(googleDriveConfig), 
           returnsNormally);
    expect(() => CloudProviderFactory.createProvider(customConfig), 
           returnsNormally);
  });
  
  test('URIs devem ser válidas', () {
    final config = OAuthProviderConfiguration(
      generateAuthUrl: (state) => Uri.parse('https://auth.com?state=$state'),
      // ...
    );
    
    final authUri = config.generateAuthUrl('test123');
    expect(authUri.isAbsolute, true);
    expect(authUri.queryParameters['state'], 'test123');
  });
});
```

---

## 🎯 VALIDAÇÃO FINAL

### **Checklist de Aceitação:**

#### Arquitetura Senior:
- ✅ Hierarquia limpa sem redundâncias (`requiresAuthentication` = `is OAuthConfig`)
- ✅ Factory usa configuração corretamente
- ✅ LocalServer é abstrato para implementação customizada  
- ✅ URIs ao invés de Strings onde faz sentido
- ✅ Zero dependências problemáticas para Flutter Web

#### Funcionalidades RULES.md:
- ✅ Widget 100% configurável via parâmetros
- ✅ Múltiplos provedores simultâneos
- ✅ Busca global com debounce 400ms
- ✅ Infinite scroll 50 itens/página
- ✅ SelectionConfig com mime-type filters
- ✅ UI adaptativa por capabilities
- ✅ Zero client_secret no app

#### Exemplos Práticos:
- ✅ MyLocalServerProvider no example app
- ✅ Configuração híbrida (local + OAuth)
- ✅ Seleção de arquivos com filtros
- ✅ Provider switching funcional

### **Cenários de Uso Validados:**

1. **Local Only**: App empresarial com servidor interno
2. **OAuth Only**: App consumer com Google Drive/OneDrive  
3. **Híbrido**: App com opções local + cloud
4. **Flutter Web**: Todos cenários funcionando perfeitamente
5. **Custom Implementation**: Usuário pode implementar qualquer provider

---

## 🔄 BREAKING CHANGES

### **Migração Obrigatória:**

```dart
// ❌ CÓDIGO ANTIGO (não funciona)
FileCloudWidget(
  oauthConfig: OAuthConfig(
    clientId: 'abc',
    authUrl: 'https://auth.com',
    // ...
  ),
  accountStorage: storage,
)

// ✅ CÓDIGO NOVO (obrigatório)
FileCloudWidget(
  providers: [
    OAuthProviderConfiguration(
      type: CloudProviderType.googleDrive,
      displayName: 'Google Drive',
      generateAuthUrl: (state) => Uri.parse('https://backend.com/oauth/google?state=$state'),
      generateTokenUrl: (state) => Uri.parse('https://backend.com/oauth/token/$state'),
      redirectScheme: 'app://oauth',
      requiredScopes: {OAuthScope.readFiles},
      capabilities: ProviderCapabilities(/*...*/),
    ),
  ],
  accountStorage: storage,
)
```

### **Providers Customizados:**

```dart
// No example app - implementação concreta
class MyLocalServerProvider extends LocalServerCloudProvider {
  // Implementa todos métodos abstratos específicos para seu servidor
}

// Configuração customizada
class MyServerConfig extends BaseProviderConfiguration {
  final Uri serverUri;
  final String apiKey;
  
  MyServerConfig({
    required super.displayName,
    required super.capabilities,
    required this.serverUri,
    required this.apiKey,
  }) : super(type: CloudProviderType.custom);
}

// Usage
CustomProviderConfiguration(
  type: CloudProviderType.custom,
  displayName: 'Meu Servidor',
  capabilities: ProviderCapabilities(/*...*/),
  providerInstance: MyLocalServerProvider()
    ..initialize(configuration: MyServerConfig(/*...*/)),
)
```

---

## 📈 RESULTADOS ESPERADOS

### **Qualidade de Código:**
- Arquitetura extensível e type-safe
- Zero code duplication
- Separation of concerns perfeita
- Flutter Web compatibility garantida

### **Developer Experience:**
- API intuitiva e type-safe
- Configuração declarativa simples
- Extensibilidade para qualquer provider
- Documentação e exemplos claros

### **Performance:**
- Lazy loading de providers
- Efficient URI handling
- Optimized infinite scroll
- Smart search debouncing

### **Flexibilidade:**
- Suporte a qualquer tipo de servidor
- OAuth flow customizável
- Capabilities-driven UI
- Múltiplos providers simultâneos

---

**Status:** PLANEJADO V3 - SENIOR ARCHITECTURE  
**Última atualização:** 2025-09-01  
**Responsável:** Claude (Opus 4.1)  
**Revisão:** Arquitetura senior elimina redundâncias, URIs corretas, providers abstratos