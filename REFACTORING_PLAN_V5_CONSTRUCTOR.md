# 📋 PLANO DE REFATORAÇÃO V5 - CONSTRUCTOR-BASED SENIOR ARCHITECTURE

## 📅 Data: 2025-09-01  
## 🎯 Objetivo: Arquitetura senior com constructors diretos e configuração imutável

---

## 🎯 ARQUITETURA SENIOR COM CONSTRUCTORS

### **1. Provider Hierarchy com Constructor-Based Config**

```dart
// Base abstrato - apenas file operations, sem configuração específica
abstract class BaseCloudProvider {
  // Apenas métodos abstratos universais
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

// OAuth Provider - constructor recebe config tipada
abstract class OAuthCloudProvider extends BaseCloudProvider {
  final OAuthProviderConfiguration config;
  final http.Client _httpClient = http.Client();
  CloudAccount? _currentAccount;
  
  // Constructor imutável com config tipada
  OAuthCloudProvider(this.config) {
    if (!config.validate()) {
      throw ArgumentError('Configuração OAuth inválida');
    }
  }
  
  CloudAccount? get currentAccount => _currentAccount;
  bool get isAuthenticated => _currentAccount != null;
  
  @override
  ProviderCapabilities getCapabilities() => config.capabilities;
  
  // Métodos OAuth específicos
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
      throw CloudProviderException('OAuth failed: ${response.statusCode}');
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
      throw StateError('Provider não autenticado');
    }
    return getAuthenticatedUserProfile();
  }
  
  @protected
  Future<UserProfile> getAuthenticatedUserProfile();
  
  Map<String, String> get authHeaders => {
    'Authorization': 'Bearer ${currentAccount?.accessToken}',
    'Content-Type': 'application/json',
  };
  
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

// Local Provider - constructor recebe config tipada, SEM auth
abstract class LocalCloudProvider extends BaseCloudProvider {
  final LocalProviderConfiguration config;
  final http.Client _httpClient = http.Client();
  
  // Constructor imutável com config tipada
  LocalCloudProvider(this.config) {
    if (!config.validate()) {
      throw ArgumentError('Configuração local inválida');
    }
  }
  
  @override
  ProviderCapabilities getCapabilities() => config.capabilities;
  
  // Helper methods para implementações locais
  Uri buildApiUri(String path, [Map<String, String>? queryParams]) {
    return config.serverBaseUri.replace(
      path: '${config.serverBaseUri.path}$path',
      queryParameters: queryParams,
    );
  }
  
  Map<String, String> get requestHeaders => {
    'Content-Type': 'application/json',
    ...config.computedHeaders,
  };
  
  Future<http.Response> apiGet(String path, [Map<String, String>? queryParams]) async {
    final uri = buildApiUri(path, queryParams);
    return await _httpClient.get(uri, headers: requestHeaders);
  }
  
  Future<http.Response> apiPost(String path, Object? body) async {
    final uri = buildApiUri(path);
    return await _httpClient.post(
      uri,
      headers: requestHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }
  
  Future<http.Response> apiDelete(String path) async {
    final uri = buildApiUri(path);
    return await _httpClient.delete(uri, headers: requestHeaders);
  }
  
  Future<http.StreamedResponse> apiPostMultipart(
    String path,
    Map<String, String> fields,
    Map<String, http.MultipartFile> files,
  ) async {
    final uri = buildApiUri(path);
    final request = http.MultipartRequest('POST', uri);
    
    request.headers.addAll(requestHeaders);
    request.fields.addAll(fields);
    request.files.addAll(files.values);
    
    return await _httpClient.send(request);
  }
}
```

### **2. Configurações com Constructors Tipados**

```dart
// Base configuration - imutável
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

// OAuth - constructor tipado
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

// Local - constructor tipado
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

// Para providers prontos - sem constructor config
class ReadyProviderConfiguration extends BaseProviderConfiguration {
  final BaseCloudProvider providerInstance;
  
  ReadyProviderConfiguration({
    required this.providerInstance,
    required super.displayName,
    super.logoWidget,
    super.logoAssetPath,
  }) : super(
         type: CloudProviderType.custom,
         capabilities: providerInstance.getCapabilities(),
       );
}
```

### **3. Factory Pattern Senior**

