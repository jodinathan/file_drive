# File Drive - Etapa 2: Operações de Arquivo e Funcionalidades Avançadas

## Objetivo da Etapa 2
Implementar todas as operações de arquivo sobre a base de autenticação criada na Etapa 1. Ao final desta etapa, o usuário deve conseguir:
- Navegar por pastas do Google Drive
- Visualizar arquivos com thumbnails
- Fazer upload de arquivos com barra de progresso
- Baixar arquivos selecionados
- Deletar arquivos e pastas
- Selecionar múltiplos arquivos
- Arrastar e soltar arquivos para upload
- Todo código precisa ser genérico para funcionar com outros provedores além do Google Drive. Também vamos implementar provedores customizados.

## Pré-requisitos da Etapa 2
- ✅ Etapa 1 completamente funcional
- ✅ Autenticação OAuth funcionando
- ✅ Token válido sendo obtido
- ✅ Interface base implementada

## Escopo Específico da Etapa 2

### ✅ O que SERÁ implementado:
- Navegação completa por diretórios
- Listagem de arquivos e pastas
- Upload de arquivos com stream de progresso
- Download de arquivos
- Operações CRUD (Create, Read, Update, Delete)
- Seleção múltipla de arquivos
- Drag & Drop para upload
- Thumbnails e preview de arquivos
- Filtros e busca
- Validação de arquivos

### ❌ O que NÃO será implementado (futuras expansões):
- Sincronização offline
- Versionamento de arquivos
- Compartilhamento de arquivos
- Comentários em arquivos
- Integração com outros provedores
- Cache avançado

## Extensão da Arquitetura (Etapa 2)

### 1. CloudProvider Completo
```dart
abstract class CloudProvider {
  // Autenticação (já implementado na Etapa 1)
  Future<bool> authenticate();
  Future<void> logout();
  bool get isAuthenticated;
  
  // Operações de arquivo (NOVO na Etapa 2)
  Future<List<CloudItem>> listItems(String? folderId);
  Future<CloudFolder> createFolder(String name, String? parentId);
  Stream<UploadProgress> uploadFile(FileUpload fileUpload);
  Future<Uint8List> downloadFile(String fileId);
  Future<void> deleteItem(String itemId);
  Future<void> moveItem(String itemId, String newParentId);
  Future<void> renameItem(String itemId, String newName);
  
  // Busca e filtros
  Future<List<CloudItem>> searchItems(SearchQuery query);
  Future<CloudItem?> getItemById(String itemId);
  
  // Metadados
  String get providerName;
  String get providerIcon;
  Color get providerColor;
  ProviderStatus get status;
}
```

### 2. Novos Modelos de Dados

#### 2.1 CloudItem (Base para arquivos e pastas)
```dart
abstract class CloudItem {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final CloudItemType type;
  final Map<String, dynamic> metadata;
  
  CloudItem({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    required this.modifiedAt,
    required this.type,
    this.metadata = const {},
  });
}

enum CloudItemType { file, folder }
```

#### 2.2 CloudFile (Específico para arquivos)
```dart
class CloudFile extends CloudItem {
  final int size;
  final String mimeType;
  final String? thumbnailUrl;
  final String? downloadUrl;
  final bool isShared;
  final FilePermissions permissions;
  
  CloudFile({
    required String id,
    required String name,
    String? parentId,
    required DateTime createdAt,
    required DateTime modifiedAt,
    required this.size,
    required this.mimeType,
    this.thumbnailUrl,
    this.downloadUrl,
    this.isShared = false,
    this.permissions = const FilePermissions(),
    Map<String, dynamic> metadata = const {},
  }) : super(
    id: id,
    name: name,
    parentId: parentId,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    type: CloudItemType.file,
    metadata: metadata,
  );
  
  String get formattedSize => _formatFileSize(size);
  String get fileExtension => name.split('.').last.toLowerCase();
  bool get hasPreview => _supportedPreviewTypes.contains(mimeType);
}
```

