import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_cloud/file_cloud.dart';
import 'package:file_cloud/src/providers/local_server_provider.dart';
import 'package:file_cloud/src/providers/google_drive_provider.dart';
import 'package:file_cloud/src/models/oauth_provider_configuration.dart';
import 'package:file_cloud/src/models/ready_provider_configuration.dart';

// Tente importar config.dart, senão use valores de exemplo
import 'config.dart' deferred as config;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Carrega a configuração
  try {
    await config.loadLibrary();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️  config.dart não encontrado, usando configuração de exemplo');
      debugPrint('📝 Copie lib/config.example.dart para lib/config.dart e configure');
    }
  }
  
  runApp(const FileCloudExampleApp());
}

class FileCloudExampleApp extends StatelessWidget {
  const FileCloudExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Cloud Example',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(brightness: Brightness.light),
      darkTheme: AppTheme.getTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AccountStorage _accountStorage;
  late final List<BaseProviderConfiguration> _providers;
  bool _isLoading = true;
  String? _error;
  bool _showInstructions = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      _accountStorage = SharedPreferencesAccountStorage();
      
      // Configure providers with proper server URLs
      String serverBaseUrl = 'http://localhost:8080';
      String redirectScheme = 'com.example.filedrive://';
      
      try {
        // Try to use config if available
        serverBaseUrl = config.AppConfig.serverBaseUrl;
        final customScheme = config.AppConfig.customScheme;
        // Use the scheme as is from config
        redirectScheme = customScheme;
      } catch (e) {
        // Use defaults if config not available
      }
      
      // Create provider configurations using ReadyProviderConfiguration to avoid factory conflicts
      _providers = <BaseProviderConfiguration>[
        ReadyProviderConfiguration.fromProvider(
          providerInstance: GoogleDriveProvider(
            oauthConfiguration: OAuthProviderConfiguration(
              type: CloudProviderType.googleDrive,
              displayName: 'Google Drive',
              capabilities: const {
                ProviderCapability.upload,
                ProviderCapability.createFolders,
                ProviderCapability.delete,
                ProviderCapability.search,
                ProviderCapability.thumbnails,
                ProviderCapability.share,
                ProviderCapability.move,
                ProviderCapability.copy,
                ProviderCapability.rename,
              },
              authUrlGenerator: (state) => Uri.parse('$serverBaseUrl/auth/google?state=$state'),
              tokenUrlGenerator: (state) => Uri.parse('$serverBaseUrl/auth/tokens/$state'),
              redirectScheme: redirectScheme,
              scopes: ['https://www.googleapis.com/auth/drive.file', 'https://www.googleapis.com/auth/drive.metadata'],
            ),
          ),
          configurationId: 'google_drive_main',
        ),
        // Add more providers if needed
        ReadyProviderConfiguration.fromProvider(
          providerInstance: LocalServerProvider(
            configuration: const LocalServerProviderConfig(
              displayName: 'Local Development Server',
            ),
          ),
          configurationId: 'local_server_main',
        ),
      ];
      
