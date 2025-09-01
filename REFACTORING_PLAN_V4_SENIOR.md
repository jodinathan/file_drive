# 📋 PLANO DE REFATORAÇÃO V4 - ARQUITETURA SENIOR

## 📅 Data: 2025-09-01  
## 🎯 Objetivo: Arquitetura senior-level com hierarquia inteligente e type safety

---

## 🎯 ARQUITETURA SENIOR DEFINITIVA

### **1. Configurações com Hierarquia Inteligente**

```dart
// Base - apenas file operations
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

// OAuth - adiciona auth específico
class OAuthProviderConfiguration extends BaseProviderConfiguration {
  final Uri Function(String state) generateAuthUrl;
  final Uri Function(String state) generateTokenUrl;
  final String redirectScheme;
  final Set<OAuthScope> requiredScopes;
  final Map<String, String> extraAuthParams;
  
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
    this.extraAuthParams = const {},
  });
  
  @override
  bool validate() => super.validate() && 
                     redirectScheme.isNotEmpty && 
                     requiredScopes.isNotEmpty;
}

// Local - adiciona server específico (SEM auth)
class LocalProviderConfiguration extends BaseProviderConfiguration {
  final Uri serverBaseUri;
  final Map<String, String> defaultHeaders;
  final Duration requestTimeout;
  final String? apiKeyHeader;
  final String? apiKey;
  
  const LocalProviderConfiguration({
    required super.displayName,
    super.logoWidget,
    super.logoAssetPath,
    required super.capabilities,
    required this.serverBaseUri,
    this.defaultHeaders = const {},
    this.requestTimeout = const Duration(seconds: 30),
    this.apiKeyHeader,
    this.apiKey,
  }) : super(type: CloudProviderType.localServer);
  
  @override
  bool validate() => super.validate() && serverBaseUri.isAbsolute;
  
  Map<String, String> get computedHeaders {
    final headers = Map<String, String>.from(defaultHeaders);
    if (apiKeyHeader != null && apiKey != null) {
      headers[apiKeyHeader!] = apiKey!;
    }
    return headers;
  }
}

// Custom - usuário passa provider pronto
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
}
```

### **2. Hierarquia de Providers Senior**

```dart
// Base - APENAS file operations
abstract class BaseCloudProvider {
  // Métodos abstratos - file operations universais
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
  
  ProviderCapabilities getCapabilities();
}

// OAuth Provider - adiciona auth + herda file ops
abstract class OAuthCloudProvider extends BaseCloudProvider {
  late final OAuthProviderConfiguration _config;
  late http.Client _httpClient;
  CloudAccount? _currentAccount;
  
  // Configuration tipada e não-nula
  OAuthProviderConfiguration get config => _config;
  CloudAccount? get currentAccount => _currentAccount;
  bool get isAuthenticated => _currentAccount != null;
  
  void initialize({
    required OAuthProviderConfiguration configuration,
    CloudAccount? account,
  }) {
    _config = configuration;
    _currentAccount = account;
    _httpClient = http.Client();
    onOAuthConfigured();
  }
  
  @protected
  void onOAuthConfigured() {} // Hook para subclasses
  
  @override
  ProviderCapabilities getCapabilities() => config.capabilities;
  
  // Métodos de AUTH específicos (não existem no BaseCloudProvider)
  Future<String> startOAuthFlow() async {
    final state = _generateSecureState();
    final authUri = config.generateAuthUrl(state);
    await _launchAuthUrl(authUri);
    return state;
  }
  
  Future<CloudAccount> exchangeCodeForToken({
    required String code,
    required String state,
  }) async {
    final tokenUri = config.generateTokenUrl(state);
    
    final response = await _httpClient.post(
      tokenUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'state': state,
        ...config.extraAuthParams,
      }),
    );
    
    if (response.statusCode != 200) {
      throw CloudProviderException('OAuth exchange failed: ${response.statusCode}');
    }
    
    final account = CloudAccount.fromJson(jsonDecode(response.body));
    _currentAccount = account;
    return account;
  }
  
  Future<CloudAccount> refreshAuth(CloudAccount account) async {
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
  
  Future<UserProfile> getUserProfile() async {
    if (!isAuthenticated) {
      throw StateError('Not authenticated');
    }
    
    // Implementação específica em subclasses
    return getAuthenticatedUserProfile();
  }
  
  @protected
  Future<UserProfile> getAuthenticatedUserProfile();
  
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
  
  Map<String, String> get authHeaders => {
    'Authorization': 'Bearer ${currentAccount?.accessToken}',
    'Content-Type': 'application/json',
  };
}

// Local Provider - SEM auth, apenas file ops
abstract class LocalCloudProvider extends BaseCloudProvider {
  late final LocalProviderConfiguration _config;
  late http.Client _httpClient;
  
  // Configuration tipada e não-nula  
  LocalProviderConfiguration get config => _config;
  
  void initialize(LocalProviderConfiguration configuration) {
    _config = configuration;
    _httpClient = http.Client();
    onLocalConfigured();
  }
  
  @protected
  void onLocalConfigured() {} // Hook para subclasses
  
  @override
  ProviderCapabilities getCapabilities() => config.capabilities;
  
  // Helper methods para subclasses
  Uri buildApiUri(String path, [Map<String, String>? queryParams]) {
    return config.serverBaseUri.replace(
      path: '${config.serverBaseUri.path}$path',
      queryParameters: queryParams,
    );
  }
  
  Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    ...config.computedHeaders,
  };
  
  Future<http.Response> get(String path, [Map<String, String>? queryParams]) async {
    final uri = buildApiUri(path, queryParams);
    return await _httpClient.get(uri, headers: defaultHeaders);
  }
  
  Future<http.Response> post(String path, Object? body) async {
    final uri = buildApiUri(path);
    return await _httpClient.post(
      uri, 
      headers: defaultHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }
  
  Future<http.Response> delete(String path) async {
    final uri = buildApiUri(path);
    return await _httpClient.delete(uri, headers: defaultHeaders);
  }
}
```