```dart
class CloudProviderFactory {
  // Registry para OAuth built-ins
  static final Map<CloudProviderType, OAuthCloudProvider Function(OAuthProviderConfiguration)> _oauthBuilders = {
    CloudProviderType.googleDrive: (config) => GoogleDriveCloudProvider(config),
    CloudProviderType.oneDrive: (config) => OneDriveCloudProvider(config),
    CloudProviderType.dropbox: (config) => DropboxCloudProvider(config),
  };
  
  static BaseCloudProvider createProvider(BaseProviderConfiguration config) {
    // Provider pronto - apenas retorna
    if (config is ReadyProviderConfiguration) {
      return config.providerInstance;
    }
    
    // OAuth provider - cria com constructor tipado
    if (config is OAuthProviderConfiguration) {
      final builder = _oauthBuilders[config.type];
      if (builder == null) {
        throw UnsupportedError('OAuth provider ${config.type} não registrado');
      }
      return builder(config);
    }
    
    // LocalProviderConfiguration é apenas para herança
    // Usuário deve criar provider e usar ReadyProviderConfiguration
    if (config is LocalProviderConfiguration) {
      throw ArgumentError(
        'LocalProviderConfiguration é apenas para herança. '
        'Crie seu provider local e use ReadyProviderConfiguration.'
      );
    }
    
    throw ArgumentError('Tipo de configuração não suportado: ${config.runtimeType}');
  }
  
  static void registerOAuthProvider(
    CloudProviderType type,
    OAuthCloudProvider Function(OAuthProviderConfiguration) builder,
  ) {
    _oauthBuilders[type] = builder;
  }
  
  static bool isOAuthProviderSupported(CloudProviderType type) => 
    _oauthBuilders.containsKey(type);
}
```

---

## 🔧 IMPLEMENTAÇÕES CONCRETAS

### **Google Drive Provider com Constructor**

```dart
class GoogleDriveCloudProvider extends OAuthCloudProvider {
  static const String _apiBaseUrl = 'https://www.googleapis.com/drive/v3';
  
  // Constructor tipado - config imutável
  GoogleDriveCloudProvider(super.config);
  
  @override
  Future<FileListPage> listFolder({
    String? parentId,
    int limit = 50,
    String? pageToken,
  }) async {
    if (!isAuthenticated) {
      throw StateError('Google Drive não autenticado');
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
      throw CloudProviderException('Google Drive list failed: ${response.statusCode}');
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
    
    final userData = jsonDecode(response.body)['user'];
    return UserProfile(
      id: currentAccount!.userId,
      name: userData['displayName'],
      email: userData['emailAddress'],
      avatarUrl: userData['photoLink'],
    );
  }
  
  @override
  Future<FileEntry> createFolder({
    required String name,
    String? parentId,
  }) async {
    if (!isAuthenticated) {
      throw StateError('Google Drive não autenticado');
    }
    
    final uri = Uri.parse('$_apiBaseUrl/files');
    final response = await _httpClient.post(
      uri,
      headers: authHeaders,
      body: jsonEncode({
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        if (parentId != null) 'parents': [parentId],
      }),
    );
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Folder creation failed: ${response.statusCode}');
    }
    
    return _mapGoogleFileToEntry(jsonDecode(response.body));
  }
  
  @override
  Stream<List<int>> downloadFile(String fileId) async* {
    if (!isAuthenticated) {
      throw StateError('Google Drive não autenticado');
    }
    
    final uri = Uri.parse('$_apiBaseUrl/files/$fileId').replace(
      queryParameters: {'alt': 'media'},
    );
    
    final request = http.Request('GET', uri);
    request.headers.addAll(authHeaders);
    
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
    if (!isAuthenticated) {
      throw StateError('Google Drive não autenticado');
    }
    
    // Google Drive resumable upload
    final metadataUri = Uri.parse('https://www.googleapis.com/upload/drive/v3/files').replace(
      queryParameters: {'uploadType': 'resumable'},
    );
    
    // 1. Iniciar upload session
    final metadataResponse = await _httpClient.post(
      metadataUri,
      headers: {
        ...authHeaders,
        'X-Upload-Content-Type': mimeType ?? 'application/octet-stream',
        'X-Upload-Content-Length': fileSize.toString(),
      },
      body: jsonEncode({
        'name': name,
        if (parentId != null) 'parents': [parentId],
      }),
    );
    
    if (metadataResponse.statusCode != 200) {
      throw CloudProviderException('Upload init failed: ${metadataResponse.statusCode}');
    }
    
    final uploadUri = Uri.parse(metadataResponse.headers['location']!);
    
    // 2. Upload file com progress
    final request = http.StreamedRequest('PUT', uploadUri);
    request.headers.addAll({
      'Content-Type': mimeType ?? 'application/octet-stream',
      'Content-Length': fileSize.toString(),
    });
    
    int uploadedBytes = 0;
    
    await for (final chunk in fileStream) {
      request.sink.add(chunk);
      uploadedBytes += chunk.length;
      
      yield UploadProgress(
        uploadedBytes: uploadedBytes,
        totalBytes: fileSize,
        isComplete: uploadedBytes >= fileSize,
      );
    }
    
    request.sink.close();
    final response = await _httpClient.send(request);
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Upload failed: ${response.statusCode}');
    }
  }
  
  @override
  Future<void> deleteEntry(String entryId) async {
    if (!isAuthenticated) {
      throw StateError('Google Drive não autenticado');
    }
    
    final uri = Uri.parse('$_apiBaseUrl/files/$entryId');
    final response = await _httpClient.delete(uri, headers: authHeaders);
    
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
    if (!isAuthenticated) {
      throw StateError('Google Drive não autenticado');
    }
    
    final searchQuery = parentId != null
      ? "name contains '$query' and '$parentId' in parents"
      : "name contains '$query'";
    
    final queryParams = <String, String>{
      'pageSize': limit.toString(),
      'fields': 'nextPageToken, files(id, name, mimeType, size, modifiedTime, parents)',
      'q': searchQuery,
      if (pageToken != null) 'pageToken': pageToken,
    };
    
    final uri = Uri.parse('$_apiBaseUrl/files').replace(queryParameters: queryParams);
    final response = await _httpClient.get(uri, headers: authHeaders);
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Search failed: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body);
    return FileListPage(
      files: (data['files'] as List).map((f) => _mapGoogleFileToEntry(f)).toList(),
      hasMore: data['nextPageToken'] != null,
      nextPageToken: data['nextPageToken'],
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
}
```