#### 2.3 CloudFolder (Específico para pastas)
```dart
class CloudFolder extends CloudItem {
  final int itemCount;
  final bool isEmpty;
  final FolderPermissions permissions;
  
  CloudFolder({
    required String id,
    required String name,
    String? parentId,
    required DateTime createdAt,
    required DateTime modifiedAt,
    this.itemCount = 0,
    this.permissions = const FolderPermissions(),
    Map<String, dynamic> metadata = const {},
  }) : isEmpty = itemCount == 0,
       super(
    id: id,
    name: name,
    parentId: parentId,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    type: CloudItemType.folder,
    metadata: metadata,
  );
}
```

#### 2.4 Upload e Download Types
```dart
class FileUpload {
  final File file;
  final String fileName;
  final String? parentFolderId;
  final Map<String, String> metadata;
  final bool overwriteExisting;
  
  FileUpload({
    required this.file,
    required this.fileName,
    this.parentFolderId,
    this.metadata = const {},
    this.overwriteExisting = false,
  });
}

class UploadProgress {
  final String uploadId;
  final String fileName;
  final int bytesUploaded;
  final int totalBytes;
  final double percentage;
  final UploadStatus status;
  final Duration? estimatedTimeRemaining;
  final String? error;
  
  UploadProgress({
    required this.uploadId,
    required this.fileName,
    required this.bytesUploaded,
    required this.totalBytes,
    required this.status,
    this.estimatedTimeRemaining,
    this.error,
  }) : percentage = totalBytes > 0 ? (bytesUploaded / totalBytes) * 100 : 0;
}

enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
  cancelled,
  paused,
}
```

#### 2.5 Busca e Filtros
```dart
class SearchQuery {
  final String query;
  final List<String> fileTypes;
  final DateRange? dateRange;
  final SizeRange? sizeRange;
  final String? folderId;
  final int maxResults;
  final SortOption sortBy;
  
  SearchQuery({
    required this.query,
    this.fileTypes = const [],
    this.dateRange,
    this.sizeRange,
    this.folderId,
    this.maxResults = 50,
    this.sortBy = SortOption.nameAsc,
  });
}

class DateRange {
  final DateTime start;
  final DateTime end;
  
  DateRange({required this.start, required this.end});
}

class SizeRange {
  final int minSize;
  final int maxSize;
  
  SizeRange({required this.minSize, required this.maxSize});
}

enum SortOption {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  sizeAsc,
  sizeDesc,
  typeAsc,
  typeDesc,
}
```

### 3. Interface Completa (Etapa 2)

#### 3.1 File Explorer Principal
```dart
class FileExplorer extends StatefulWidget {
  final CloudProvider provider;
  final Function(List<CloudFile>)? onFilesSelected;
  final FileSelectionConfig selectionConfig;
  final FileValidationConfig validationConfig;
  
  const FileExplorer({
    Key? key,
    required this.provider,
    this.onFilesSelected,
    this.selectionConfig = const FileSelectionConfig(),
    this.validationConfig = const FileValidationConfig(),
  }) : super(key: key);
}

class _FileExplorerState extends State<FileExplorer> {
  String? currentFolderId;
  List<CloudItem> items = [];
  List<CloudItem> selectedItems = [];
  bool isLoading = false;
  String? error;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Breadcrumb navigation
        BreadcrumbNavigation(
          currentPath: _buildCurrentPath(),
          onNavigate: _navigateToFolder,
        ),
        // Toolbar (upload, create folder, etc.)
        FileToolbar(
          onUpload: _showUploadDialog,
          onCreateFolder: _showCreateFolderDialog,
          onDelete: selectedItems.isNotEmpty ? _deleteSelected : null,
          selectedCount: selectedItems.length,
        ),
        // File grid/list
        Expanded(
          child: _buildFileView(),
        ),
        // Upload progress (if any uploads in progress)
        UploadProgressPanel(),
      ],
    );
  }
}
```