### **3. Factory Pattern Inteligente**

```dart
class CloudProviderFactory {
  // Registry apenas para OAuth built-ins
  static final Map<CloudProviderType, OAuthCloudProvider Function()> _oauthRegistry = {
    CloudProviderType.googleDrive: () => GoogleDriveCloudProvider(),
    CloudProviderType.oneDrive: () => OneDriveCloudProvider(),
    CloudProviderType.dropbox: () => DropboxCloudProvider(),
  };
  
  static BaseCloudProvider createAndInitialize(BaseProviderConfiguration config) {
    final provider = _createProvider(config);
    _initializeProvider(provider, config);
    return provider;
  }
  
  static BaseCloudProvider _createProvider(BaseProviderConfiguration config) {
    // Custom providers já vêm instanciados
    if (config is CustomProviderConfiguration) {
      return config.providerInstance;
    }
    
    // OAuth providers do registry
    if (config is OAuthProviderConfiguration) {
      final builder = _oauthRegistry[config.type];
      if (builder == null) {
        throw UnsupportedError('OAuth provider ${config.type} não registrado');
      }
      return builder();
    }
    
    // LocalProviderConfiguration não pode ser criada pelo factory
    // Usuário deve usar CustomProviderConfiguration com provider local
    throw ArgumentError(
      'LocalProviderConfiguration deve ser usada com CustomProviderConfiguration. '
      'Crie seu provider local e passe via CustomProviderConfiguration.'
    );
  }
  
  static void _initializeProvider(BaseCloudProvider provider, BaseProviderConfiguration config) {
    if (provider is OAuthCloudProvider && config is OAuthProviderConfiguration) {
      provider.initialize(configuration: config);
    } else if (provider is LocalCloudProvider && config is LocalProviderConfiguration) {
      provider.initialize(config);
    } else if (config is CustomProviderConfiguration) {
      // Custom provider já deve estar inicializado pelo usuário
      // Apenas verifica se está correto
      if (provider.getCapabilities() != config.capabilities) {
        throw ArgumentError('Provider capabilities não coincidem com configuration');
      }
    } else {
      throw ArgumentError('Incompatibilidade entre provider e configuration');
    }
  }
  
  static void registerOAuthProvider(
    CloudProviderType type,
    OAuthCloudProvider Function() builder,
  ) {
    _oauthRegistry[type] = builder;
  }
}
```

---

## 🔧 IMPLEMENTAÇÕES CONCRETAS

### **Google Drive OAuth Provider**

