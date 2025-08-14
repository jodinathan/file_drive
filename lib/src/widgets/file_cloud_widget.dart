import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import '../models/cloud_account.dart';
import '../models/account_status.dart';
import '../models/file_entry.dart';
import '../models/image_file_entry.dart';
import '../models/selection_config.dart';
import '../models/crop_config.dart';
import '../providers/base_cloud_provider.dart';
import '../providers/google_drive_provider.dart';
import '../providers/local_server_provider.dart';
import '../providers/account_based_provider.dart';
import '../storage/account_storage.dart';
import '../auth/oauth_config.dart';
import '../auth/oauth_manager.dart';
import '../theme/app_constants.dart';
import '../l10n/generated/app_localizations.dart';
import '../managers/navigation_manager.dart';

import '../utils/app_logger.dart';
import 'provider_logo.dart';
import 'provider_card.dart';
import 'account_card.dart';
import 'file_item_card.dart';
import 'image_file_item_card.dart';
import 'crop_panel_widget.dart';
import 'navigation_bar_widget.dart';
import 'create_folder_dialog.dart';

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
  
  /// Crop configuration for image editing (if provided, enables crop functionality)
  final CropConfig? cropConfig;
  
  /// Callback when an image is cropped
  final Function(ImageFileEntry)? onImageCropped;

  const FileCloudWidget({
    super.key,
    required this.accountStorage,
    required this.oauthConfig,
    this.selectionConfig,
    this.onFilesSelected,
    this.initialProvider,
    this.cropConfig,
    this.onImageCropped,
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
  final List<FileEntry> _selectedFiles = [];
  bool _isSelectionMode = false;
  bool _isAddingAccount = false;
  bool _showCropPanel = false;
  List<ImageFileEntry> _croppableImageFiles = [];
  
  // Upload management
  final Map<String, UploadProgress> _activeUploads = {};
  static const bool _debugSlowUpload = true; // Flag para teste de upload lento
  void Function()? _uploadDialogUpdateCallback;
  
  // Calculate average upload progress
  double get _averageUploadProgress {
    // Filter only active uploads (not completed, error, or cancelled)
    final activeUploads = _activeUploads.values.where((progress) =>
        progress.status == UploadStatus.uploading ||
        progress.status == UploadStatus.waiting ||
        progress.status == UploadStatus.retrying ||
        progress.status == UploadStatus.paused).toList();
    
    if (activeUploads.isEmpty) {
      return 0.0;
    }
    
    double totalProgress = 0.0;
    int validUploads = 0;
    
    for (final progress in activeUploads) {
      if (progress.total > 0) {
        final currentProgress = progress.uploaded / progress.total;
        totalProgress += currentProgress;
        validUploads++;
      }
    }
    
    return validUploads > 0 ? totalProgress / validUploads : 0.0;
  }

  // Count only active uploads (not completed)
  int get _activeUploadsCount {
    return _activeUploads.values.where((progress) =>
        progress.status == UploadStatus.uploading ||
        progress.status == UploadStatus.waiting ||
        progress.status == UploadStatus.retrying ||
        progress.status == UploadStatus.paused).length;
  }

  // New managers for upload, navigation, and drag & drop
  // late UploadManager _uploadManager; // Comentado até implementação completa
  late NavigationManager _navigationManager;
  // late DragDropManager _dragDropManager; // Comentado até implementação completa

  @override
  void initState() {
    super.initState();
    AppLogger.systemInit('FileCloudWidget iniciado');
    
    // Initialize managers
    // _uploadManager = UploadManager(); // Comentado até implementação completa
    _navigationManager = NavigationManager();
    // _dragDropManager = DragDropManager(); // Comentado até implementação completa
    
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
        case 'local_server':
          _providers[providerType] = LocalServerProvider(
            serverUrl: 'http://localhost:8080',
          );
          AppLogger.success('LocalServerProvider inicializado', component: 'Init');
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
    
    // Set providers map in ProviderHelper for custom logo access
    ProviderHelper.setProvidersMap(_providers);
    
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
      // Check if current provider needs account management
      final showAccountManagement = ProviderHelper.getShowAccountManagement(_selectedProvider ?? '');
      
      if (!showAccountManagement && _selectedProvider != null) {
        // For providers without account management, no account needed
        AppLogger.info('Provider $_selectedProvider não usa gerenciamento de contas - funcionando sem conta', component: 'Accounts');
        
        _accountsByProvider.clear();
        _selectedAccount = null; // No account needed for serverless providers
        
        AppLogger.info('Provider $_selectedProvider configurado para funcionar sem contas', component: 'Accounts');
        await _loadFiles();
        return;
      }
      
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

  /// Handles authentication errors by trying to refresh token first, then updating account status
  Future<void> _handleAuthenticationError(dynamic error, String component) async {
    // LOG DETALHADO: Authentication error detected
    print('🔍 DEBUG: Authentication Error Handler Called:');
    print('   Error Type: ${error.runtimeType}');
    print('   Error: $error');
    print('   Component: $component');
    print('   Selected Account: ${_selectedAccount?.email ?? 'No account (serverless provider)'}');
    print('   Has Refresh Token: ${_selectedAccount?.refreshToken != null}');
    
    if (error is CloudProviderException && error.statusCode == 401) {
      AppLogger.warning('Erro de autenticação detectado, tentando refresh token', component: component);
      
      // Only try to refresh token for account-based providers
      final provider = _providers[_selectedProvider!]!;
      if (provider is AccountBasedProvider && _selectedAccount != null && _selectedAccount!.refreshToken != null && _selectedAccount!.refreshToken!.isNotEmpty) {
        try {
          // Try to refresh using provider's refreshAuth method first
          AppLogger.info('Tentando refresh do token via provider para: ${_selectedAccount!.name}', component: component);
          print('🔍 DEBUG: Attempting provider token refresh for account: ${_selectedAccount!.email}');
          
          final provider = _providers[_selectedProvider!]!;
          if (provider is AccountBasedProvider) {
            final refreshedAccount = await provider.refreshAuth(_selectedAccount!);
            
            if (refreshedAccount != null) {
              // Token refreshed successfully via provider
              _selectedAccount = refreshedAccount;
              await widget.accountStorage.saveAccount(refreshedAccount);
              AppLogger.success('Token refreshed via provider com sucesso: ${refreshedAccount.name}', component: component);
              
              // Reinitialize provider with new token
              provider.initialize(refreshedAccount);
              
              // Reload accounts to reflect the updated token in UI
              await _reloadAccountsOnly();
              return; // Success, no need to mark as revoked
            }
          }
          
          // Fallback to OAuth manager refresh if provider refresh fails
          final refreshedAccount = await _refreshAccountToken(_selectedAccount!);
          
          if (refreshedAccount != null) {
            // Token refreshed successfully
            _selectedAccount = refreshedAccount;
            await widget.accountStorage.saveAccount(refreshedAccount);
            AppLogger.success('Token refreshed com sucesso: ${refreshedAccount.name}', component: component);
            
            // Reinitialize provider with new token (only for account-based providers)
            final provider = _providers[_selectedProvider!]!;
            if (provider is AccountBasedProvider) {
              provider.initialize(refreshedAccount);
            }
            
            // Reload accounts to reflect the updated token in UI
            await _reloadAccountsOnly();
            return; // Success, no need to mark as revoked
          }
        } catch (refreshError) {
          AppLogger.error('Falha ao fazer refresh do token', component: component, error: refreshError);
        }
      } else {
        if (provider is AccountBasedProvider) {
          AppLogger.warning('Refresh token não disponível para a conta: ${_selectedAccount?.email}', component: component);
          print('⚠️  Refresh token is null or empty. Account will need reauthorization.');
        } else {
          AppLogger.warning('Erro de autenticação em provider serverless - verificar configuração do servidor', component: component);
          print('⚠️  Serverless provider authentication failed. Check server configuration.');
        }
      }
      
      // If refresh failed or no refresh token available, mark as revoked (only for account-based providers)
      if (provider is AccountBasedProvider) {
        AppLogger.warning('Marcando conta como revogada devido à falha de autenticação', component: component);
        
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
      } else {
        AppLogger.warning('Provider serverless com erro de autenticação - não há conta para marcar como revogada', component: component);
      }
    }
  }

  /// Attempts to refresh the account token using OAuth manager
  Future<CloudAccount?> _refreshAccountToken(CloudAccount account) async {
    try {
      AppLogger.info('Iniciando refresh token para provedor: ${account.providerType}', component: 'Auth');
      
      // LOG DETALHADO: Estado da conta antes do refresh
      print('🔍 DEBUG: Refresh Token Request - Estado da Conta:');
      print('   Account ID: ${account.id}');
      print('   Account Email: ${account.email}');
      print('   Provider Type: ${account.providerType}');
      print('   Access Token (last 10 chars): ${account.accessToken.substring(account.accessToken.length - 10)}');
      print('   Refresh Token exists: ${account.refreshToken != null}');
      print('   Refresh Token (last 10 chars): ${account.refreshToken?.substring((account.refreshToken?.length ?? 0) - 10)}');
      print('   Token expires at: ${account.expiresAt}');
      print('   Current time: ${DateTime.now().toIso8601String()}');
      print('   Account Status: ${account.status}');
      
      // Get OAuth configuration for the provider
      final oauthConfig = widget.oauthConfig;
      if (oauthConfig.providerType != account.providerType) {
        AppLogger.error('OAuth config não corresponde ao tipo do provedor: ${oauthConfig.providerType} != ${account.providerType}', component: 'Auth');
        return null;
      }
      
      // Create OAuth manager instance
      final oauthManager = OAuthManager();
      
      // Build refresh URL from the auth URL pattern
      // Extract base URL from generateAuthUrl and create refresh endpoint
      final authUrl = oauthConfig.generateAuthUrl('dummy');
      final baseUrl = authUrl.split('/auth/')[0]; // Get base URL
      final refreshUrl = '$baseUrl/auth/refresh';
      
      AppLogger.info('Usando refresh URL: $refreshUrl', component: 'Auth');
      print('🔍 DEBUG: Refresh URL: $refreshUrl');
      
      // Attempt to refresh the token
      final result = await oauthManager.refreshToken(
        refreshUrl: refreshUrl,
        refreshToken: account.refreshToken!,
        clientId: null, // Most implementations don't need client ID for refresh
      );
      
      // LOG DETALHADO: Resultado do refresh
      print('🔍 DEBUG: Refresh Token Response:');
      print('   Success: ${result.isSuccess}');
      print('   Error: ${result.error}');
      print('   New Access Token exists: ${result.accessToken != null}');
      print('   New Access Token (last 10 chars): ${result.accessToken?.substring((result.accessToken?.length ?? 0) - 10)}');
      print('   New Refresh Token exists: ${result.refreshToken != null}');
      print('   New Refresh Token (last 10 chars): ${result.refreshToken?.substring((result.refreshToken?.length ?? 0) - 10)}');
      print('   New Expires At: ${result.expiresAt}');
      
      if (result.isSuccess) {
        // Update account with new tokens
        final refreshedAccount = account.updateTokens(
          accessToken: result.accessToken!,
          refreshToken: result.refreshToken ?? account.refreshToken,
          expiresAt: result.expiresAt,
        );
        
        AppLogger.success('Token refreshed com sucesso', component: 'Auth');
        print('🔍 DEBUG: Account updated with new tokens');
        return refreshedAccount;
      } else {
        AppLogger.warning('Refresh token falhou: ${result.error}', component: 'Auth');
        print('🔍 DEBUG: Refresh failed - account will be marked as revoked');
        return null;
      }
    } catch (e) {
      AppLogger.error('Erro durante refresh token', component: 'Auth', error: e);
      print('🔍 DEBUG: Exception during refresh: ${e.toString()}');
      return null;
    }
  }

  /// Checks if token needs refresh (expires within 5 minutes) and refreshes if needed
  Future<CloudAccount?> _checkAndRefreshTokenIfNeeded(CloudAccount account) async {
    // If no expiration time, assume token is still valid
    if (account.expiresAt == null) {
      return account;
    }
    
    // Check if token expires within 5 minutes
    final now = DateTime.now();
    final expiresIn = account.expiresAt!.difference(now);
    
    if (expiresIn.inMinutes <= 5) {
      AppLogger.info('Token expira em ${expiresIn.inMinutes} minutos, fazendo refresh preventivo', component: 'Auth');
      return await _refreshAccountToken(account);
    }
    
    return account;
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

  Future<void> _loadFiles({String? folderId, String? folderName, bool skipNavigation = false}) async {
    print('DEBUG: _loadFiles chamado com folderId: $folderId, skipNavigation: $skipNavigation');
    
    if (_selectedProvider == null) {
      AppLogger.warning('Tentativa de carregar arquivos sem provedor selecionado', component: 'Files');
      return;
    }

    // Check if this provider requires account management
    final provider = _providers[_selectedProvider!]!;
    final requiresAccount = provider is AccountBasedProvider;
    
    if (requiresAccount && _selectedAccount == null) {
      AppLogger.warning('Tentativa de carregar arquivos sem conta selecionada para provedor que requer conta', component: 'Files');
      return;
    }

    AppLogger.info('Carregando arquivos${folderId != null ? ' da pasta $folderId' : ' da raiz'}', component: 'Files');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check and refresh token if needed before making API calls (only for account-based providers)
      if (requiresAccount && _selectedAccount != null) {
        final refreshedAccount = await _checkAndRefreshTokenIfNeeded(_selectedAccount!);
        if (refreshedAccount != null && refreshedAccount != _selectedAccount) {
          _selectedAccount = refreshedAccount;
          await widget.accountStorage.saveAccount(refreshedAccount);
          AppLogger.info('Token atualizado preventivamente', component: 'Files');
        }
      }
      
      final provider = _providers[_selectedProvider!]!;
      if (provider is AccountBasedProvider && _selectedAccount != null) {
        provider.initialize(_selectedAccount!);
        AppLogger.debug('Provider inicializado para ${_selectedAccount!.name}', component: 'Files');
      } else {
        AppLogger.debug('Provider serverless inicializado sem conta', component: 'Files');
      }
      
      final filesPage = await provider.listFolder(folderId: folderId);
      
      AppLogger.success('${filesPage.entries.length} arquivos carregados', component: 'Files');

      setState(() {
        _currentFiles = filesPage.entries;
        
        // Only update navigation if not skipping (avoid double navigation)
        if (!skipNavigation) {
          print('DEBUG: Atualizando navegação no _loadFiles');
          // Update navigation manager with folder information
          if (folderId != null) {
            // Use provided folderName or fallback to searching in current files
            final finalFolderName = folderName ?? _currentFiles.firstWhere(
              (entry) => entry.id == folderId,
              orElse: () => FileEntry(
                id: folderId,
                name: 'Pasta',
                isFolder: true,
                size: 0,
                modifiedAt: DateTime.now(),
              ),
            ).name;
            
            _navigationManager.navigateToFolder(
              folderId: folderId,
              folderName: finalFolderName,
              providerType: _selectedProvider!,
              accountId: _selectedAccount?.id ?? 'serverless',
            );
            _pathStack = _navigationManager.history.current?.pathComponents ?? [];
          } else {
            _navigationManager.navigateToFolder(
              folderId: null,
              folderName: _getRootFolderName(context),
              providerType: _selectedProvider!,
              accountId: _selectedAccount?.id ?? 'serverless',
            );
            _pathStack.clear();
          }
        } else {
          print('DEBUG: Pulando atualização de navegação');
          // Just update _pathStack from current navigation state
          _pathStack = _navigationManager.history.current?.pathComponents ?? [];
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
      
      // LOG DETALHADO: Verificar se refresh token foi recebido
      print('🔍 DEBUG: OAuth Result Details:');
      print('   Success: ${result.isSuccess}');
      print('   Access Token exists: ${result.accessToken != null}');
      print('   Access Token (last 10 chars): ${result.accessToken?.substring((result.accessToken?.length ?? 0) - 10)}');
      print('   Refresh Token exists: ${result.refreshToken != null}');
      print('   Refresh Token (last 10 chars): ${result.refreshToken?.substring((result.refreshToken?.length ?? 0) - 10)}');
      print('   Expires At: ${result.expiresAt}');
      print('   Additional Data: ${result.additionalData}');

      // Verificar se o refresh token está presente
      if (result.refreshToken == null || result.refreshToken!.isEmpty) {
        print('⚠️  WARNING: Refresh token não recebido do servidor OAuth!');
        print('   Isso significa que a conta precisará ser reautorizada quando o token expirar.');
        print('   Para resolver, configure o servidor OAuth com:');
        print('   - access_type=offline');
        print('   - approval_prompt=force (ou prompt=consent)');
      } else {
        print('✅ Refresh token recebido com sucesso');
      }
      
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

        if (provider is AccountBasedProvider) {
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
    for (final file in _selectedFiles) {
      AppLogger.debug('Arquivo para exclusão: ${file.name} (ID: ${file.id})', component: 'FileOps');
    }
    
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
        
        if (_selectedProvider == null) {
          throw Exception('Nenhum provedor selecionado');
        }
        
        final provider = _providers[_selectedProvider!]!;
        
        // Only check for account if provider requires it
        if (provider is AccountBasedProvider) {
          if (_selectedAccount == null) {
            throw Exception('Nenhuma conta selecionada para provedor que requer conta');
          }
          provider.initialize(_selectedAccount!);
        }
        
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
    print('🔍 DEBUG _useSelection:');
    print('   - selectedFiles count: ${_selectedFiles.length}');
    print('   - selectedFiles types: ${_selectedFiles.map((f) => f.runtimeType).toList()}');
    
    // Check if crop is enabled and we have selected image files
    if (widget.cropConfig != null && _selectedFiles.isNotEmpty) {
      // Try to get both existing ImageFileEntry and convert FileEntry to ImageFileEntry
      final allImageFiles = <ImageFileEntry>[];
      
      for (final file in _selectedFiles) {
        if (file is ImageFileEntry && file.canBeCropped()) {
          allImageFiles.add(file);
        } else if (!file.isFolder && file.mimeType != null && file.mimeType!.startsWith('image/')) {
          final imageEntry = ImageFileEntry.tryCreateImageFileEntry(file);
          if (imageEntry != null && imageEntry.canBeCropped()) {
            allImageFiles.add(imageEntry);
          }
        }
      }
      
      print('   - Found ${allImageFiles.length} croppable images');
      
      if (allImageFiles.isNotEmpty) {
        print('   - Showing crop panel!');
        // Store the converted image files for the crop panel
        _croppableImageFiles = allImageFiles;
        setState(() {
          _showCropPanel = true;
        });
        return;
      }
    }
    
    print('   - Using original behavior');
    // Original behavior for non-crop cases
    if (widget.onFilesSelected != null && _selectedFiles.isNotEmpty) {
      widget.onFilesSelected!(_selectedFiles);
    }
    
    // Also call the selection config callback if it exists
    if (widget.selectionConfig?.onSelectionConfirm != null && _selectedFiles.isNotEmpty) {
      widget.selectionConfig?.onSelectionConfirm!(_selectedFiles);
    }
  }
  void _handleCropCompleted(List<ImageFileEntry> croppedFiles) {
    // Update the selected files with the cropped versions
    for (int i = 0; i < _selectedFiles.length; i++) {
      final selectedFile = _selectedFiles[i];
      if (selectedFile is ImageFileEntry) {
        final croppedFile = croppedFiles.firstWhere(
          (file) => file.id == selectedFile.id,
          orElse: () => selectedFile,
        );
        _selectedFiles[i] = croppedFile;
        
        // Also update in the current files list
        final currentIndex = _currentFiles.indexWhere((file) => file.id == selectedFile.id);
        if (currentIndex != -1) {
          _currentFiles[currentIndex] = croppedFile;
        }
      }
    }
    
    setState(() {
      _showCropPanel = false;
      _croppableImageFiles = [];
    });
    
    // Trigger callback for cropped images
    if (widget.onImageCropped != null) {
      for (final croppedFile in croppedFiles) {
        if (croppedFile.hasCropData()) {
          widget.onImageCropped!(croppedFile);
        }
      }
    }
    
    // Complete the selection process
    if (widget.onFilesSelected != null && _selectedFiles.isNotEmpty) {
      widget.onFilesSelected!(_selectedFiles);
    }
    
    if (widget.selectionConfig?.onSelectionConfirm != null && _selectedFiles.isNotEmpty) {
      widget.selectionConfig?.onSelectionConfirm!(_selectedFiles);
    }
  }

  void _handleCropCancelled() {
    setState(() {
      _showCropPanel = false;
      _croppableImageFiles = [];
    });
  }



  Future<void> _createFolder() async {
    if (_selectedProvider == null) {
      AppLogger.warning('Tentativa de criar pasta sem provedor selecionado', component: 'Folder');
      return;
    }

    final provider = _providers[_selectedProvider!]!;
    
    // Only check for account if provider requires it
    if (provider is AccountBasedProvider && _selectedAccount == null) {
      AppLogger.warning('Tentativa de criar pasta sem conta selecionada para provedor que requer conta', component: 'Folder');
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final provider = _providers[_selectedProvider!]!;
        if (provider is AccountBasedProvider) {
          provider.initialize(_selectedAccount!);
        }

        final currentFolderId = _navigationManager.currentFolderId;

        await provider.createFolder(
          name: result,
          parentId: currentFolderId,
        );

        // Refresh file list
        await _loadFiles(folderId: currentFolderId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pasta "$result" criada com sucesso!')),
          );
        }
      } catch (e) {
        AppLogger.error('Erro ao criar pasta', component: 'Folder', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao criar pasta: $e')),
          );
        }
      }
    }
  }

  void _handleNavigation(String action) {
    print('DEBUG: _handleNavigation called with action: $action');
    print('DEBUG: Estado atual do NavigationManager: $_navigationManager');
    
    switch (action) {
      case 'home':
        print('🔍 DEBUG: HOME NAVIGATION - Clearing history and going to root');
        print('🔍 DEBUG: Navigation state before: $_navigationManager');
        _navigationManager.goHome(
          providerType: _selectedProvider!,
          accountId: _selectedAccount!.id,
        );
        print('🔍 DEBUG: Navigation state after goHome: $_navigationManager');
        _loadFiles(skipNavigation: true);
        print('🔍 DEBUG: Home navigation completed');
        break;
      case 'back':
        print('DEBUG: Tentando voltar. CanGoBack: ${_navigationManager.canGoBack}');
        if (_navigationManager.canGoBack) {
          final entry = _navigationManager.goBack();
          print('DEBUG: Resultado do goBack: $entry');
          if (entry != null) {
            print('DEBUG: Carregando arquivos para folderId: ${entry.folderId} (skipNavigation=true)');
            _loadFiles(folderId: entry.folderId, skipNavigation: true);
          }
        }
        break;
      case 'forward':
        print('DEBUG: Tentando avançar. CanGoForward: ${_navigationManager.canGoForward}');
        if (_navigationManager.canGoForward) {
          final entry = _navigationManager.goForward();
          print('DEBUG: Resultado do goForward: $entry');
          if (entry != null) {
            print('DEBUG: Carregando arquivos para folderId: ${entry.folderId} (skipNavigation=true)');
            _loadFiles(folderId: entry.folderId, skipNavigation: true);
          }
        }
        break;
    }
    
    print('DEBUG: Estado após navegação: $_navigationManager');
  }

  Future<void> _uploadFiles() async {
    if (_selectedProvider == null) {
      AppLogger.warning('Upload cancelado: provedor não selecionado', component: 'Upload');
      return;
    }

    final provider = _providers[_selectedProvider!]!;
    
    // Only check for account if provider requires it
    if (provider is AccountBasedProvider && _selectedAccount == null) {
      AppLogger.warning('Upload cancelado: conta não selecionada para provedor que requer conta', component: 'Upload');
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true, // Force to load bytes data
      );

      if (result != null && result.files.isNotEmpty) {
        AppLogger.info('Iniciando upload de ${result.files.length} arquivo(s)', component: 'Upload');
        
        int successCount = 0;
        int failCount = 0;
        
        for (PlatformFile file in result.files) {
          AppLogger.info('Processando arquivo: ${file.name} (${file.size} bytes)', component: 'Upload');
          
          if (file.bytes != null && file.bytes!.isNotEmpty) {
            try {
              AppLogger.info('Iniciando upload do arquivo: ${file.name}', component: 'Upload');
              
              final uploadId = '${file.name}_${DateTime.now().millisecondsSinceEpoch}';
              
              // Create initial upload progress
              setState(() {
                _activeUploads[uploadId] = UploadProgress(
                  uploaded: 0,
                  total: file.bytes!.length,
                  fileName: file.name,
                  status: UploadStatus.uploading,
                );
              });
              
              Stream<List<int>> fileStream;
              int totalBytes = file.bytes!.length;
              int uploadedBytes = 0;
              
              if (_debugSlowUpload) {
                // Simulate slow upload by chunking the data and tracking progress manually
                fileStream = _createSlowUploadStreamWithProgress(file.bytes!, uploadId, totalBytes);
              } else {
                fileStream = Stream.value(file.bytes!);
              }
              
              // Upload file using bytes (works on all platforms)
              final uploadStream = provider.uploadFile(
                fileName: file.name,
                fileBytes: fileStream,
                parentId: _navigationManager.currentFolderId,
                mimeType: file.extension != null ? 'application/${file.extension}' : null,
              );
              
              if (_debugSlowUpload) {
                // In debug mode, we're manually tracking progress
                // Just wait for the final result
                await for (final progress in uploadStream) {
                  print('DEBUG: Progresso final do provider - ${progress.uploaded}/${progress.total} status: ${progress.status}');
                  
                  if (progress.isComplete) {
                    AppLogger.success('Upload concluído: ${file.name}', component: 'Upload');
                    setState(() {
                      _activeUploads[uploadId] = progress;
                    });
                    _uploadDialogUpdateCallback?.call();
                    successCount++;
                    break;
                  } else if (progress.status == UploadStatus.error) {
                    AppLogger.error('Erro no upload: ${file.name} - ${progress.error}', component: 'Upload');
                    setState(() {
                      _activeUploads[uploadId] = progress;
                    });
                    _uploadDialogUpdateCallback?.call();
                    failCount++;
                    break;
                  }
                }
              } else {
                // Normal mode - rely on provider progress
                // Listen to upload progress
                await for (final progress in uploadStream) {
                  print('DEBUG: Recebendo progresso - ${progress.uploaded}/${progress.total} status: ${progress.status}');
                  print('DEBUG: Progress médio antes: $_averageUploadProgress');
                  setState(() {
                    _activeUploads[uploadId] = progress;
                  });
                  print('DEBUG: Progress médio depois: $_averageUploadProgress');
                  print('DEBUG: Total uploads ativos: ${_activeUploads.length}');
                  
                  // Update upload dialog if it's open
                  print('DEBUG: Chamando callback do dialog');
                  _uploadDialogUpdateCallback?.call();
                  
                  AppLogger.info('Upload ${file.name}: ${progress.uploaded}/${progress.total} bytes', component: 'Upload');
                  if (progress.isComplete) {
                    AppLogger.success('Upload concluído: ${file.name}', component: 'Upload');
                    _uploadDialogUpdateCallback?.call();
                    successCount++;
                    break;
                  } else if (progress.status == UploadStatus.error) {
                    AppLogger.error('Erro no upload: ${file.name} - ${progress.error}', component: 'Upload');
                    _uploadDialogUpdateCallback?.call();
                    failCount++;
                    break;
                  }
                }
              }
            } catch (e) {
              AppLogger.error('Erro ao fazer upload do arquivo ${file.name}', component: 'Upload', error: e);
              failCount++;
            }
          } else {
            AppLogger.warning('Ignorando arquivo ${file.name}: bytes não disponíveis (size: ${file.size})', component: 'Upload');
            failCount++;
          }
        }
        
        if (mounted) {
          String message;
          Color backgroundColor;
          
          if (successCount > 0 && failCount == 0) {
            message = '$successCount arquivo(s) enviado(s) com sucesso!';
            backgroundColor = Colors.green;
          } else if (successCount > 0 && failCount > 0) {
            message = '$successCount arquivo(s) enviado(s) com sucesso, $failCount falharam.';
            backgroundColor = Colors.orange;
          } else if (failCount > 0) {
            message = '$failCount arquivo(s) falharam no upload.';
            backgroundColor = Colors.red;
          } else {
            message = 'Nenhum arquivo foi enviado.';
            backgroundColor = Colors.grey;
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: backgroundColor,
            ),
          );
          
          // Auto-clear completed uploads after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _clearCompletedUploads();
            }
          });
          
          // Refresh the file list if any file was uploaded successfully
          if (successCount > 0) {
            await _loadFiles();
          }
        }
      } else {
        AppLogger.info('Nenhum arquivo selecionado', component: 'Upload');
      }
    } catch (e) {
      AppLogger.error('Erro geral no upload de arquivos', component: 'Upload', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar arquivos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUploadList() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Register callback to update dialog from outside
          _uploadDialogUpdateCallback = () {
            print('DEBUG: Tentando atualizar dialog, mounted: ${context.mounted}');
            if (context.mounted) {
              setDialogState(() {
                print('DEBUG: Atualizando estado do dialog');
              });
            }
          };
          
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.upload),
                const SizedBox(width: 8),
                Text('Uploads (${_activeUploadsCount})'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: _activeUploads.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Nenhum upload em andamento'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _activeUploads.length,
                      itemBuilder: (context, index) {
                        final uploadId = _activeUploads.keys.elementAt(index);
                        final progress = _activeUploads[uploadId]!;
                        return _buildUploadItem(progress);
                      },
                    ),
            ),
            actions: [
              if (_activeUploads.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _clearCompletedUploads();
                    setDialogState(() {}); // Update dialog
                    Navigator.of(context).pop();
                  },
                  child: const Text('Limpar Concluídos'),
                ),
              TextButton(
                onPressed: () {
                  _uploadDialogUpdateCallback = null; // Clear callback
                  Navigator.of(context).pop();
                },
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      // Clear callback when dialog is closed
      _uploadDialogUpdateCallback = null;
    });
  }

  Widget _buildUploadItem(UploadProgress progress) {
    final percentage = progress.total > 0 
        ? (progress.uploaded / progress.total * 100).round()
        : 0;
    
    final statusIcon = switch (progress.status) {
      UploadStatus.waiting => const Icon(Icons.schedule, color: Colors.grey),
      UploadStatus.uploading => const Icon(Icons.cloud_upload, color: Colors.blue),
      UploadStatus.completed => const Icon(Icons.check_circle, color: Colors.green),
      UploadStatus.error => const Icon(Icons.error, color: Colors.red),
      UploadStatus.paused => const Icon(Icons.pause_circle, color: Colors.orange),
      UploadStatus.cancelled => const Icon(Icons.cancel, color: Colors.grey),
      UploadStatus.retrying => const Icon(Icons.refresh, color: Colors.orange),
    };

    final statusText = switch (progress.status) {
      UploadStatus.waiting => 'Aguardando',
      UploadStatus.uploading => '$percentage%',
      UploadStatus.completed => 'Concluído',
      UploadStatus.error => 'Erro',
      UploadStatus.paused => 'Pausado',
      UploadStatus.cancelled => 'Cancelado',
      UploadStatus.retrying => 'Tentando novamente',
    };

    return Card(
      child: ListTile(
        leading: statusIcon,
        title: Text(
          progress.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (progress.status == UploadStatus.uploading) ...[
              LinearProgressIndicator(value: progress.total > 0 ? progress.uploaded / progress.total : 0),
              const SizedBox(height: 4),
              Text('${_formatBytes(progress.uploaded)} / ${_formatBytes(progress.total)}'),
              if (progress.speed != null)
                Text('${_formatBytes(progress.speed!.round())}/s'),
            ] else ...[
              Text(statusText),
              if (progress.error != null)
                Text(
                  progress.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ],
        ),
        trailing: progress.status == UploadStatus.uploading
            ? IconButton(
                icon: const Icon(Icons.cancel),
                onPressed: () {
                  // TODO: Implementar cancelamento de upload
                },
              )
            : null,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  void _clearCompletedUploads() {
    setState(() {
      _activeUploads.removeWhere((key, progress) => 
          progress.status == UploadStatus.completed ||
          progress.status == UploadStatus.error ||
          progress.status == UploadStatus.cancelled);
    });
    
    // Update upload dialog if it's open
    _uploadDialogUpdateCallback?.call();
    
    AppLogger.info('Uploads concluídos removidos. Uploads ativos restantes: ${_activeUploads.length}', component: 'Upload');
  }

  Stream<List<int>> _createSlowUploadStreamWithProgress(List<int> bytes, String uploadId, int totalBytes) async* {
    const chunkSize = 1024 * 4; // 4KB chunks
    const delayBetweenChunks = Duration(milliseconds: 100); // 100ms delay
    int uploadedBytes = 0;
    
    AppLogger.info('Criando stream de upload lento com progresso: ${bytes.length} bytes em chunks de ${chunkSize}B', component: 'Upload');
    
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(i, end);
      uploadedBytes += chunk.length;
      
      // Update progress manually BEFORE yielding the chunk
      setState(() {
        _activeUploads[uploadId] = UploadProgress(
          uploaded: uploadedBytes,
          total: totalBytes,
          fileName: _activeUploads[uploadId]?.fileName ?? 'unknown',
          status: uploadedBytes >= totalBytes ? UploadStatus.completed : UploadStatus.uploading,
        );
      });
      
      // Update dialog
      _uploadDialogUpdateCallback?.call();
      
      AppLogger.debug('Enviando chunk ${i ~/ chunkSize + 1}: ${chunk.length} bytes (${uploadedBytes}/${totalBytes})', component: 'Upload');
      print('DEBUG: Progresso manual atualizado: $uploadedBytes/$totalBytes');
      
      yield chunk;
      
      // Add delay to simulate slow upload
      if (i + chunkSize < bytes.length) {
        await Future.delayed(delayBetweenChunks);
      }
    }
    
    AppLogger.info('Stream de upload lento concluído', component: 'Upload');
  }

  Stream<List<int>> _createSlowUploadStream(List<int> bytes) async* {
    const chunkSize = 1024 * 4; // 4KB chunks
    const delayBetweenChunks = Duration(milliseconds: 100); // 100ms delay
    
    AppLogger.info('Criando stream de upload lento: ${bytes.length} bytes em chunks de ${chunkSize}B', component: 'Upload');
    
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(i, end);
      
      AppLogger.debug('Enviando chunk ${i ~/ chunkSize + 1}: ${chunk.length} bytes', component: 'Upload');
      yield chunk;
      
      // Add delay to simulate slow upload
      if (i + chunkSize < bytes.length) {
        await Future.delayed(delayBetweenChunks);
      }
    }
    
    AppLogger.info('Stream de upload lento concluído', component: 'Upload');
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Set context for navigation manager to use translations
    _navigationManager.setContext(context);
    
    // Show crop panel if active
    if (_showCropPanel) {
      print('🔍 DEBUG build - crop panel:');
      print('   - _croppableImageFiles count: ${_croppableImageFiles.length}');
      print('   - _croppableImageFiles names: ${_croppableImageFiles.map((f) => f.name).toList()}');
      
      return CropPanelWidget(
        imageFiles: _croppableImageFiles,
        cropConfig: widget.cropConfig,
        onCropCompleted: _handleCropCompleted,
        onCancel: _handleCropCancelled,
      );
    }
    
    return Stack(
      children: [
        Container(
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
        ),
        
        // Drag & Drop Overlay (simplified)
        // TODO: Implement proper drag & drop detection
        const SizedBox.shrink(),
      ],
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
                  customLogoWidget: ProviderHelper.getCustomLogoWidget(providerType),
                  showAccountCount: ProviderHelper.getShowAccountManagement(providerType),
                  onTap: () {
                    setState(() {
                      _selectedProvider = providerType;
                      _selectedAccount = null;
                      _currentFiles.clear();
                      _pathStack.clear();
                    });
                    // Reset navigation history when changing provider
                    _navigationManager.clearHistory();
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
    final showAccountManagement = ProviderHelper.getShowAccountManagement(_selectedProvider ?? '');
    
    return Column(
      children: [
        // Seção de contas com altura fixa e sem overflow - apenas se showAccountManagement for true
        if (showAccountManagement) _buildAccountSection(),
        
        // Divisor horizontal - apenas se showAccountManagement for true
        if (showAccountManagement) Container(
          height: 1,
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        
        // Navigation bar (nova adição)
        if (_selectedProvider != null && (_selectedAccount != null || 
            (_providers[_selectedProvider]! is! AccountBasedProvider)))
          NavigationBarWidget(
            navigationHistory: _navigationManager.history,
            onGoHome: () {
              print('🔍 DEBUG: HOME BUTTON CLICKED - calling _handleNavigation(home)');
              _handleNavigation('home');
            },
            onGoBack: _navigationManager.canGoBack ? () => _handleNavigation('back') : null,
            onGoForward: _navigationManager.canGoForward ? () => _handleNavigation('forward') : null,
            onBreadcrumbTap: (index) {
              print('🔍 DEBUG: BREADCRUMB CLICKED - index: $index');
              
              // Special case: if clicking on index 0 (Home), clear history first
              if (index == 0) {
                print('🔍 DEBUG: BREADCRUMB HOME (index 0) - calling goHome instead');
                _handleNavigation('home');
              } else {
                print('🔍 DEBUG: BREADCRUMB - navigating to index: $index');
                final entry = _navigationManager.navigateToIndex(index);
                if (entry != null) {
                  _loadFiles(folderId: entry.folderId, skipNavigation: true);
                }
              }
            },
            onCreateFolder: _createFolder,
            onUpload: _uploadFiles,
            onViewUploads: _showUploadList,
            activeUploadsCount: _activeUploadsCount,
            uploadProgress: _averageUploadProgress,
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
                      // Reset navigation history when changing account
                      _navigationManager.clearHistory();
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
    // Check if provider requires account
    final provider = _providers[_selectedProvider]!;
    final requiresAccount = provider is AccountBasedProvider;
    
    if (requiresAccount && _selectedAccount == null) {
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
    
    // For serverless providers, we can proceed without an account
    if (!requiresAccount && _selectedProvider == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Selecione um provedor para navegar nos arquivos'),
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





  Widget _buildFileItem(FileEntry file) {
    final isSelected = _selectedFiles.contains(file);
    
    // Debug logging
    print('🔍 DEBUG: Building file item for: ${file.name}');
    print('   - isFolder: ${file.isFolder}');
    print('   - mimeType: ${file.mimeType}');
    
    // Check if this is an image file - always use ImageFileItemCard for images
    if (!file.isFolder) {
      print('   - Checking if image...');
      final imageEntry = ImageFileEntry.tryCreateImageFileEntry(file);
      print('   - imageEntry created: ${imageEntry != null}');
      if (imageEntry != null) {
        print('   - Using ImageFileItemCard');
        return ImageFileItemCard(
          imageEntry: imageEntry,
          isSelected: isSelected,
          showCheckbox: widget.selectionConfig != null,
          onTap: () {
            if (widget.selectionConfig != null) {
              _toggleFileSelection(file);
            }
          },
          onCheckboxChanged: widget.selectionConfig != null 
              ? (_) => _toggleFileSelection(file)
              : null,
        );
      }
    }
    
    print('   - Using standard FileItemCard');
    // Default to standard FileItemCard
    return FileItemCard(
      file: file,
      isSelected: isSelected,
      showCheckbox: widget.selectionConfig != null,
      onTap: () {
        if (file.isFolder) {
          // Always navigate into folders when clicked
          _loadFiles(folderId: file.id, folderName: file.name);
        } else if (widget.selectionConfig != null) {
          // Only toggle selection for files when in selection mode
          _toggleFileSelection(file);
        }
      },
      onCheckboxChanged: widget.selectionConfig != null 
          ? (_) => _toggleFileSelection(file)
          : null,
    );
  }

  String _getLocalizedText(String fallback, String Function(AppLocalizations) localizationGetter) {
    try {
      // Use Localizations.of directly to avoid the null assertion in AppLocalizations.of
      final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
      if (localizations != null) {
        return localizationGetter(localizations);
      }
    } catch (e, stackTrace) {
      debugPrint('Localization error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    return fallback;
  }

  String _getRootFolderName(BuildContext context) {
    return _getLocalizedText('Root Folder', (l) => l.rootFolder);
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
            child: const Text('Cancelar'),
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