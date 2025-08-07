/// File Explorer widget for cloud storage navigation
library;

import 'package:flutter/material.dart';
import '../models/cloud_item.dart';
import '../models/cloud_file.dart';
import '../models/cloud_folder.dart';
import '../models/file_operations.dart';
import '../models/search_models.dart';
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';
import 'breadcrumb_navigation.dart';
import 'file_toolbar.dart';
import 'file_grid_view.dart';
import 'upload_progress_panel.dart';

/// Configuration for file selection behavior
class FileSelectionConfig {
  final bool allowMultipleSelection;
  final bool allowFolderSelection;
  final List<String> allowedFileTypes;
  final int maxSelectionCount;
  
  const FileSelectionConfig({
    this.allowMultipleSelection = true,
    this.allowFolderSelection = false,
    this.allowedFileTypes = const [],
    this.maxSelectionCount = 100,
  });
}

/// Configuration for file validation
class FileValidationConfig {
  final int maxFileSize;
  final List<String> allowedExtensions;
  final List<String> blockedExtensions;
  final bool requireExtension;
  
  const FileValidationConfig({
    this.maxFileSize = 100 * 1024 * 1024, // 100MB
    this.allowedExtensions = const [],
    this.blockedExtensions = const [],
    this.requireExtension = false,
  });
}

/// Main file explorer widget
class FileExplorer extends StatefulWidget {
  final CloudProvider provider;
  final Function(List<CloudFile>)? onFilesSelected;
  final FileSelectionConfig selectionConfig;
  final FileValidationConfig validationConfig;
  final FileDriveTheme? theme;
  
  const FileExplorer({
    Key? key,
    required this.provider,
    this.onFilesSelected,
    this.selectionConfig = const FileSelectionConfig(),
    this.validationConfig = const FileValidationConfig(),
    this.theme,
  }) : super(key: key);
  
  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  String? _currentFolderId;
  List<CloudItem> _items = [];
  List<CloudItem> _selectedItems = [];
  List<CloudFolder> _folderPath = [];
  bool _isLoading = false;
  String? _error;
  ViewMode _viewMode = ViewMode.grid;
  SortOption _sortOption = SortOption.nameAsc;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadItems();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? FileDriveTheme.light();
    