```dart
class GoogleDriveCloudProvider extends OAuthCloudProvider {
  static const String _apiBaseUrl = 'https://www.googleapis.com/drive/v3';
  
  @override
  Future<FileListPage> listFolder({
    String? parentId,
    int limit = 50,
    String? pageToken,
  }) async {
    if (!isAuthenticated) {
      throw StateError('Google Drive requer autenticação');
    }
    
    final queryParams = <String, String>{
      'pageSize': limit.toString(),
      'fields': 'nextPageToken, files(id, name, mimeType, size, modifiedTime, parents)',
      'q': parentId != null ? "'$parentId' in parents" : "'root' in parents",
      if (pageToken != null) 'pageToken': pageToken,
    };
    
    final uri = Uri.parse('$_apiBaseUrl/files').replace(queryParameters: queryParams);
    final response = await _httpClient.get(uri, headers: authHeaders);
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Lista falhou: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body);
    return FileListPage(
      files: (data['files'] as List).map((f) => _mapGoogleFileToEntry(f)).toList(),
      hasMore: data['nextPageToken'] != null,
      nextPageToken: data['nextPageToken'],
    );
  }
  
  @override
  Future<UserProfile> getAuthenticatedUserProfile() async {
    final uri = Uri.parse('$_apiBaseUrl/about').replace(
      queryParameters: {'fields': 'user(displayName,emailAddress,photoLink)'},
    );
    
    final response = await _httpClient.get(uri, headers: authHeaders);
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Profile fetch failed: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body)['user'];
    return UserProfile(
      id: currentAccount!.userId,
      name: data['displayName'],
      email: data['emailAddress'],
      avatarUrl: data['photoLink'],
    );
  }
  
  FileEntry _mapGoogleFileToEntry(Map<String, dynamic> driveFile) {
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
  
  // ... resto dos métodos file operations
}
```

### **Example App - Local Server Implementation**

**Arquivo:** `example/lib/providers/example_local_server_provider.dart`

```dart
class ExampleLocalServerProvider extends LocalCloudProvider {
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
    
    final response = await get('/files', queryParams);
    
    if (response.statusCode != 200) {
      throw CloudProviderException('List failed: ${response.statusCode}');
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
    final response = await post('/folders', {
      'name': name,
      if (parentId != null) 'parent_id': parentId,
    });
    
    if (response.statusCode != 201) {
      throw CloudProviderException('Folder creation failed: ${response.statusCode}');
    }
    
    return FileEntry.fromJson(jsonDecode(response.body));
  }
  
  @override
  Future<void> deleteEntry(String entryId) async {
    final response = await delete('/files/$entryId');
    
    if (response.statusCode != 204) {
      throw CloudProviderException('Delete failed: ${response.statusCode}');
    }
  }
  
  @override
  Stream<List<int>> downloadFile(String fileId) async* {
    final uri = buildApiUri('/files/$fileId/download');
    final request = http.Request('GET', uri);
    request.headers.addAll(defaultHeaders);
    
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
    final uri = buildApiUri('/files/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(defaultHeaders);
    
    request.fields['name'] = name;
    if (parentId != null) request.fields['parent_id'] = parentId;
    if (mimeType != null) request.fields['mime_type'] = mimeType;
    
    request.files.add(http.MultipartFile(
      'file',
      fileStream,
      fileSize,
      filename: name,
    ));
    
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
    
    final response = await get('/search', queryParams);
    
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

---

## 🎯 FILECLOUD WIDGET SENIOR

### **Widget Principal com Type Safety**

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
  }) : assert(providers.isNotEmpty, 'Pelo menos um provider é obrigatório'),
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
    _initializeAllProviders();
    _loadStoredAccountsForOAuthProviders();
  }
  
  void _initializeAllProviders() {
    for (final config in widget.providers) {
      try {
        final provider = CloudProviderFactory.createAndInitialize(config);
        _providers[config.type] = provider;
      } catch (e) {
        debugPrint('Failed to initialize ${config.type}: $e');
      }
    }
    
    if (_providers.isNotEmpty) {
      _selectedProviderType = _providers.keys.first;
    }
  }
  
  Future<void> _loadStoredAccountsForOAuthProviders() async {
    for (final entry in _providers.entries) {
      final provider = entry.value;
      
      // Apenas OAuth providers precisam de contas armazenadas
      if (provider is OAuthCloudProvider) {
        final account = await widget.accountStorage.getAccount(entry.key);
        if (account != null) {
          provider._currentAccount = account;
        }
      }
      // Local providers não precisam de contas
    }
    
    if (mounted) setState(() {});
  }
  
  BaseCloudProvider? get _currentProvider => 
    _selectedProviderType != null ? _providers[_selectedProviderType] : null;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showProviderSwitcher && _providers.length > 1)
          _buildProviderSwitcher(),
        
        if (_currentProvider != null)
          _buildAdaptiveNavigationBar(),
        
        if (widget.selectionConfig != null)
          FileTypeFilterWidget(selectionConfig: widget.selectionConfig!),
        
        Expanded(
          child: _currentProvider != null
            ? InfiniteScrollFileList(
                provider: _currentProvider!,
                selectionConfig: widget.selectionConfig,
                onSelectionChanged: _handleSelectionChanged,
              )
            : _buildNoProvidersState(),
        ),
      ],
    );
  }
  
  Widget _buildAdaptiveNavigationBar() {
    final provider = _currentProvider!;
    
    // OAuth provider precisa verificar auth antes de mostrar features
    if (provider is OAuthCloudProvider && !provider.isAuthenticated) {
      return _buildAuthenticationRequired(provider);
    }
    
    // Provider local ou OAuth autenticado - mostra features completas
    return AdaptiveNavigationBar(
      provider: provider,
      showSearch: widget.enableGlobalSearch && provider.getCapabilities().canSearch,
      onUpload: provider.getCapabilities().canUpload ? _handleUpload : null,
      onCreateFolder: provider.getCapabilities().canCreateFolders ? _handleCreateFolder : null,
      onRefresh: _handleRefresh,
    );
  }
  
  Widget _buildAuthenticationRequired(OAuthCloudProvider oauthProvider) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Autenticação necessária para ${oauthProvider.config.displayName}'),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _authenticateProvider(oauthProvider),
            child: Text('Conectar'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _authenticateProvider(OAuthCloudProvider provider) async {
    try {
      final state = await provider.startOAuthFlow();
      // Aguardar callback do OAuth
      // Implementação específica do redirect handling
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na autenticação: $e')),
      );
    }
  }
}
```