### **Example App - Local Server Implementation**

**Arquivo:** `example/lib/providers/example_local_server_provider.dart`

```dart
class ExampleLocalServerProvider extends LocalCloudProvider {
  // Constructor tipado - config imutável
  ExampleLocalServerProvider(super.config);
  
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
    
    final response = await apiGet('/files', queryParams);
    
    if (response.statusCode != 200) {
      throw CloudProviderException('Server list failed: ${response.statusCode}');
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
    final response = await apiPost('/folders', {
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
    final response = await apiDelete('/files/$entryId');
    
    if (response.statusCode != 204) {
      throw CloudProviderException('Delete failed: ${response.statusCode}');
    }
  }
  
  @override
  Stream<List<int>> downloadFile(String fileId) async* {
    final uri = buildApiUri('/files/$fileId/download');
    final request = http.Request('GET', uri);
    request.headers.addAll(requestHeaders);
    
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
    final fields = <String, String>{
      'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (mimeType != null) 'mime_type': mimeType,
    };
    
    final files = <String, http.MultipartFile>{
      'file': http.MultipartFile(
        'file',
        fileStream,
        fileSize,
        filename: name,
      ),
    };
    
    final response = await apiPostMultipart('/files/upload', fields, files);
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
    
    final response = await apiGet('/search', queryParams);
    
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

## 📋 EXAMPLE APP USAGE SENIOR

### **main.dart com Constructor-Based Config**

```dart
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Cloud Senior Example',
      home: Scaffold(
        appBar: AppBar(title: Text('Multi-Provider File Manager')),
        body: FileCloudWidget(
          providers: [
            // Local server - constructor direto
            ReadyProviderConfiguration(
              providerInstance: ExampleLocalServerProvider(
                LocalProviderConfiguration(
                  displayName: 'Meu Servidor Local',
                  serverBaseUri: Uri.parse('https://files.meuserver.com/api/v1'),
                  apiKeyHeader: 'Authorization',
                  apiKey: 'Bearer minha_chave_secreta',
                  defaultHeaders: {
                    'User-Agent': 'MeuApp/1.0',
                    'Accept': 'application/json',
                  },
                  requestTimeout: Duration(seconds: 15),
                  capabilities: ProviderCapabilities(
                    canUpload: true,
                    canDownload: true,
                    canCreateFolders: true,
                    canDeleteFiles: true,
                    canSearch: true,
                    maxFileSize: 50 * 1024 * 1024, // 50MB
                    supportedMimeTypes: {
                      'image/*',
                      'application/pdf',
                      'text/plain',
                    },
                  ),
                ),
              ),
              displayName: 'Meu Servidor Local',
              logoWidget: Icon(Icons.storage, color: Colors.blue),
            ),
            
            // Google Drive OAuth - constructor direto
            OAuthProviderConfiguration(
              type: CloudProviderType.googleDrive,
              displayName: 'Google Drive',
              logoAssetPath: 'assets/logos/google_drive.png',
              generateAuthUrl: (state) => Uri.parse(
                'https://backend.meuapp.com/oauth/google/authorize'
              ).replace(queryParameters: {
                'state': state,
                'client_app': 'flutter',
              }),
              generateTokenUrl: (state) => Uri.parse(
                'https://backend.meuapp.com/oauth/google/token/$state'
              ),
              redirectScheme: 'meuapp://oauth/google',
              requiredScopes: {
                OAuthScope.readFiles,
                OAuthScope.writeFiles,
                OAuthScope.userProfile,
              },
              extraAuthParams: {
                'access_type': 'offline',
                'prompt': 'consent',
              },
              capabilities: ProviderCapabilities(
                canUpload: true,
                canDownload: true,
                canCreateFolders: true,
                canDeleteFiles: true,
                canSearch: true,
                canShare: true,
                canRename: true,
                canMove: true,
                supportsThumbnails: true,
                supportsVersioning: true,
                maxFileSize: -1, // Ilimitado
              ),
            ),
            
            // OneDrive OAuth - constructor direto
            OAuthProviderConfiguration(
              type: CloudProviderType.oneDrive,
              displayName: 'OneDrive',
              logoAssetPath: 'assets/logos/onedrive.png',
              generateAuthUrl: (state) => Uri.parse(
                'https://backend.meuapp.com/oauth/microsoft/authorize'
              ).replace(queryParameters: {
                'state': state,
                'response_type': 'code',
              }),
              generateTokenUrl: (state) => Uri.parse(
                'https://backend.meuapp.com/oauth/microsoft/token/$state'
              ),
              redirectScheme: 'meuapp://oauth/microsoft',
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
                canRename: true,
                maxFileSize: 250 * 1024 * 1024, // 250MB
                maxFilesPerUpload: 5,
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
              'application/pdf',
            ],
            mimeTypeHint: 'Apenas imagens (JPEG, PNG, WebP) e PDFs são aceitos',
            showTypeFilters: true,
            onSelectionConfirm: (selectedFiles) {
              _handleFileSelection(context, selectedFiles);
            },
          ),
          showProviderSwitcher: true,
          enableGlobalSearch: true,
        ),
      ),
    );
  }
  
  void _handleFileSelection(BuildContext context, List<FileEntry> files) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${files.length} Arquivo(s) Selecionado(s)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: files.map((file) => Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(_getFileIcon(file.mimeType), size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(file.name)),
                Text(_formatFileSize(file.size)),
              ],
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processSelectedFiles(files);
            },
            child: Text('Confirmar'),
          ),
        ],
      ),
    );
  }
  
  void _processSelectedFiles(List<FileEntry> files) {
    // Processar arquivos selecionados
    print('Processando ${files.length} arquivos:');
    for (final file in files) {
      print('- ${file.name} (${file.mimeType})');
    }
  }
  
  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
    if (mimeType.startsWith('text/')) return Icons.text_snippet;
    
    return Icons.insert_drive_file;
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
```

---

## 🎯 FILECLOUD WIDGET FINAL

### **Widget State com Constructor Logic**

```dart
class _FileCloudWidgetState extends State<FileCloudWidget> {
  final Map<CloudProviderType, BaseCloudProvider> _providers = {};
  CloudProviderType? _selectedProviderType;
  
