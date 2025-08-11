import 'package:flutter/material.dart';
import '../models/cloud_account.dart';
import '../models/account_status.dart';
import '../models/file_entry.dart';
import '../models/selection_config.dart';
import '../providers/base_cloud_provider.dart';
import '../providers/google_drive_provider.dart';
import '../storage/account_storage.dart';
import '../auth/oauth_config.dart';
import '../auth/oauth_manager.dart';
import '../theme/app_constants.dart';
import '../l10n/generated/app_localizations.dart';
import 'provider_logo.dart';

/// Main File Cloud widget that provides cloud storage integration
class FileCloudWidget extends StatefulWidget {
  /// Storage for managing user accounts
  final AccountStorage accountStorage;
  
  /// OAuth configuration for authentication
  final OAuthConfig oauthConfig;
  
  /// File selection configuration (optional)
  final SelectionConfig? selectionConfig;
  
  /// Callback when files are selected (required if selectionConfig is provided)
  final Function(List<FileEntry>)? onFilesSelected;
  
  /// Initial provider type to show ('google_drive', 'dropbox', 'onedrive')
  final String? initialProvider;

  const FileCloudWidget({
    super.key,
    required this.accountStorage,
    required this.oauthConfig,
    this.selectionConfig,
    this.onFilesSelected,
    this.initialProvider,
  });

  @override
  State<FileCloudWidget> createState() => _FileCloudWidgetState();
}