---

## 📋 EXAMPLE APP COMPLETO

### **main.dart Senior Implementation**

```dart
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Cloud Example',
      home: Scaffold(
        appBar: AppBar(title: Text('Multi-Provider File Manager')),
        body: FileCloudWidget(
          providers: [
            // Local server customizado
            CustomProviderConfiguration(
              type: CloudProviderType.custom,
              displayName: 'Meu Servidor Local',
              logoWidget: Icon(Icons.storage, color: Colors.blue),
              capabilities: ProviderCapabilities(
                canUpload: true,
                canDownload: true,
                canCreateFolders: true,
                canDeleteFiles: true,
                canSearch: true,
                maxFileSize: 100 * 1024 * 1024, // 100MB
                supportedMimeTypes: {'image/*', 'application/pdf', 'text/*'},
              ),
              providerInstance: ExampleLocalServerProvider()
                ..initialize(LocalProviderConfiguration(
                  displayName: 'Meu Servidor Local',
                  serverBaseUri: Uri.parse('https://files.meuserver.com/api/v1'),
                  apiKeyHeader: 'X-API-Key',
                  apiKey: 'minha_chave_secreta',
                  capabilities: ProviderCapabilities(
                    canUpload: true,
                    canDownload: true,
                    canCreateFolders: true,
                    canDeleteFiles: true,
                    canSearch: true,
                    maxFileSize: 100 * 1024 * 1024,
                    supportedMimeTypes: {'image/*', 'application/pdf', 'text/*'},
                  ),
                )),
            ),
            
            // Google Drive OAuth
            OAuthProviderConfiguration(
              type: CloudProviderType.googleDrive,
              displayName: 'Google Drive',
              logoAssetPath: 'assets/logos/google_drive.png',
              generateAuthUrl: (state) => Uri.parse(
                'https://backend.meuapp.com/oauth/google/authorize?state=$state'
              ),
              generateTokenUrl: (state) => Uri.parse(
                'https://backend.meuapp.com/oauth/google/token/$state'
              ),
              redirectScheme: 'meuapp://oauth',
              requiredScopes: {
                OAuthScope.readFiles,
                OAuthScope.writeFiles,
                OAuthScope.userProfile,
              },
              capabilities: ProviderCapabilities(
                canUpload: true,
                canDownload: true,
                canCreateFolders: true,
                canDeleteFiles: true,
                canSearch: true,
                canShare: true,
                supportsThumbnails: true,
                supportsVersioning: true,
                maxFileSize: -1, // Ilimitado
              ),
            ),
            
            // OneDrive OAuth
            OAuthProviderConfiguration(
              type: CloudProviderType.oneDrive,
              displayName: 'OneDrive',
              logoAssetPath: 'assets/logos/onedrive.png',
              generateAuthUrl: (state) => Uri.parse(
                'https://backend.meuapp.com/oauth/microsoft/authorize?state=$state'
              ),
              generateTokenUrl: (state) => Uri.parse(
                'https://backend.meuapp.com/oauth/microsoft/token/$state'
              ),
              redirectScheme: 'meuapp://oauth',
              requiredScopes: {
                OAuthScope.readFiles,
                OAuthScope.writeFiles,
              },
              capabilities: ProviderCapabilities(
                canUpload: true,
                canDownload: true,
                canCreateFolders: true,
                canDeleteFiles: true,
                canSearch: false, // OneDrive search é limitado
                maxFileSize: 250 * 1024 * 1024, // 250MB limit
              ),
            ),
          ],
          accountStorage: SharedPreferencesAccountStorage(),
          selectionConfig: SelectionConfig(
            minSelection: 1,
            maxSelection: 3,
            allowFolders: false,
            allowedMimeTypes: [
              'image/jpeg',
              'image/png', 
              'image/webp',
              'application/pdf'
            ],
            mimeTypeHint: 'Apenas imagens (JPEG, PNG, WebP) e PDFs',
            onSelectionConfirm: (selectedFiles) {
              _handleSelectedFiles(selectedFiles);
            },
          ),
          showProviderSwitcher: true,
          enableGlobalSearch: true,
        ),
      ),
    );
  }
  
  void _handleSelectedFiles(List<FileEntry> files) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Arquivos Selecionados'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: files.map((f) => Text(f.name)).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

---

## 🔍 COMPONENTES AUXILIARES

### **Selection Config Inteligente**

```dart
class SelectionConfig {
  final int minSelection;
  final int maxSelection;
  final bool allowFolders;
  final List<String> allowedMimeTypes;
  final String? mimeTypeHint;
  final bool showTypeFilters;
  final Function(List<FileEntry>) onSelectionConfirm;
  