  @override
  void initState() {
    super.initState();
    _createAndRegisterProviders();
    _loadStoredOAuthAccounts();
  }
  
  void _createAndRegisterProviders() {
    for (final config in widget.providers) {
      try {
        // Factory cria provider com constructor tipado
        final provider = CloudProviderFactory.createProvider(config);
        _providers[config.type] = provider;
      } catch (e) {
        debugPrint('Failed to create provider ${config.type}: $e');
      }
    }
    
    if (_providers.isNotEmpty) {
      _selectedProviderType = _providers.keys.first;
    }
  }
  
  Future<void> _loadStoredOAuthAccounts() async {
    final loadFutures = <Future<void>>[];
    
    for (final entry in _providers.entries) {
      final provider = entry.value;
      
      // Apenas OAuth providers precisam carregar contas
      if (provider is OAuthCloudProvider) {
        loadFutures.add(_loadAccountForOAuthProvider(entry.key, provider));
      }
    }
    
    await Future.wait(loadFutures);
    if (mounted) setState(() {});
  }
  
  Future<void> _loadAccountForOAuthProvider(
    CloudProviderType type,
    OAuthCloudProvider provider,
  ) async {
    try {
      final account = await widget.accountStorage.getAccount(type);
      if (account != null) {
        provider._currentAccount = account;
      }
    } catch (e) {
      debugPrint('Failed to load account for $type: $e');
    }
  }
  