#### 3.2 File Grid/List View
```dart
class FileGridView extends StatelessWidget {
  final List<CloudItem> items;
  final List<CloudItem> selectedItems;
  final Function(CloudItem) onItemTap;
  final Function(CloudItem) onItemDoubleTap;
  final Function(CloudItem, bool) onItemSelected;
  
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _calculateCrossAxisCount(context),
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedItems.contains(item);
        
        return FileItemCard(
          item: item,
          isSelected: isSelected,
          onTap: () => onItemTap(item),
          onDoubleTap: () => onItemDoubleTap(item),
          onSelectionChanged: (selected) => onItemSelected(item, selected),
        );
      },
    );
  }
}
```

#### 3.3 File Item Card
```dart
class FileItemCard extends StatelessWidget {
  final CloudItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final Function(bool) onSelectionChanged;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              // Selection checkbox
              Align(
                alignment: Alignment.topRight,
                child: Checkbox(
                  value: isSelected,
                  onChanged: onSelectionChanged,
                ),
              ),
              // Icon/Thumbnail
              Expanded(
                child: _buildItemIcon(),
              ),
              // Name
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              // Metadata
              if (item is CloudFile)
                Text(
                  (item as CloudFile).formattedSize,
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildItemIcon() {
    if (item.type == CloudItemType.folder) {
      return Icon(Icons.folder, size: 48, color: Colors.amber);
    }
    
    final file = item as CloudFile;
    if (file.thumbnailUrl != null) {
      return Image.network(
        file.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFileTypeIcon(file),
      );
    }
    
    return _buildFileTypeIcon(file);
  }
}
```

#### 3.4 Upload Progress Panel
```dart
class UploadProgressPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UploadProgress>>(
      stream: UploadManager.instance.activeUploads,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox.shrink();
        }
        
        return Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  children: [
                    Text('Uploads em Progresso'),
                    Spacer(),
                    TextButton(
                      onPressed: () => UploadManager.instance.cancelAll(),
                      child: Text('Cancelar Todos'),
                    ),
                  ],
                ),
              ),
              // Upload list
              Expanded(
                child: ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final upload = snapshot.data![index];
                    return UploadProgressItem(upload: upload);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

## Implementação por Fases (Etapa 2)

### Semana 1: Navegação e Listagem
1. **Modelos de Dados Completos**
   - Implementar CloudFile e CloudFolder
   - Criar tipos de upload e download
   - Implementar tipos de busca e filtros

2. **Navegação Básica**
   - Implementar listagem de itens
   - Criar breadcrumb navigation
   - Implementar navegação por pastas

3. **Interface de Listagem**
   - Criar FileExplorer widget
   - Implementar grid/list view
   - Adicionar seleção de itens

### Semana 2: Upload e Download
1. **Sistema de Upload**
   - Implementar upload com stream
   - Criar barra de progresso
   - Adicionar drag & drop

2. **Sistema de Download**
   - Implementar download de arquivos
   - Adicionar preview de arquivos
   - Criar thumbnails

3. **Operações CRUD**
   - Implementar delete
   - Adicionar rename
   - Criar pastas

### Semana 3: Funcionalidades Avançadas
1. **Busca e Filtros**
   - Implementar busca por nome
   - Adicionar filtros por tipo
   - Criar filtros por data/tamanho

2. **Validações e Melhorias**
   - Validação de tipos de arquivo
   - Limitação de tamanho
   - Tratamento de erros

3. **Polimento da UI**
   - Melhorar responsividade
   - Adicionar animações
   - Otimizar performance

## Upload Manager (Singleton para gerenciar uploads)

### Upload Manager Implementation
```dart
class UploadManager {
  static final UploadManager _instance = UploadManager._internal();
  static UploadManager get instance => _instance;
  UploadManager._internal();

  final Map<String, StreamController<UploadProgress>> _activeUploads = {};
  final StreamController<List<UploadProgress>> _uploadsController =
      StreamController<List<UploadProgress>>.broadcast();

  Stream<List<UploadProgress>> get activeUploads => _uploadsController.stream;

  String startUpload(FileUpload fileUpload, CloudProvider provider) {
    final uploadId = _generateUploadId();
    final controller = StreamController<UploadProgress>();
    _activeUploads[uploadId] = controller;

    // Start upload process
    _performUpload(uploadId, fileUpload, provider, controller);

    return uploadId;
  }