  const SelectionConfig({
    this.minSelection = 1,
    this.maxSelection = 1,
    this.allowFolders = false,
    this.allowedMimeTypes = const [],
    this.mimeTypeHint,
    this.showTypeFilters = true,
    required this.onSelectionConfirm,
  }) : assert(minSelection >= 0),
       assert(maxSelection >= minSelection),
       assert(maxSelection > 0);
  
  bool isFileAllowed(FileEntry file) {
    if (file.isFolder && !allowFolders) return false;
    if (allowedMimeTypes.isEmpty) return true;
    
    final fileMimeType = file.mimeType ?? '';
    return allowedMimeTypes.any((pattern) => _matchesMimePattern(fileMimeType, pattern));
  }
  
  bool _matchesMimePattern(String fileMimeType, String pattern) {
    if (pattern.contains('*')) {
      final regex = RegExp('^${pattern.replaceAll('*', '.*')}\$');
      return regex.hasMatch(fileMimeType);
    }
    return fileMimeType == pattern;
  }
  
  List<String> get friendlyTypeNames {
    return allowedMimeTypes.map((type) {
      if (type == 'image/*') return 'Imagens';
      if (type == 'image/jpeg') return 'JPEG';
      if (type == 'image/png') return 'PNG';
      if (type == 'application/pdf') return 'PDF';
      if (type == 'text/*') return 'Textos';
      if (type == 'video/*') return 'Vídeos';
      return type.split('/').last.toUpperCase();
    }).toList();
  }
}
```

### **Infinite Scroll Performático**

```dart
class InfiniteScrollFileList extends StatefulWidget {
  final BaseCloudProvider provider;
  final SelectionConfig? selectionConfig;
  final Function(List<FileEntry>) onSelectionChanged;
  final String? currentFolderId;
  final String? searchQuery;
  