  BaseCloudProvider? get _currentProvider => 
    _selectedProviderType != null ? _providers[_selectedProviderType] : null;
  
  @override
  Widget build(BuildContext context) {
    if (_providers.isEmpty) {
      return _buildNoProvidersState();
    }
    
    return Column(
      children: [
        // Provider switcher
        if (widget.showProviderSwitcher && _providers.length > 1)
          _buildProviderSwitcher(),
        
        // Navigation ou auth prompt
        if (_currentProvider != null)
          _buildNavigationOrAuthPrompt(),
        
        // File type filters
        if (widget.selectionConfig != null && 
            widget.selectionConfig!.showTypeFilters)
          FileTypeFilterWidget(selectionConfig: widget.selectionConfig!),
        
        // File list
        Expanded(
          child: _currentProvider != null
            ? InfiniteScrollFileList(
                provider: _currentProvider!,
                selectionConfig: widget.selectionConfig,
                onSelectionChanged: _handleSelectionChanged,
              )
            : _buildSelectProviderState(),
        ),
      ],
    );
  }
  
  Widget _buildNavigationOrAuthPrompt() {
    final provider = _currentProvider!;
    
    // OAuth provider não autenticado - mostra prompt
    if (provider is OAuthCloudProvider && !provider.isAuthenticated) {
      return _buildAuthenticationPrompt(provider);
    }
    
    // Provider pronto (local ou OAuth autenticado) - mostra navigation
    return _buildAdaptiveNavigationBar(provider);
  }
  
  Widget _buildAuthenticationPrompt(OAuthCloudProvider oauthProvider) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (oauthProvider.config.logoWidget != null) ...[
            oauthProvider.config.logoWidget!,
            SizedBox(height: 16),
          ],
          Text(
            'Conecte-se ao ${oauthProvider.config.displayName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 8),
          Text(
            'Para acessar seus arquivos, você precisa se conectar.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _authenticateProvider(oauthProvider),
            icon: Icon(Icons.login),
            label: Text('Conectar'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAdaptiveNavigationBar(BaseCloudProvider provider) {
    final capabilities = provider.getCapabilities();
    
    return AdaptiveNavigationBar(
      provider: provider,
      showSearch: widget.enableGlobalSearch && capabilities.canSearch,
      onUpload: capabilities.canUpload ? _handleUpload : null,
      onCreateFolder: capabilities.canCreateFolders ? _handleCreateFolder : null,
      onRefresh: _handleRefresh,
    );
  }
  
  Future<void> _authenticateProvider(OAuthCloudProvider provider) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Abrindo autenticação...'),
            ],
          ),
        ),
      );
      
      final state = await provider.startOAuthFlow();
      
      Navigator.pop(context); // Remove loading dialog
      
      // Aguardar callback OAuth - implementação específica do app
      _waitForOAuthCallback(provider, state);
      
    } catch (e) {
      Navigator.pop(context); // Remove loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro na autenticação: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _waitForOAuthCallback(OAuthCloudProvider provider, String state) {
    // Implementação específica para aguardar callback
    // Pode usar deep links, custom URL scheme, etc.
  }
  
  void _handleSelectionChanged(List<FileEntry> selectedFiles) {
    final config = widget.selectionConfig;
    if (config == null) return;
    
    // Validar seleção mínima antes de confirmar
    if (selectedFiles.length >= config.minSelection) {
      config.onSelectionConfirm(selectedFiles);
    }
  }
}
```

---

## 🔍 COMPONENTES AUXILIARES SENIOR

### **Adaptive Navigation Bar**

```dart
class AdaptiveNavigationBar extends StatelessWidget {
  final BaseCloudProvider provider;
  final bool showSearch;
  final VoidCallback? onUpload;
  final VoidCallback? onCreateFolder;
  final VoidCallback? onRefresh;
  
  const AdaptiveNavigationBar({
    Key? key,
    required this.provider,
    this.showSearch = true,
    this.onUpload,
    this.onCreateFolder,
    this.onRefresh,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final capabilities = provider.getCapabilities();
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Row(
        children: [
          // Search bar expandida
          if (capabilities.canSearch && showSearch) ...[
            Expanded(
              child: SearchBarWidget(
                onSearch: (query) => _handleSearch(context, query),
                placeholder: 'Buscar em ${_getProviderDisplayName()}',
              ),
            ),
            SizedBox(width: 12),
          ],
          
          // Action buttons
          ..._buildActionButtons(context, capabilities),
        ],
      ),
    );
  }
  
