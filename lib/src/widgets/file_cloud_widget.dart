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
import '../utils/app_logger.dart';
import 'provider_logo.dart';
import 'provider_card.dart';
import 'account_card.dart';

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
    AppLogger.systemInit('FileCloudWidget iniciado');
    _initializeProviders();
    _loadAccounts();
  }

  void _initializeProviders() {
    AppLogger.info('Inicializando provedores de nuvem', component: 'Init');
    
    // Only initialize enabled/implemented providers
    final enabledProviders = ProviderHelper.getEnabledProviders();
    AppLogger.info('Provedores habilitados: $enabledProviders', component: 'Init');
    
    for (final providerType in enabledProviders) {
      switch (providerType) {
        case 'google_drive':
          _providers[providerType] = GoogleDriveProvider();
          AppLogger.success('GoogleDriveProvider inicializado', component: 'Init');
          break;
        // TODO: Add other providers when implemented
        // case 'dropbox':
        //   _providers[providerType] = DropboxProvider();
        //   break;
        // case 'onedrive':
        //   _providers[providerType] = OneDriveProvider();
        //   break;
        default:
          AppLogger.warning('Provedor não implementado: $providerType', component: 'Init');
      }
    }
    
    // Set initial provider to first enabled provider
    _selectedProvider = widget.initialProvider ?? enabledProviders.first;
    AppLogger.info('Provedor inicial selecionado: $_selectedProvider', component: 'Init');
  }

  Future<void> _loadAccounts() async {
    AppLogger.info('Carregando contas do storage', component: 'Accounts');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final accounts = await widget.accountStorage.getAccounts();
      AppLogger.info('${accounts.length} contas carregadas do storage', component: 'Accounts');
      
      // Group accounts by provider
      _accountsByProvider.clear();
      for (final account in accounts) {
        _accountsByProvider
            .putIfAbsent(account.providerType, () => [])
            .add(account);
        AppLogger.debug('Conta agrupada: ${account.name} (${account.providerType})', component: 'Accounts');
      }

      // Select first account for current provider if available
      if (_selectedProvider != null && 
          _accountsByProvider[_selectedProvider!]?.isNotEmpty == true) {
        _selectedAccount = _accountsByProvider[_selectedProvider!]!.first;
        AppLogger.info('Conta selecionada automaticamente: ${_selectedAccount!.name}', component: 'Accounts');
        await _loadFiles();
      } else {
        AppLogger.info('Nenhuma conta disponível para o provedor $_selectedProvider', component: 'Accounts');
      }
    } catch (e) {
      AppLogger.error('Erro ao carregar contas', component: 'Accounts', error: e);
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
    if (_selectedAccount == null || _selectedProvider == null) {
      AppLogger.warning('Tentativa de carregar arquivos sem conta ou provedor selecionado', component: 'Files');
      return;
    }

    AppLogger.info('Carregando arquivos${folderId != null ? ' da pasta $folderId' : ' da raiz'}', component: 'Files');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = _providers[_selectedProvider!]!;
      provider.initialize(_selectedAccount!);
      
      AppLogger.debug('Provider inicializado para ${_selectedAccount!.name}', component: 'Files');
      
      final filesPage = await provider.listFolder(folderId: folderId);
      
      AppLogger.success('${filesPage.entries.length} arquivos carregados', component: 'Files');

      setState(() {
        _currentFiles = filesPage.entries;
        if (folderId != null) {
          _pathStack.add(folderId);
          AppLogger.debug('Pasta adicionada ao stack: $folderId', component: 'Files');
        } else {
          _pathStack.clear();
          AppLogger.debug('Stack de pastas limpo', component: 'Files');
        }
      });
    } catch (e) {
      AppLogger.error('Erro ao carregar arquivos', component: 'Files', error: e);
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

  void _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) {
      AppLogger.warning('Tentativa de exclusão sem arquivos selecionados', component: 'FileOps');
      return;
    }
    
    AppLogger.info('Iniciando exclusão de ${_selectedFiles.length} arquivo(s)', component: 'FileOps');
    _selectedFiles.forEach((file) {
      AppLogger.debug('Arquivo para exclusão: ${file.name} (ID: ${file.id})', component: 'FileOps');
    });
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
          'Deseja realmente excluir ${_selectedFiles.length} arquivo(s) selecionado(s)?\n\nEsta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppLogger.info('Exclusão cancelada pelo usuário', component: 'FileOps');
              Navigator.of(context).pop(false);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              AppLogger.info('Exclusão confirmada pelo usuário', component: 'FileOps');
              Navigator.of(context).pop(true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        AppLogger.info('Executando exclusão de arquivos...', component: 'FileOps');
        
        if (_selectedAccount == null || _selectedProvider == null) {
          throw Exception('Nenhuma conta ou provedor selecionado');
        }
        
        final provider = _providers[_selectedProvider!]!;
        provider.initialize(_selectedAccount!);
        
        // Excluir cada arquivo selecionado
        int successCount = 0;
        for (final file in _selectedFiles) {
          AppLogger.info('Excluindo arquivo: ${file.name}', component: 'FileOps');
          
          try {
            // Exclusão real via provider
            await provider.deleteEntry(entryId: file.id, permanent: false);
            
            // Remove da lista atual se estiver presente
            setState(() {
              _currentFiles.removeWhere((f) => f.id == file.id);
            });
            
            successCount++;
            AppLogger.success('Arquivo excluído com sucesso: ${file.name}', component: 'FileOps');
          } catch (e) {
            AppLogger.error('Erro ao excluir arquivo ${file.name}', component: 'FileOps', error: e);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro ao excluir ${file.name}: $e')),
              );
            }
            // Continue tentando excluir outros arquivos
          }
        }
        
        final totalFiles = _selectedFiles.length;
        setState(() {
          _selectedFiles.clear();
          _isSelectionMode = false;
        });
        
        AppLogger.success('Exclusão concluída: $successCount/$totalFiles arquivos excluídos', component: 'FileOps');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount arquivo(s) excluído(s) com sucesso!'),
            ),
          );
        }
        
        // Recarregar lista de arquivos
        await _loadFiles();
        
      } catch (e) {
        AppLogger.error('Erro durante exclusão de arquivos', component: 'FileOps', error: e);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir arquivos: $e')),
          );
        }
      }
    }
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna 1: Lista de Provedores
          _buildProviderColumn(),
          
          // Divisor vertical
          Container(
            width: 1,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          
          // Coluna 2: Conteúdo Principal
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  /// Primeira coluna: Lista de provedores com design melhorado
  Widget _buildProviderColumn() {
    return SizedBox(
      width: 260, // Reduzido de 280 para evitar overflow
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com melhor padding
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              'Provedores',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          
          // Lista de provedores com melhor espaçamento
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: ProviderHelper.getEnabledProviders().length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final providerType = ProviderHelper.getEnabledProviders()[index];
                final accounts = _accountsByProvider[providerType] ?? [];
                return ProviderCard(
                  providerType: providerType,
                  isSelected: _selectedProvider == providerType,
                  accounts: accounts,
                  onTap: () {
                    setState(() {
                      _selectedProvider = providerType;
                      _selectedAccount = null;
                      _currentFiles.clear();
                      _pathStack.clear();
                    });
                    _loadAccounts();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }



  /// Segunda coluna: Conteúdo principal com layout melhorado
  Widget _buildMainContent() {
    return Column(
      children: [
        // Seção de contas com altura fixa e sem overflow
        _buildAccountSection(),
        
        // Divisor horizontal
        Container(
          height: 1,
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        
        // Navegação de arquivos
        Expanded(
          child: _buildFileNavigation(),
        ),
        
        // Controles de seleção (se ativo)
        if (_isSelectionMode && widget.selectionConfig != null)
          _buildSelectionControls(),
      ],
    );
  }

  /// Seção de contas melhorada sem overflow
  Widget _buildAccountSection() {
    final accounts = _accountsByProvider[_selectedProvider] ?? [];
    
    return Container(
      height: 120, // Altura aumentada de 140 para 120 para evitar overflow
      padding: const EdgeInsets.all(16), // Padding reduzido de 20 para 16
      child: accounts.isEmpty ? _buildEmptyAccountsView() : _buildAccountsList(accounts),
    );
  }

  Widget _buildEmptyAccountsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Nenhuma conta conectada',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _addAccount,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar Conta'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList(List<CloudAccount> accounts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Cards de contas existentes
          ...accounts.asMap().entries.map((entry) {
            final index = entry.key;
            final account = entry.value;
            return Padding(
              padding: EdgeInsets.only(right: index < accounts.length ? 12 : 0),
              child: AccountCard(
                account: account,
                isSelected: _selectedAccount?.id == account.id,
                onTap: () {
                  setState(() {
                    _selectedAccount = account;
                    _currentFiles.clear();
                    _pathStack.clear();
                  });
                  _loadFiles();
                },
                onMenuAction: (action) {
                  // TODO: Implementar ações do menu
                  if (action == 'remove') {
                    // Remover conta
                  } else if (action == 'reauth') {
                    // Reautorizar conta
                  }
                },
              ),
            );
          }),
          
          // Botão adicionar nova conta com design melhorado
          _buildAddAccountCard(),
        ],
      ),
    );
  }



  Widget _buildAddAccountCard() {
    const cardHeight = 80.0; // Mesma altura do AccountCard
    
    return Container(
      width: 120,
      height: cardHeight, // Altura igual ao card da conta
      margin: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _addAccount,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                'Adicionar\nConta',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
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
          TextButton(
            onPressed: _selectedFiles.isNotEmpty ? _deleteSelectedFiles : null,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
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