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

import '../utils/app_logger.dart';
import 'provider_logo.dart';
import 'provider_card.dart';
import 'account_card.dart';
import 'file_item_card.dart';

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
  bool _isAddingAccount = false;

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

      // Select first valid account for current provider if available
      if (_selectedProvider != null && 
          _accountsByProvider[_selectedProvider!]?.isNotEmpty == true) {
        
        // Find the first account with OK status
        final availableAccounts = _accountsByProvider[_selectedProvider!]!;
        final validAccount = availableAccounts.where(
          (account) => account.status == AccountStatus.ok,
        ).firstOrNull;
        
        if (validAccount != null) {
          _selectedAccount = validAccount;
          AppLogger.info('Conta selecionada automaticamente: ${_selectedAccount!.name}', component: 'Accounts');
          await _loadFiles();
        } else {
          AppLogger.warning('Nenhuma conta válida (status OK) encontrada para o provedor $_selectedProvider', component: 'Accounts');
          _selectedAccount = null;
        }
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

  /// Handles authentication errors by updating account status and reloading accounts
  Future<void> _handleAuthenticationError(dynamic error, String component) async {
    if (error is CloudProviderException && error.statusCode == 401) {
      AppLogger.warning('Erro de autenticação detectado, atualizando status da conta', component: component);
      
      // Update account status to revoked and save it
      if (_selectedAccount != null) {
        final updatedAccount = _selectedAccount!.updateStatus(AccountStatus.revoked);
        await widget.accountStorage.saveAccount(updatedAccount);
        AppLogger.info('Status da conta atualizado para revoked: ${updatedAccount.name}', component: component);
        
        // Clear the selected account to prevent further attempts with invalid credentials
        _selectedAccount = null;
        
        // Reload accounts to reflect the updated status in UI, but don't auto-load files
        await _reloadAccountsOnly();
      }
    }
  }

  /// Shows reconnection dialog for revoked accounts
  void _showReconnectDialog(CloudAccount account) {
    AppLogger.info('Mostrando dialog de reconexão para conta: ${account.name}', component: 'ReconnectDialog');
    
    // Ensure we're not in a loading state when showing the dialog
    setState(() {
      _isLoading = false;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (context) => AlertDialog(
        title: const Text('Conta desconectada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A conta "${account.name}" (${account.email}) do ${account.providerType.toString().split('.').last} foi desconectada e precisa ser reconectada.'),
            const SizedBox(height: 16),
            const Text('Isso pode acontecer por:'),
            const SizedBox(height: 8),
            const Text('• Token de acesso expirado'),
            const Text('• Permissões foram revogadas'),
            const Text('• Configurações de segurança alteradas'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _reconnectAccount(account);
            },
            child: const Text('Reconectar'),
          ),
        ],
      ),
    );
    });
  }

  /// Reconnects a revoked account
  Future<void> _reconnectAccount(CloudAccount account) async {
    AppLogger.info('Iniciando reconexão da conta: ${account.name}', component: 'Auth');
    
    try {
      // Remove the old account
      await widget.accountStorage.removeAccount(account.id);
      
      // Start new OAuth flow for the same provider
      await _addAccount();
      
    } catch (e) {
      AppLogger.error('Erro ao reconectar conta', component: 'Auth', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao reconectar: $e')),
        );
      }
    }
  }

  /// Reloads accounts without auto-selecting or loading files
  Future<void> _reloadAccountsOnly() async {
    AppLogger.info('Recarregando contas (sem seleção automática)', component: 'Accounts');
    
    try {
      final accounts = await widget.accountStorage.getAccounts();
      AppLogger.info('${accounts.length} contas recarregadas', component: 'Accounts');
      
      setState(() {
        // Group accounts by provider
        _accountsByProvider.clear();
        for (final account in accounts) {
          _accountsByProvider
              .putIfAbsent(account.providerType, () => [])
              .add(account);
          AppLogger.debug('Conta reagrupada: ${account.name} (${account.providerType}) - Status: ${account.status}', component: 'Accounts');
        }
      });
    } catch (e) {
      AppLogger.error('Erro ao recarregar contas', component: 'Accounts', error: e);
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
      
      // Handle authentication errors
      await _handleAuthenticationError(e, 'Files');
      
      setState(() {
        _error = 'Erro ao carregar arquivos: $e';
        // Clear current files on error to show empty state
        _currentFiles = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addAccount() async {
    if (_selectedProvider == null || _isAddingAccount) return;

    setState(() {
      _isAddingAccount = true;
    });

    try {
      AppLogger.info('Iniciando OAuth para $_selectedProvider', component: 'Auth');
      
      final oauthManager = OAuthManager();
      final result = await oauthManager.authenticate(widget.oauthConfig);
      
      AppLogger.info('Resultado OAuth - Sucesso: ${result.isSuccess}', component: 'Auth');
      if (result.accessToken != null) {
        AppLogger.debug('Token de acesso recebido', component: 'Auth');
      } else {
        AppLogger.warning('OAuth falhou - Erro: ${result.error}', component: 'Auth');
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
      AppLogger.error('Erro ao adicionar conta', component: 'Auth', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar conta: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingAccount = false;
        });
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
        if (_selectedFiles.length >= widget.selectionConfig!.maxSelection) {
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
        title: Text(
          _selectedFiles.length == 1 
              ? 'Confirmar exclusão' 
              : 'Confirmar exclusão de ${_selectedFiles.length} itens'
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedFiles.length == 1
                    ? 'Deseja realmente excluir este arquivo?'
                    : 'Deseja realmente excluir os seguintes arquivos?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (_selectedFiles.length <= 10) ...[
                // Show full list for up to 10 files
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _selectedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      return FileItemCard(
                        file: file,
                        isSelected: false,
                        showCheckbox: false,
                      );
                    },
                  ),
                ),
              ] else ...[
                // Show first 5 files, then "... and X more"
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                  ),
                  child: Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          final file = _selectedFiles[index];
                          return FileItemCard(
                            file: file,
                            isSelected: false,
                            showCheckbox: false,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '... e mais ${_selectedFiles.length - 5} arquivo(s)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta ação não pode ser desfeita.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            
            // Handle authentication errors
            await _handleAuthenticationError(e, 'FileOps');
            
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
        mainAxisSize: MainAxisSize.min, // Usa apenas o espaço necessário
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 24, // Reduzido de 32 para 24
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4), // Reduzido de 8 para 4
          Text(
            'Nenhuma conta conectada',
            style: Theme.of(context).textTheme.bodySmall?.copyWith( // Mudado de bodyMedium para bodySmall
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8), // Reduzido de 12 para 8
          FilledButton.icon(
            onPressed: _isAddingAccount ? null : _addAccount,
            icon: _isAddingAccount 
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.add, size: 16),
            label: Text(_isAddingAccount ? 'Conectando...' : 'Adicionar Conta'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList(List<CloudAccount> accounts) {
    return Row(
      children: [
        // Carrossel de contas existentes
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: accounts.asMap().entries.map((entry) {
                final index = entry.key;
                final account = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < accounts.length - 1 ? 12 : 0, // Espaçamento entre contas
                  ),
                  child: AccountCard(
                    account: account,
                    isSelected: _selectedAccount?.id == account.id,
                    onTap: () {
                      // Check if account has valid status before selecting
                      if (account.status == AccountStatus.revoked) {
                        // Log for debugging
                        AppLogger.info('Conta revoked clicada: ${account.name}. Mostrando dialog de reconexão.', component: 'AccountSelection');
                        // Show reconnection dialog for revoked accounts
                        _showReconnectDialog(account);
                        return;
                      }
                      
                      AppLogger.info('Selecionando conta: ${account.name}', component: 'AccountSelection');
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
              }).toList(),
            ),
          ),
        ),
        
        // Espaçamento entre carrossel e botão
        const SizedBox(width: 16),
        
        // Botão adicionar nova conta fora do carrossel
        _buildAddAccountCard(),
      ],
    );
  }



  Widget _buildAddAccountCard() {
    const cardHeight = 80.0; // Mesma altura do AccountCard
    
    return Container(
      width: 120,
      height: cardHeight, // Altura igual ao card da conta
      // Removida margem left pois agora está fora do carrossel
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
          onTap: _isAddingAccount ? null : _addAccount,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _isAddingAccount 
                  ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isAddingAccount
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.add_circle_outline,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                const SizedBox(height: 4),
                Text(
                  _isAddingAccount ? 'Conectando...' : 'Adicionar\nConta',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _isAddingAccount
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
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
    
    return FileItemCard(
      file: file,
      isSelected: isSelected,
      showCheckbox: widget.selectionConfig != null,
      onTap: () {
        if (widget.selectionConfig != null) {
          _toggleFileSelection(file);
        } else if (file.isFolder) {
          _loadFiles(folderId: file.id);
        }
      },
      onCheckboxChanged: widget.selectionConfig != null 
          ? (_) => _toggleFileSelection(file)
          : null,
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
          // Botão Excluir no início (mais longe dos outros)
          TextButton(
            onPressed: _selectedFiles.isNotEmpty ? _deleteSelectedFiles : null,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
          const Spacer(), // Espaça o botão excluir dos demais
          Text(
            '${_selectedFiles.length} arquivo(s) selecionado(s)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 16),
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