  void cancelUpload(String uploadId) {
    final controller = _activeUploads[uploadId];
    if (controller != null) {
      controller.add(UploadProgress(
        uploadId: uploadId,
        fileName: '',
        bytesUploaded: 0,
        totalBytes: 0,
        status: UploadStatus.cancelled,
      ));
      _cleanupUpload(uploadId);
    }
  }

  void cancelAll() {
    for (final uploadId in _activeUploads.keys.toList()) {
      cancelUpload(uploadId);
    }
  }
}
```

## Drag & Drop Implementation

### Drag & Drop Zone
```dart
class DropZone extends StatefulWidget {
  final Widget child;
  final Function(List<File>) onFilesDropped;
  final FileValidationConfig validationConfig;

  const DropZone({
    Key? key,
    required this.child,
    required this.onFilesDropped,
    this.validationConfig = const FileValidationConfig(),
  }) : super(key: key);
}

class _DropZoneState extends State<DropZone> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) => setState(() => _isDragOver = true),
      onDragExited: (details) => setState(() => _isDragOver = false),
      onDragDone: (details) {
        setState(() => _isDragOver = false);
        _handleDroppedFiles(details.files);
      },
      child: Container(
        decoration: BoxDecoration(
          border: _isDragOver
              ? Border.all(color: Colors.blue, width: 2)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: widget.child,
      ),
    );
  }

  void _handleDroppedFiles(List<XFile> files) {
    final validFiles = <File>[];

    for (final xFile in files) {
      final file = File(xFile.path);
      if (_validateFile(file)) {
        validFiles.add(file);
      }
    }

    if (validFiles.isNotEmpty) {
      widget.onFilesDropped(validFiles);
    }
  }
}
```

## Critérios de Sucesso da Etapa 2

### ✅ Funcionalidades Obrigatórias:
1. Navegação completa por diretórios
2. Upload de arquivos com progresso
3. Download de arquivos
4. Seleção múltipla funcionando
5. Operações CRUD completas
6. Drag & Drop para upload
7. Busca e filtros básicos
8. Upload Manager funcionando
9. Validação de arquivos

### 🧪 Testes Necessários:
1. Teste de upload/download
2. Teste de navegação
3. Teste de seleção múltipla
4. Teste de operações CRUD
5. Teste de busca e filtros
6. Teste de validações
7. Teste de performance
8. Teste de drag & drop
9. Teste de upload manager

### 📋 Entregáveis:
1. Widget completo e funcional
2. Documentação de API
3. Exemplos de uso avançado
4. Testes completos
5. Guia de contribuição para novos provedores
6. Upload Manager implementado
7. Sistema de drag & drop funcional

## Estrutura de Arquivos Final (Etapa 2)
```
lib/
├── src/
│   ├── providers/
│   │   ├── base/
│   │   │   ├── cloud_provider.dart
│   │   │   └── oauth_cloud_provider.dart
│   │   └── google_drive/
│   │       └── google_drive_provider.dart
│   ├── models/
│   │   ├── cloud_item.dart
│   │   ├── cloud_file.dart
│   │   ├── cloud_folder.dart
│   │   ├── upload_progress.dart
│   │   ├── search_query.dart
│   │   ├── oauth_types.dart
│   │   ├── file_drive_config.dart
│   │   └── theme_types.dart
│   ├── widgets/
│   │   ├── file_drive_widget.dart
│   │   ├── provider_sidebar.dart
│   │   ├── provider_content.dart
│   │   ├── file_explorer.dart
│   │   ├── file_grid_view.dart
│   │   ├── file_item_card.dart
│   │   ├── upload_progress_panel.dart
│   │   ├── breadcrumb_navigation.dart
│   │   ├── file_toolbar.dart
│   │   ├── drop_zone.dart
│   │   └── auth_screen.dart
│   ├── services/
│   │   ├── upload_manager.dart
│   │   ├── file_service.dart
│   │   └── auth_service.dart
│   └── utils/
│       ├── constants.dart
│       ├── extensions.dart
│       ├── file_utils.dart
│       └── helpers.dart
└── file_drive.dart
```