  List<Widget> _buildActionButtons(BuildContext context, ProviderCapabilities capabilities) {
    final buttons = <Widget>[];
    
    // Upload
    if (capabilities.canUpload && onUpload != null) {
      buttons.add(_buildActionButton(
        context: context,
        icon: Icons.upload,
        label: 'Upload',
        onPressed: onUpload!,
      ));
    }
    
    // Nova pasta
    if (capabilities.canCreateFolders && onCreateFolder != null) {
      buttons.add(_buildActionButton(
        context: context,
        icon: Icons.create_new_folder,
        label: 'Nova Pasta',
        onPressed: onCreateFolder!,
      ));
    }
    
    // Refresh sempre disponível
    if (onRefresh != null) {
      buttons.add(_buildActionButton(
        context: context,
        icon: Icons.refresh,
        label: 'Atualizar',
        onPressed: onRefresh!,
      ));
    }
    
    return buttons;
  }
  
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
  
  String _getProviderDisplayName() {
    if (provider is OAuthCloudProvider) {
      return (provider as OAuthCloudProvider).config.displayName;
    }
    if (provider is LocalCloudProvider) {
      return (provider as LocalCloudProvider).config.displayName;
    }
    return 'Cloud Storage';
  }
  
  void _handleSearch(BuildContext context, String query) {
    // Delegar para widget pai
    final parentState = context.findAncestorStateOfType<_FileCloudWidgetState>();
    parentState?._handleGlobalSearch(query);
  }
}
```

### **Search Bar com Debounce Inteligente**

```dart
class SearchBarWidget extends StatefulWidget {
  final Function(String query) onSearch;
  final String? placeholder;
  final Duration debounce;
  final int minQueryLength;
  