class _FileCloudWidgetState extends State<FileCloudWidget> {
  final Map<String, BaseCloudProvider> _providers = {};
  final Map<String, List<CloudAccount>> _accountsByProvider = {};
  String? _selectedProvider;
  CloudAccount? _selectedAccount;
  List<FileEntry> _currentFiles = [];
  List<String> _pathStack = [];
  bool _isLoading = false;
  String? _error;
  List<FileEntry> _selectedFiles = [];
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _initializeProviders();
    _loadAccounts();
  }

  void _initializeProviders() {
    // Only initialize enabled/implemented providers
    final enabledProviders = ProviderHelper.getEnabledProviders();
    
    for (final providerType in enabledProviders) {
      switch (providerType) {
        case 'google_drive':
          _providers[providerType] = GoogleDriveProvider();
          break;
        // TODO: Add other providers when implemented
        // case 'dropbox':
        //   _providers[providerType] = DropboxProvider();
        //   break;
        // case 'onedrive':
        //   _providers[providerType] = OneDriveProvider();
        //   break;
      }
    }
    
    // Set initial provider to first enabled provider
    _selectedProvider = widget.initialProvider ?? enabledProviders.first;
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final accounts = await widget.accountStorage.getAccounts();
      
      // Group accounts by provider
      _accountsByProvider.clear();
      for (final account in accounts) {
        _accountsByProvider
            .putIfAbsent(account.providerType, () => [])
            .add(account);
      }

      // Select first account for current provider if available
      if (_selectedProvider != null && 
          _accountsByProvider[_selectedProvider!]?.isNotEmpty == true) {
        _selectedAccount = _accountsByProvider[_selectedProvider!]!.first;
        await _loadFiles();
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar contas: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFiles({String? folderId}) async {
    if (_selectedAccount == null || _selectedProvider == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = _providers[_selectedProvider!]!;
      provider.initialize(_selectedAccount!);
      
      final filesPage = await provider.listFolder(folderId: folderId);

      setState(() {
        _currentFiles = filesPage.entries;
        if (folderId != null) {
          _pathStack.add(folderId);
        } else {
          _pathStack.clear();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar arquivos: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addAccount() async {
    if (_selectedProvider == null) return;

    try {
      print('🔍 Starting OAuth for $_selectedProvider');
      
      final oauthManager = OAuthManager();
      final result = await oauthManager.authenticate(widget.oauthConfig);
      
      print('🔍 OAuth result - Success: ${result.isSuccess}');
      if (result.accessToken != null) {
        print('🔍 Access token received: ${result.accessToken!.substring(0, 20)}...');
      } else {
        print('🔍 OAuth failed - Error: ${result.error}');
      }
      
      if (result.accessToken != null) {
        final provider = _providers[_selectedProvider!]!;
        
        // Create temporary account to get profile
        final tempAccount = CloudAccount(
          id: 'temp',
          providerType: _selectedProvider!,
          externalId: result.additionalData['user_id']?.toString() ?? 'unknown',
          accessToken: result.accessToken!,
          refreshToken: result.refreshToken,
          name: 'Loading...',
          email: 'Loading...',
          status: AccountStatus.ok,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        provider.initialize(tempAccount);
        final profile = await provider.getUserProfile();

        final account = CloudAccount(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          providerType: _selectedProvider!,
          externalId: profile.id,
          accessToken: result.accessToken!,
          refreshToken: result.refreshToken,
          name: profile.name,
          email: profile.email,
          photoUrl: profile.photoUrl,
          status: AccountStatus.ok,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await widget.accountStorage.saveAccount(account);
        await _loadAccounts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta adicionada com sucesso!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro na autenticação: ${result.error ?? "Cancelado pelo usuário"}')),
          );
        }
      }
    } catch (e) {
      print('🔍 Exception in _addAccount: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar conta: $e')),
        );
      }
    }
  }

  void _toggleFileSelection(FileEntry file) {
    if (widget.selectionConfig == null) return;

    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
      } else {
        // Check selection limits
        if (widget.selectionConfig!.maxSelection != null &&
            _selectedFiles.length >= widget.selectionConfig!.maxSelection!) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Máximo de ${widget.selectionConfig!.maxSelection} arquivos',
              ),
            ),
          );
          return;
        }

        _selectedFiles.add(file);
      }

      _isSelectionMode = _selectedFiles.isNotEmpty;
    });
  }

  void _useSelection() {
    if (widget.onFilesSelected != null && _selectedFiles.isNotEmpty) {
      widget.onFilesSelected!(_selectedFiles);
    }
    
    // Also call the selection config callback if it exists
    if (widget.selectionConfig?.onSelectionConfirm != null && _selectedFiles.isNotEmpty) {
      widget.selectionConfig!.onSelectionConfirm!(_selectedFiles);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Coluna 1: Lista de Provedores
        _buildProviderColumn(),
        
        // Coluna 2: Conteúdo Principal (contas + arquivos)
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    );
  }

  /// Primeira coluna: Lista de provedores
  Widget _buildProviderColumn() {
    return Container(
      width: AppConstants.providerListWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingM),
            child: Text(
              'Provedores',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Lista de provedores
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingS),
              children: ProviderHelper.getEnabledProviders().map((providerType) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
                  child: _buildProviderCard(providerType),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(String providerType) {
    final isSelected = _selectedProvider == providerType;
    final accounts = _accountsByProvider[providerType] ?? [];
    final displayName = ProviderHelper.getDisplayName(providerType);
    
    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer 
          : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedProvider = providerType;
            _selectedAccount = null;
            _currentFiles.clear();
            _pathStack.clear();
          });
          _loadAccounts();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProviderLogo(
                    providerType: providerType,
                    size: AppConstants.iconL,
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Expanded(
                    child: Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppConstants.spacingS),
              Text(
                '${accounts.length} conta${accounts.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Segunda coluna: Conteúdo principal dividido em duas linhas
  Widget _buildMainContent() {
    return Column(
      children: [
        // Linha 1: Carrossel de contas
        _buildAccountCarousel(),
        
        // Linha 2: Navegação de arquivos
        Expanded(
          child: _buildFileNavigation(),
        ),
        
        // Controles de seleção (se ativo)
        if (_isSelectionMode && widget.selectionConfig != null)
          _buildSelectionControls(),
      ],
    );
  }

  /// Carrossel de contas integradas
  Widget _buildAccountCarousel() {
    final accounts = _accountsByProvider[_selectedProvider] ?? [];
    
    return Container(
      height: AppConstants.accountCarouselHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: accounts.isEmpty ? _buildEmptyAccountsView() : _buildAccountsList(accounts),
    );
  }

  Widget _buildEmptyAccountsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppConstants.spacingS),
            Text(
              'Nenhuma conta conectada',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
            FilledButton.icon(
              onPressed: _addAccount,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Conta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsList(List<CloudAccount> accounts) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(AppConstants.paddingM),
      itemCount: accounts.length + 1, // +1 para botão adicionar
      itemBuilder: (context, index) {
        if (index == accounts.length) {
          // Botão adicionar nova conta
          return Container(
            width: 200,
            margin: const EdgeInsets.only(left: AppConstants.spacingS),
            child: Card(
              child: InkWell(
                onTap: _addAccount,
                borderRadius: BorderRadius.circular(12),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, size: AppConstants.iconL),
                      SizedBox(height: AppConstants.spacingXS),
                      Text('Adicionar\nConta', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        
        final account = accounts[index];
        final isSelected = _selectedAccount?.id == account.id;
        
        return Container(
          width: 200,
          margin: EdgeInsets.only(
            left: index == 0 ? 0 : AppConstants.spacingS,
          ),
          child: Card(
            elevation: isSelected ? 2 : 0,
            color: isSelected 
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surface,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedAccount = account;
                  _currentFiles.clear();
                  _pathStack.clear();
                });
                _loadFiles();
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(12),
              ),
              child: Row(
                children: [
                  // Foto (40x40)
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.all(AppConstants.paddingS),
                    child: CircleAvatar(
                      backgroundImage: account.photoUrl != null
                          ? NetworkImage(account.photoUrl!)
                          : null,
                      child: account.photoUrl == null
                          ? Text(account.name.substring(0, 1).toUpperCase())
                          : null,
                    ),
                  ),
                  
                  // Informações
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.paddingS,
                        horizontal: AppConstants.paddingXS,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            account.email,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Status icon
                          Row(
                            children: [
                              Icon(
                                account.status == AccountStatus.ok 
                                    ? Icons.check_circle 
                                    : Icons.error,
                                size: 12,
                                color: account.status == AccountStatus.ok 
                                    ? Colors.green 
                                    : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                account.status == AccountStatus.ok 
                                    ? 'Conectado' 
                                    : 'Erro',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Menu
                  PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'reauth',
                        child: Row(
                          children: [
                            Icon(Icons.refresh),
                            SizedBox(width: 8),
                            Text('Reautorizar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Remover'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      // TODO: Implementar ações do menu
                      if (value == 'remove') {
                        // Remover conta
                      } else if (value == 'reauth') {
                        // Reautorizar conta
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Navegação de arquivos (parte inferior)
  Widget _buildFileNavigation() {
    if (_selectedAccount == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Selecione uma conta para navegar nos arquivos'),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando arquivos...'),
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
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _loadFiles(),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Navigation breadcrumb
        if (_pathStack.isNotEmpty) _buildBreadcrumb(),
        
        // File list
        Expanded(
          child: _currentFiles.isEmpty
              ? const Center(child: Text('Nenhum arquivo encontrado'))
              : ListView.builder(
                  itemCount: _currentFiles.length,
                  itemBuilder: (context, index) {
                    final file = _currentFiles[index];
                    return _buildFileItem(file);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _pathStack.clear();
              });
              _loadFiles();
            },
            icon: const Icon(Icons.home, size: 16),
            label: const Text('Início'),
          ),
          if (_pathStack.isNotEmpty) ...[
            const Icon(Icons.chevron_right, size: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _pathStack.removeLast();
                });
                _loadFiles(folderId: _pathStack.isNotEmpty ? _pathStack.last : null);
              },
              child: const Text('Voltar'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileItem(FileEntry file) {
    final isSelected = _selectedFiles.contains(file);
    
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.selectionConfig != null)
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleFileSelection(file),
            ),
          Icon(
            file.isFolder ? Icons.folder : Icons.description,
            color: file.isFolder
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ],
      ),
      title: Text(file.name),
      subtitle: file.size != null
          ? Text('${(file.size! / 1024 / 1024).toStringAsFixed(1)} MB')
          : null,
      onTap: () {
        if (widget.selectionConfig != null) {
          _toggleFileSelection(file);
        } else if (file.isFolder) {
          _loadFiles(folderId: file.id);
        }
      },
      selected: isSelected,
    );
  }

  Widget _buildSelectionControls() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_selectedFiles.length} arquivo(s) selecionado(s)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedFiles.clear();
                _isSelectionMode = false;
              });
            },
            child: const Text('Limpar'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _selectedFiles.isNotEmpty ? _useSelection : null,
            child: const Text('Usar Seleção'),
          ),
        ],
      ),
    );
  }
}