  const InfiniteScrollFileList({
    Key? key,
    required this.provider,
    required this.onSelectionChanged,
    this.selectionConfig,
    this.currentFolderId,
    this.searchQuery,
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
  static const double _scrollThreshold = 0.8;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }
  
  @override
  void didUpdateWidget(InfiniteScrollFileList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
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
        page = await widget.provider.searchByName(
          query: widget.searchQuery!,
          parentId: widget.currentFolderId,
          limit: _pageSize,
          pageToken: reset ? null : _nextPageToken,
        );
      } else {
        page = await widget.provider.listFolder(
          parentId: widget.currentFolderId,
          limit: _pageSize,
          pageToken: reset ? null : _nextPageToken,
        );
      }
      
      setState(() {
        if (reset) {
          _files.clear();
          _selectedFileIds.clear();
        }
        _files.addAll(page.files);
        _hasMore = page.hasMore;
        _nextPageToken = page.nextPageToken;
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_files.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }
    
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
  
  Widget _buildFileItem(FileEntry file) {
    final isSelected = _selectedFileIds.contains(file.id);
    final isSelectable = widget.selectionConfig?.isFileAllowed(file) ?? false;
    final isInSelectionMode = widget.selectionConfig != null;
    
    return ListTile(
      leading: _buildFileIcon(file),
      title: Text(file.name),
      subtitle: _buildFileSubtitle(file),
      trailing: isInSelectionMode
        ? Checkbox(
            value: isSelected,
            onChanged: isSelectable ? (_) => _toggleSelection(file) : null,
          )
        : null,
      onTap: () => _handleFileTap(file),
      enabled: !isInSelectionMode || isSelectable,
    );
  }
  
  void _toggleSelection(FileEntry file) {
    final config = widget.selectionConfig!;
    
    if (!config.isFileAllowed(file)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(config.mimeTypeHint ?? 'Arquivo não permitido')),
      );
      return;
    }
    
    setState(() {
      if (_selectedFileIds.contains(file.id)) {
        _selectedFileIds.remove(file.id);
      } else {
        if (_selectedFileIds.length >= config.maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Máximo ${config.maxSelection} arquivos')),
          );
          return;
        }
        _selectedFileIds.add(file.id);
      }
    });
    
    final selectedFiles = _files.where((f) => _selectedFileIds.contains(f.id)).toList();
    widget.onSelectionChanged(selectedFiles);
    
    if (selectedFiles.length >= config.minSelection) {
      config.onSelectionConfirm(selectedFiles);
    }
  }
}
```

---

## 🧪 TESTING STRATEGY SENIOR

### **Architecture Tests**

```dart
// test/architecture_test.dart
group('Architecture Validation', () {
  test('OAuth providers devem herdar OAuthCloudProvider', () {
    final googleProvider = GoogleDriveCloudProvider();
    expect(googleProvider, isA<OAuthCloudProvider>());
    expect(googleProvider, isA<BaseCloudProvider>());
  });
  
  test('Local providers devem herdar LocalCloudProvider', () {
    final localProvider = ExampleLocalServerProvider();
    expect(localProvider, isA<LocalCloudProvider>());
    expect(localProvider, isA<BaseCloudProvider>());
    // Local provider NÃO deve ter métodos OAuth
    expect(localProvider, isNot(isA<OAuthCloudProvider>()));
  });
  
  test('Configurations devem ser type-safe', () {
    final oauthConfig = OAuthProviderConfiguration(/*...*/);
    final localConfig = LocalProviderConfiguration(/*...*/);
    
    expect(oauthConfig, isA<BaseProviderConfiguration>());
    expect(localConfig, isA<BaseProviderConfiguration>());
    expect(oauthConfig, isNot(isA<LocalProviderConfiguration>()));
  });
});
```

### **Type Safety Tests**

```dart
// test/type_safety_test.dart
group('Type Safety', () {
  test('OAuth provider deve receber OAuth config', () {
    final provider = GoogleDriveCloudProvider();
    final config = OAuthProviderConfiguration(/*...*/);
    
    expect(() => provider.initialize(configuration: config), returnsNormally);
    expect(provider.config, same(config));
    expect(provider.config.generateAuthUrl('test'), isA<Uri>());
  });
  
  test('Local provider deve receber Local config', () {
    final provider = ExampleLocalServerProvider();
    final config = LocalProviderConfiguration(/*...*/);
    
    expect(() => provider.initialize(config), returnsNormally);
    expect(provider.config, same(config));
    expect(provider.config.serverBaseUri, isA<Uri>());
  });
  
  test('Factory deve validar compatibility', () {
    final localConfig = LocalProviderConfiguration(/*...*/);
    
    // LocalProviderConfiguration não deve ser aceita diretamente pelo factory
    expect(
      () => CloudProviderFactory.createAndInitialize(localConfig),
      throwsArgumentError,
    );
  });
});
```

### **Flutter Web Tests**

```dart
// test/web_compatibility_test.dart
@TestOn('browser')
group('Flutter Web Compatibility', () {
  test('deve funcionar sem dart:io imports', () {
    final providers = [
      GoogleDriveCloudProvider(),
      OneDriveCloudProvider(),
      ExampleLocalServerProvider(),
    ];
    
    for (final provider in providers) {
      expect(provider, isA<BaseCloudProvider>());
    }
  });
  
  test('URIs devem ser válidas no web', () {
    final config = OAuthProviderConfiguration(
      type: CloudProviderType.googleDrive,
      displayName: 'Test',
      generateAuthUrl: (state) => Uri.parse('https://auth.com?state=$state&web=true'),
      generateTokenUrl: (state) => Uri.parse('https://token.com/$state'),
      redirectScheme: 'https://myapp.com/oauth-callback',
      requiredScopes: {OAuthScope.readFiles},
      capabilities: ProviderCapabilities(),
    );
    
    final authUri = config.generateAuthUrl('web-test');
    expect(authUri.scheme, 'https');
    expect(authUri.queryParameters['state'], 'web-test');
    expect(authUri.queryParameters['web'], 'true');
  });
});
```

---

## 🚀 MIGRATION GUIDE

### **De V1 para V4 Senior**

#### 1. Substituir Configurações
```dart
// ❌ V1 - obsoleto
OAuthConfig(
  clientId: 'abc',
  authUrl: 'https://auth.com',
)