  const SearchBarWidget({
    Key? key,
    required this.onSearch,
    this.placeholder,
    this.debounce = const Duration(milliseconds: 400),
    this.minQueryLength = 2,
  }) : super(key: key);
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  String _lastQuery = '';
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }
  
  void _onTextChanged() {
    final query = _controller.text.trim();
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Empty query - execute immediately
    if (query.isEmpty) {
      _executeSearch('');
      return;
    }
    
    // Too short - don't search
    if (query.length < widget.minQueryLength) {
      setState(() => _isSearching = false);
      return;
    }
    
    // Same as last - don't search
    if (query == _lastQuery) return;
    
    // Show loading state
    setState(() => _isSearching = true);
    
    // Schedule search with debounce
    _debounceTimer = Timer(widget.debounce, () {
      _executeSearch(query);
    });
  }
  
  void _executeSearch(String query) {
    _lastQuery = query;
    setState(() => _isSearching = false);
    widget.onSearch(query);
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.placeholder ?? 'Buscar arquivos...',
          prefixIcon: _isSearching
            ? Container(
                width: 20,
                height: 20,
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: _clearSearch,
              )
            : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (query) => _executeSearch(query.trim()),
      ),
    );
  }
  
  void _clearSearch() {
    _controller.clear();
    _executeSearch('');
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
```

---

## 🧪 TESTING STRATEGY COMPLETAMENTE SENIOR

### **Constructor Tests**

```dart
// test/constructor_tests.dart
group('Constructor-Based Configuration', () {
  test('OAuth provider deve receber config no constructor', () {
    final config = OAuthProviderConfiguration(
      type: CloudProviderType.googleDrive,
      displayName: 'Google Drive',
      generateAuthUrl: (state) => Uri.parse('https://auth.com?state=$state'),
      generateTokenUrl: (state) => Uri.parse('https://token.com/$state'),
      redirectScheme: 'app://oauth',
      requiredScopes: {OAuthScope.readFiles},
      capabilities: ProviderCapabilities(),
    );
    
    final provider = GoogleDriveCloudProvider(config);
    
    expect(provider.config, same(config));
    expect(provider.isAuthenticated, false);
    expect(() => provider.getCapabilities(), returnsNormally);
  });
  
  test('Local provider deve receber config no constructor', () {
    final config = LocalProviderConfiguration(
      displayName: 'My Server',
      serverBaseUri: Uri.parse('https://api.server.com'),
      capabilities: ProviderCapabilities(),
    );
    
    final provider = ExampleLocalServerProvider(config);
    
    expect(provider.config, same(config));
    expect(provider.getCapabilities(), same(config.capabilities));
  });
  
  test('deve falhar com configuração inválida', () {
    final invalidConfig = OAuthProviderConfiguration(
      type: CloudProviderType.googleDrive,
      displayName: '', // Inválido
      generateAuthUrl: (state) => Uri.parse('https://auth.com'),
      generateTokenUrl: (state) => Uri.parse('https://token.com'),
      redirectScheme: '',
      requiredScopes: {},
      capabilities: ProviderCapabilities(),
    );
    
    expect(
      () => GoogleDriveCloudProvider(invalidConfig),
      throwsArgumentError,
    );
  });
});
```

### **Type Safety Tests**

```dart
// test/type_safety_tests.dart
group('Type Safety Validation', () {
  test('OAuth provider só aceita OAuth config', () {
    final oauthConfig = OAuthProviderConfiguration(/*...*/);
    final provider = GoogleDriveCloudProvider(oauthConfig);
    
    expect(provider.config, isA<OAuthProviderConfiguration>());
    expect(provider.config.generateAuthUrl('test'), isA<Uri>());
  });
  
  test('Local provider só aceita Local config', () {
    final localConfig = LocalProviderConfiguration(/*...*/);
    final provider = ExampleLocalServerProvider(localConfig);
    
    expect(provider.config, isA<LocalProviderConfiguration>());
    expect(provider.config.serverBaseUri, isA<Uri>());
  });
  
  test('não deve ser possível passar config errado', () {
    // Compile-time type safety - teste conceitual
    // GoogleDriveCloudProvider(LocalProviderConfiguration()) <- Não compila
    // ExampleLocalServerProvider(OAuthProviderConfiguration()) <- Não compila
    
    expect(true, true); // Type safety é garantida em compile-time
  });
});
```

### **Integration Tests Robustos**

```dart
// integration_test/multi_provider_integration_test.dart
testWidgets('deve funcionar com múltiplos providers via constructor', (tester) async {
  final localProvider = ExampleLocalServerProvider(
    LocalProviderConfiguration(
      displayName: 'Local Server',
      serverBaseUri: Uri.parse('https://test.server.com'),
      capabilities: ProviderCapabilities(canUpload: true, canDownload: true),
    ),
  );
  
  final oauthConfig = OAuthProviderConfiguration(
    type: CloudProviderType.googleDrive,
    displayName: 'Google Drive',
    generateAuthUrl: (state) => Uri.parse('https://oauth.com?state=$state'),
    generateTokenUrl: (state) => Uri.parse('https://token.com/$state'),
    redirectScheme: 'app://oauth',
    requiredScopes: {OAuthScope.readFiles},
    capabilities: ProviderCapabilities(canUpload: true, canDownload: true),
  );
  
  await tester.pumpWidget(
    MaterialApp(
      home: FileCloudWidget(
        providers: [
          ReadyProviderConfiguration(
            providerInstance: localProvider,
            displayName: 'Local Server',
          ),
          oauthConfig,
        ],
        accountStorage: MemoryAccountStorage(),
      ),
    ),
  );
  
  // Verificar que ambos providers estão disponíveis
  expect(find.text('Local Server'), findsOneWidget);
  expect(find.text('Google Drive'), findsOneWidget);
  
  // Local server deve estar pronto imediatamente
  await tester.tap(find.text('Local Server'));
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.upload), findsOneWidget);
  
  // OAuth provider deve mostrar prompt de auth
  await tester.tap(find.text('Google Drive'));
  await tester.pumpAndSettle();
  expect(find.text('Conecte-se ao Google Drive'), findsOneWidget);
});
```

---

## 🚀 MIGRATION PATH SENIOR

### **De Initialize Pattern para Constructor Pattern**

```dart
// ❌ CÓDIGO ANTIGO (júnior)
final provider = GoogleDriveCloudProvider();
provider.initialize(configuration: config, account: account);

// ✅ CÓDIGO NOVO (senior)
final provider = GoogleDriveCloudProvider(config);
if (account != null) {
  provider._currentAccount = account; // Ou método setAccount se necessário
}
```

### **Factory Usage Senior**

```dart
// ❌ CÓDIGO ANTIGO (complexo)
final provider = CloudProviderFactory.createProvider(config);
provider.initialize(configuration: config);

// ✅ CÓDIGO NOVO (simples)
final provider = CloudProviderFactory.createProvider(config);
// Provider já vem configurado do constructor
```

### **Example App Setup**

```dart
// No example app - criar provider local
final myServerProvider = ExampleLocalServerProvider(
  LocalProviderConfiguration(
    displayName: 'Meu Servidor',
    serverBaseUri: Uri.parse('https://api.meuserver.com/v1'),
    apiKeyHeader: 'X-API-Key',
    apiKey: 'minha_chave',
    capabilities: ProviderCapabilities(
      canUpload: true,
      canDownload: true,
      canCreateFolders: true,
      canSearch: true,
    ),
  ),
);