      // Test server connectivity
      await _testServerConnection();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Initialize providers with empty list on error to prevent LateInitializationError
      _providers = <BaseProviderConfiguration>[];
      print('❌ Erro ao inicializar: $e');
      if (mounted) {
        setState(() {
          _error = 'Erro ao inicializar: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeAllAccounts() async {
    // Mostrar dialog de confirmação
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Remover Todas as Contas'),
          ],
        ),
        content: const Text(
          'Esta ação removerá TODAS as contas salvas, independente do status. '
          'Esta operação não pode ser desfeita.\n\n'
          'Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remover Todas'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Buscar todas as contas para mostrar a contagem
        final accounts = await _accountStorage.getAccounts();
        
        if (accounts.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Nenhuma conta encontrada para remover.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final accountCount = accounts.length;

        // Usar clearAll() para remover todas as contas de uma vez
        await _accountStorage.clearAll();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$accountCount contas removidas com sucesso!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
        
        // Forçar rebuild do widget para refletir as mudanças
        setState(() {});
        
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover contas: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _testServerConnection() async {
    // Simple test to see if server is running
    // This will throw if server is not accessible
    try {
      // You could add a simple HTTP test here if needed
      // For now, we'll assume it's working if config exists
    } catch (e) {
      _showInstructions = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Cloud Example'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        actions: [
          // Menu de três pontos com opções de exemplo
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'remove_accounts':
                  _removeAllAccounts();
                  break;
                case 'toggle_instructions':
                  setState(() {
                    _showInstructions = !_showInstructions;
                  });
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'remove_accounts',
                child: const Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Remover Todas as Contas'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'toggle_instructions',
                child: Row(
                  children: [
                    Icon(_showInstructions ? Icons.dashboard : Icons.help_outline),
                    const SizedBox(width: 8),
                    Text(_showInstructions ? 'Mostrar Widget' : 'Mostrar Instruções'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando...'),
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
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                _initializeApp();
              },
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    // Show instructions if config is missing or user requested
    if (_showInstructions) {
      return _buildInstructions();
    }

    // Show the actual File Cloud widget
    return _buildFileCloudWidget();
  }

  Widget _buildFileCloudWidget() {
    return FileCloudWidget(
      providers: _providers,
      accountStorage: _accountStorage,
      cropConfig: CropConfig.custom(
        aspectRatio: 9.0 / 6.0,
        minWidth: 500,
        minHeight: 300,
        enforceAspectRatio: true,
      ),
      selectionConfig: SelectionConfig(
        minSelection: 1,
        maxSelection: 5,
        allowFolders: false,
        allowedMimeTypes: ['image/*', 'application/pdf', 'text/*'],
        mimeTypeHint: 'You can select images, PDF documents, and text files',
        onSelectionConfirm: (files) {
          // Show selected files in a dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('${files.length} arquivos selecionados'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: files.map((file) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        file.isFolder ? Icons.folder : Icons.description,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(file.name)),
                    ],
                  ),
                )).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${files.length} arquivos selecionados!'),
                      ),
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
      ),
      onFilesSelected: (files) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${files.length} arquivos selecionados via callback!'),
          ),
        );
      },
    );
  }

  Widget _buildInstructions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Configuration instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Configuração Necessária',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Para testar o File Cloud widget, você precisa:\n\n'
                    '1. 🔧 Configurar credenciais Google OAuth2\n'
                    '2. 🖥️  Iniciar o servidor OAuth (../server/)\n'
                    '3. 📱 Configurar o arquivo config.dart\n\n'
                    'Veja as instruções detalhadas no README.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showInstructions = false;
                      });
                    },
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Tentar Usar Widget Mesmo Assim'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Demo components
          Text(
            'Demonstração dos Componentes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          
          const SizedBox(height: 16),
          
          _buildAccountExample(),
          const SizedBox(height: 16),
          _buildFileExample(),
          const SizedBox(height: 16),
          _buildCapabilitiesExample(),
        ],
      ),
    );
  }

  Widget _buildAccountExample() {
    final account = CloudAccount(
      id: 'example-1',
      providerType: CloudProviderType.googleDrive.name,
      externalId: 'user@example.com',
      accessToken: 'example-token',
      name: 'João Silva',
      email: 'joao@example.com',
      photoUrl: null,
      status: AccountStatus.ok,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CloudAccount Example',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  account.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              title: Text(account.name),
              subtitle: Text(account.email),
              trailing: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.getStatusColor(
                    Theme.of(context).colorScheme,
                    account.status.value,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileExample() {
    final file = FileEntry(
      id: 'example-file-1',
      name: 'Documento.pdf',
      isFolder: false,
      size: 1024 * 1024, // 1MB
      mimeType: 'application/pdf',
      modifiedAt: DateTime.now().subtract(const Duration(hours: 2)),
      canDownload: true,
      canDelete: true,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FileEntry Example',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                file.isFolder ? Icons.folder : Icons.description,
                color: AppTheme.getFileTypeColor(
                  Theme.of(context).colorScheme,
                  file.mimeType,
                ),
              ),
              title: Text(file.name),
              subtitle: Text(
                file.size != null
                    ? '${(file.size! / 1024 / 1024).toStringAsFixed(1)} MB'
                    : 'Pasta',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (file.canDownload)
                    const Icon(Icons.download, size: 16, color: Colors.green),
                  if (file.canDelete)
                    const SizedBox(width: 4),
                  if (file.canDelete)
                    const Icon(Icons.delete, size: 16, color: Colors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilitiesExample() {
    const capabilities = ProviderCapabilities(
      canUpload: true,     
      canCreateFolders: true,
      canDelete: true,
      canSearch: true,
      canChunkedUpload: true,
      hasThumbnails: true,
      maxPageSize: 50,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ProviderCapabilities Example',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCapabilityChip('Upload', capabilities.canUpload),
                _buildCapabilityChip('Pastas', capabilities.canCreateFolders),
                _buildCapabilityChip('Excluir', capabilities.canDelete),
                _buildCapabilityChip('Buscar', capabilities.canSearch),
                _buildCapabilityChip('Thumbnails', capabilities.hasThumbnails),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityChip(String label, bool enabled) {
    return Chip(
      label: Text(label),
      backgroundColor: enabled
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      side: BorderSide(
        color: enabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
    );
  }
}