// ✅ V4 - senior
OAuthProviderConfiguration(
  type: CloudProviderType.googleDrive,
  displayName: 'Google Drive',
  generateAuthUrl: (state) => Uri.parse('https://backend.com/oauth?state=$state'),
  generateTokenUrl: (state) => Uri.parse('https://backend.com/token/$state'),
  redirectScheme: 'app://oauth',
  requiredScopes: {OAuthScope.readFiles},
  capabilities: ProviderCapabilities(/*...*/),
)
```

#### 2. Implementar Providers Locais
```dart
// Criar provider customizado
class MyServerProvider extends LocalCloudProvider {
  // Implementar métodos abstratos
}

// Usar CustomProviderConfiguration
CustomProviderConfiguration(
  type: CloudProviderType.custom,
  displayName: 'Meu Servidor',
  capabilities: ProviderCapabilities(/*...*/),
  providerInstance: MyServerProvider()..initialize(LocalProviderConfiguration(/*...*/)),
)
```

#### 3. Atualizar Widget Usage
```dart
// ❌ V1 - um provider só
FileCloudWidget(
  oauthConfig: config,
  accountStorage: storage,
)

// ✅ V4 - múltiplos providers
FileCloudWidget(
  providers: [
    oauthConfig,      // OAuth providers
    customConfig,     // Local/custom providers
  ],
  accountStorage: storage,
)
```

---

## 🎯 RESULTADOS ESPERADOS

### **Senior-Level Architecture:**
- Type safety completa em tempo de compilação
- Hierarquia clara sem redundâncias
- Separation of concerns perfeita
- Flutter Web compatibility nativa

### **Developer Experience:**
- API intuitiva e self-documenting
- Zero configuração nullable desnecessária
- Compile-time validation de configs
- Extensibilidade natural

### **Code Quality:**
- Zero code duplication
- Single responsibility principle
- Proper abstraction levels
- Clean inheritance hierarchy

### **Flexibilidade Máxima:**
- Qualquer tipo de servidor local
- Qualquer OAuth provider
- Múltiplos providers simultâneos
- UI completamente adaptativa

---

## 📊 MÉTRICAS DE QUALIDADE

### **Code Metrics:**
- **Cyclomatic Complexity**: < 5 por método
- **Coupling**: Baixo (cada provider é independente)
- **Cohesion**: Alto (responsabilidades bem definidas)
- **Testability**: 100% mockable e testável

### **Type Safety:**
- Zero `dynamic` usage
- Zero nullable desnecessário
- Compile-time config validation
- Runtime type checking

### **Performance:**
- Lazy provider initialization
- Efficient URI handling
- Smart infinite scroll
- Debounced search

---

**Status:** PLANEJADO V4 - SENIOR ARCHITECTURE  
**Responsável:** Claude (Opus 4.1)  
**Validação:** Arquitetura senior com hierarquia inteligente, type safety e zero redundâncias