    return Material(
      color: theme.colorScheme.background,
      child: Column(
        children: [
          // Breadcrumb navigation
          BreadcrumbNavigation(
            currentPath: _folderPath,
            onNavigate: _navigateToFolder,
            theme: theme,
          ),
          
          // Toolbar
          FileToolbar(
            onUpload: widget.provider.capabilities.supportsUpload ? _showUploadDialog : null,
            onCreateFolder: widget.provider.capabilities.supportsCreateFolder ? _showCreateFolderDialog : null,
            onDelete: _selectedItems.isNotEmpty && widget.provider.capabilities.supportsDelete ? _deleteSelected : null,
            onSearch: widget.provider.capabilities.supportsSearch ? _onSearchChanged : null,
            selectedCount: _selectedItems.length,
            viewMode: _viewMode,
            onViewModeChanged: _onViewModeChanged,
            sortOption: _sortOption,
            onSortChanged: _onSortChanged,
            theme: theme,
          ),
          
          // File content area
          Expanded(
            child: _buildContent(theme),
          ),
          
          // Upload progress panel
          UploadProgressPanel(
            uploads: const [], // TODO: Implement upload tracking
            onCancelUpload: (id) {
              // TODO: Implement upload cancellation
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent(FileDriveTheme theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Carregando arquivos...',
              style: theme.typography.body.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar arquivos',
              style: theme.typography.title.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.typography.body.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadItems,
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }
    
    if (_items.isEmpty) {
      return _buildEmptyState(theme);
    }
    
    return FileGridView(
      files: _items.whereType<CloudFile>().toList(),
      onFileSelected: (file) => _onItemTap(file),
      onFileLongPressed: (file) => _onItemSelected(file, true),
      selectedFiles: _selectedItems.map((item) => item.id).toSet(),
    );
  }
  
  Widget _buildEmptyState(FileDriveTheme theme) {
    final isRootFolder = _currentFolderId == null;
    final hasSearchQuery = _searchQuery.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearchQuery ? Icons.search_off : Icons.folder_open,
            size: 80,
            color: theme.colorScheme.onBackground.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            hasSearchQuery 
                ? 'Nenhum resultado encontrado'
                : isRootFolder 
                    ? 'Sua pasta está vazia'
                    : 'Esta pasta está vazia',
            style: theme.typography.title.copyWith(
              color: theme.colorScheme.onBackground.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearchQuery
                ? 'Tente usar termos de busca diferentes'
                : 'Faça upload de arquivos ou crie uma nova pasta',
            textAlign: TextAlign.center,
            style: theme.typography.body.copyWith(
              color: theme.colorScheme.onBackground.withOpacity(0.5),
            ),
          ),
          if (!hasSearchQuery) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.provider.capabilities.supportsUpload)
                  ElevatedButton.icon(
                    onPressed: _showUploadDialog,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload de Arquivos'),
                  ),
                if (widget.provider.capabilities.supportsUpload && 
                    widget.provider.capabilities.supportsCreateFolder)
                  const SizedBox(width: 16),
                if (widget.provider.capabilities.supportsCreateFolder)
                  OutlinedButton.icon(
                    onPressed: _showCreateFolderDialog,
                    icon: const Icon(Icons.create_new_folder),
                    label: const Text('Nova Pasta'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  // Event handlers
  
  void _onItemTap(CloudItem item) {
    if (widget.selectionConfig.allowMultipleSelection) {
      _onItemSelected(item, !_selectedItems.contains(item));
    } else {
      setState(() {
        _selectedItems.clear();
        if (item is CloudFile || widget.selectionConfig.allowFolderSelection) {
          _selectedItems.add(item);
        }
      });
      _notifySelectionChanged();
    }
  }
  
  void _onItemDoubleTap(CloudItem item) {
    if (item is CloudFolder) {
      _navigateToFolder(item.id);
    } else if (item is CloudFile) {
      // Open file or preview
      _openFile(item);
    }
  }
  
  void _onItemSelected(CloudItem item, bool selected) {
    setState(() {
      if (selected) {
        if (!widget.selectionConfig.allowMultipleSelection) {
          _selectedItems.clear();
        }
        if (widget.selectionConfig.maxSelectionCount > _selectedItems.length) {
          if (item is CloudFile || widget.selectionConfig.allowFolderSelection) {
            _selectedItems.add(item);
          }
        }
      } else {
        _selectedItems.remove(item);
      }
    });
    _notifySelectionChanged();
  }
  
  void _onViewModeChanged(ViewMode viewMode) {
    setState(() {
      _viewMode = viewMode;
    });
  }
  
  void _onSortChanged(SortOption sortOption) {
    setState(() {
      _sortOption = sortOption;
      _sortItems();
    });
  }
  
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _performSearch();
  }
  
  // Navigation and data loading
  
  Future<void> _navigateToFolder(String? folderId) async {
    setState(() {
      _currentFolderId = folderId;
      _selectedItems.clear();
      _searchQuery = '';
    });
    
    await _loadFolderPath();
    await _loadItems();
  }
  
  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      List<CloudItem> items;
      
      if (_searchQuery.isNotEmpty) {
        final query = SearchQuery(
          query: _searchQuery,
          folderId: _currentFolderId,
          sortBy: _sortOption,
        );
        items = await widget.provider.searchItems(query);
      } else {
        items = await widget.provider.listItems(_currentFolderId);
      }
      
      setState(() {
        _items = items;
        _sortItems();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadFolderPath() async {
    try {
      final path = await widget.provider.getFolderPath(_currentFolderId);
      setState(() {
        _folderPath = path;
      });
    } catch (e) {
      // Ignore path loading errors
      print('Error loading folder path: $e');
    }
  }
  
  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) {
      await _loadItems();
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final query = SearchQuery(
        query: _searchQuery,
        folderId: _currentFolderId,
        sortBy: _sortOption,
      );
      final results = await widget.provider.searchItems(query);
      
      setState(() {
        _items = results;
        _sortItems();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  void _sortItems() {
    // Items are already sorted by the provider, but we can apply additional sorting here if needed
  }
  
  void _notifySelectionChanged() {
    final selectedFiles = _selectedItems.whereType<CloudFile>().toList();
    widget.onFilesSelected?.call(selectedFiles);
  }
  
  // File operations
  
  void _openFile(CloudFile file) {
    // TODO: Implement file opening/preview
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abrir Arquivo'),
        content: Text('Abrindo ${file.name}...\n\nFuncionalidade em desenvolvimento.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showUploadDialog() async {
    // TODO: Implement upload dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload de Arquivos'),
        content: const Text('Funcionalidade de upload em desenvolvimento...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showCreateFolderDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CreateFolderDialog(),
    );
    
    if (result != null && result.isNotEmpty) {
      await _createFolder(result);
    }
  }
  
  Future<void> _createFolder(String name) async {
    try {
      await widget.provider.createFolder(name, _currentFolderId);
      await _loadItems();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sucesso'),
          content: Text('Pasta "$name" criada com sucesso'),
          backgroundColor: Colors.green.shade50,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erro'),
          content: Text('Erro ao criar pasta: $e'),
          backgroundColor: Colors.red.shade50,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
  
  Future<void> _deleteSelected() async {
    final count = _selectedItems.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          count == 1 
              ? 'Tem certeza que deseja excluir "${_selectedItems.first.name}"?'
              : 'Tem certeza que deseja excluir $count itens selecionados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      for (final item in _selectedItems) {
        try {
          await widget.provider.deleteItem(item.id);
        } catch (e) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Erro'),
              content: Text('Erro ao excluir ${item.name}: $e'),
              backgroundColor: Colors.red.shade50,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
      
      setState(() {
        _selectedItems.clear();
      });
      
      await _loadItems();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sucesso'),
          content: Text('$count ${count == 1 ? 'item excluído' : 'itens excluídos'}'),
          backgroundColor: Colors.green.shade50,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

/// View modes for file display
enum ViewMode { grid, list, details }

/// Dialog for creating new folders
class _CreateFolderDialog extends StatefulWidget {
  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Pasta'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Nome da pasta',
            hintText: 'Digite o nome da nova pasta',
          ),
          autofocus: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Digite um nome para a pasta';
            }
            return null;
          },
          onFieldSubmitted: (value) {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(value.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('Criar'),
        ),
      ],
    );
  }
}