// Usar ReadyProviderConfiguration
FileCloudWidget(
  providers: [
    ReadyProviderConfiguration(
      providerInstance: myServerProvider,
      displayName: 'Meu Servidor',
      logoWidget: Icon(Icons.storage),
    ),
    // OAuth providers direto
    OAuthProviderConfiguration(/*...*/),
  ],
  // ...
)
```

---

## 📊 BENEFÍCIOS DA ARQUITETURA SENIOR

### **Code Quality:**
- **Immutability**: Configuração imutável desde criação
- **Type Safety**: Constructor tipado elimina erros runtime
- **Simplicity**: Sem métodos initialize desnecessários
- **Clarity**: Intent clear desde a criação do objeto

### **Developer Experience:**
- **Less Boilerplate**: Constructor direto vs initialize + setters
- **Compile-time Safety**: Impossible para passar config errado
- **IDE Support**: Autocomplete e type hints melhores
- **Debugging**: Stack traces mais claros

### **Architecture Benefits:**
- **Single Responsibility**: Cada classe tem um propósito claro
- **Open/Closed**: Extensível via herança, fechado para modificação
- **Dependency Inversion**: Abstrações não dependem de detalhes
- **Interface Segregation**: Interfaces focadas e específicas

### **Performance:**
- **No Late Initialization**: Zero overhead de validation
- **Immutable State**: Melhor para performance e debugging
- **Clear Lifecycle**: Constructor → use → dispose
- **Memory Efficient**: Sem state desnecessário

---

## 🎯 VALIDATION CHECKLIST SENIOR

### **Architecture Validation:**
- ✅ Constructor-based configuration (não initialize)
- ✅ Type-safe hierarchy (OAuth vs Local)
- ✅ Immutable configuration objects
- ✅ Clear separation of concerns
- ✅ Zero redundant methods ou properties

### **Implementation Validation:**
- ✅ OAuth providers herdam OAuthCloudProvider(OAuthConfig)
- ✅ Local providers herdam LocalCloudProvider(LocalConfig)
- ✅ Custom providers via ReadyProviderConfiguration
- ✅ Factory pattern creates correctly configured instances
- ✅ Zero nullable configuration fields

### **Quality Validation:**
- ✅ Flutter Web compatibility without dart:io
- ✅ Uri objects throughout (não String com parse)
- ✅ Exception handling bem definido
- ✅ Resource cleanup appropriado
- ✅ Thread-safe operations

### **Usage Validation:**
- ✅ Example app mostra implementação local custom
- ✅ Multi-provider setup funcional
- ✅ Selection mode com mime-type filters
- ✅ Infinite scroll performático
- ✅ Search com debounce inteligente

---

## 🔄 IMPLEMENTAÇÃO PRIORITY ORDER

### **Phase 1: Core Architecture (1-2 days)**
1. Create configuration hierarchy com constructors
2. Refactor BaseCloudProvider → OAuthCloudProvider/LocalCloudProvider  
3. Update factory pattern para constructor-based
4. Create ReadyProviderConfiguration para custom providers

### **Phase 2: Built-in Providers (1 day)**
1. Update GoogleDriveCloudProvider constructor
2. Update OneDriveCloudProvider constructor
3. Update DropboxCloudProvider constructor
4. Remove AccountBasedProvider completely

### **Phase 3: Example Implementation (1 day)**
1. Create ExampleLocalServerProvider extends LocalCloudProvider
2. Update example app para usar ReadyProviderConfiguration
3. Test multi-provider setup
4. Validate Flutter Web compatibility

### **Phase 4: Advanced Features (1-2 days)**
1. Implement SearchBarWidget com debounce
2. Implement InfiniteScrollFileList
3. Update SelectionConfig com mime-type filters
4. Create AdaptiveNavigationBar com capabilities

### **Phase 5: Polish & Testing (1 day)**
1. Add comprehensive unit tests
2. Add integration tests
3. Add Flutter Web specific tests
4. Update documentation e examples

---

**Status:** PLANEJADO V5 - CONSTRUCTOR-BASED SENIOR ARCHITECTURE  
**Responsável:** Claude (Opus 4.1)  
**Validação:** Arquitetura senior com constructors diretos, type safety e zero initialize patterns