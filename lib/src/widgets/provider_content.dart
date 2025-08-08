/// Provider content area widget
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';
import '../providers/base/oauth_cloud_provider.dart';
import 'auth_screen.dart';
import 'file_explorer.dart';
import 'account_list.dart';

/// Content area showing provider-specific content
class ProviderContent extends StatefulWidget {
  final CloudProvider? provider;
  final FileDriveTheme theme;
  final Function(List<String>)? onFilesSelected;
  
  const ProviderContent({
    Key? key,
    required this.provider,
    required this.theme,
    this.onFilesSelected,
  }) : super(key: key);
  
  @override
  State<ProviderContent> createState() => _ProviderContentState();
}

class _ProviderContentState extends State<ProviderContent> {
  @override
  Widget build(BuildContext context) {
    if (widget.provider == null) {
      return _buildEmptyState();
    }
    
    return Material(
      color: widget.theme.colorScheme.background,
      child: StreamBuilder<ProviderStatus>(
        stream: widget.provider!.statusStream,
        initialData: widget.provider!.status,
        builder: (context, snapshot) {
          final status = snapshot.data ?? ProviderStatus.disconnected;
          
          switch (status) {
            case ProviderStatus.connected:
              return _buildAuthenticatedState();
            case ProviderStatus.connecting:
              return _buildConnectingState();
            case ProviderStatus.error:
              return _buildErrorState();
            case ProviderStatus.needsReauth:
              return _buildReauthState();
            default:
              return _buildAuthenticationScreen();
          }
        },
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      color: widget.theme.colorScheme.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: widget.theme.colorScheme.onBackground.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Selecione um provedor',
              style: widget.theme.typography.title.copyWith(
                color: widget.theme.colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha um provedor na barra lateral\npara começar a gerenciar seus arquivos',
              textAlign: TextAlign.center,
              style: widget.theme.typography.body.copyWith(
                color: widget.theme.colorScheme.onBackground.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAuthenticationScreen() {
    return AuthenticationScreen(
      provider: widget.provider!,
      theme: widget.theme,
    );
  }
  
  Widget _buildConnectingState() {
    return Container(
      color: widget.theme.colorScheme.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: widget.provider!.providerColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.cloud,
                    size: 40,
                    color: widget.provider!.providerColor,
                  ),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.provider!.providerColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Conectando...',
              style: widget.theme.typography.title.copyWith(
                color: widget.theme.colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Autenticando com ${widget.provider!.providerName}',
              style: widget.theme.typography.body.copyWith(
                color: widget.theme.colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReauthState() {
    final isOAuthProvider = widget.provider is OAuthCloudProvider;
    
    if (isOAuthProvider) {
      // Para provedores OAuth: Row com lista de contas + painel de permissões
      return Row(
        children: [
          // Lista de contas (coluna esquerda)
          AccountList(
            provider: widget.provider as OAuthCloudProvider,
            theme: widget.theme,
            width: 250,
          ),
          
          // Painel de permissões insuficientes (coluna direita)
          Expanded(
            child: _buildReauthPanel(),
          ),
        ],
      );
    } else {
      // Para provedores não-OAuth: apenas o painel central
      return _buildReauthPanel();
    }
  }

  Widget _buildReauthPanel() {
    return Container(
      color: widget.theme.colorScheme.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.warning_outlined,
                size: 40,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Permissões Insuficientes',
              style: widget.theme.typography.title.copyWith(
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            // Show current user info
            FutureBuilder<Map<String, dynamic>?>(
              future: widget.provider!.getUserInfo(),
              builder: (context, snapshot) {
                final userInfo = snapshot.data;
                final userDisplay = userInfo != null 
                    ? (userInfo['name'] ?? userInfo['email'] ?? 'Conta conectada')
                    : 'Conta conectada';
                
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (userInfo?['picture'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                userInfo!['picture'],
                                width: 32,
                                height: 32,
                                errorBuilder: (context, error, stackTrace) {
                                  return CircleAvatar(
                                    radius: 16,
                                    backgroundColor: widget.provider!.providerColor,
                                    child: Text(
                                      userDisplay[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: widget.provider!.providerColor,
                              child: Text(
                                userDisplay.isNotEmpty ? userDisplay[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              userDisplay,
                              style: widget.theme.typography.body.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Esta conta precisa de permissões adicionais para acessar o ${widget.provider!.providerName}.\nÉ necessário refazer o login com as permissões corretas.',
                      textAlign: TextAlign.center,
                      style: widget.theme.typography.body.copyWith(
                        color: widget.theme.colorScheme.onBackground.withOpacity(0.6),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => widget.provider!.authenticate(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refazer Login'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorState() {
    final isOAuthProvider = widget.provider is OAuthCloudProvider;
    
    if (isOAuthProvider) {
      // Para provedores OAuth: Row com lista de contas + painel de erro
      return Row(
        children: [
          // Lista de contas (coluna esquerda)
          AccountList(
            provider: widget.provider as OAuthCloudProvider,
            theme: widget.theme,
            width: 250,
          ),
          
          // Painel de erro (coluna direita)
          Expanded(
            child: _buildErrorPanel(),
          ),
        ],
      );
    } else {
      // Para provedores não-OAuth: apenas o painel central
      return _buildErrorPanel();
    }
  }

  Widget _buildErrorPanel() {
    return Container(
      color: widget.theme.colorScheme.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Erro de Conexão',
              style: widget.theme.typography.title.copyWith(
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            // Show current user info
            FutureBuilder<Map<String, dynamic>?>(
              future: widget.provider!.getUserInfo(),
              builder: (context, snapshot) {
                final userInfo = snapshot.data;
                final userDisplay = userInfo != null 
                    ? (userInfo['name'] ?? userInfo['email'] ?? 'Conta conectada')
                    : 'Conta conectada';
                
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (userInfo?['picture'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                userInfo!['picture'],
                                width: 32,
                                height: 32,
                                errorBuilder: (context, error, stackTrace) {
                                  return CircleAvatar(
                                    radius: 16,
                                    backgroundColor: widget.provider!.providerColor,
                                    child: Text(
                                      userDisplay.isNotEmpty ? userDisplay[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: widget.provider!.providerColor,
                              child: Text(
                                userDisplay.isNotEmpty ? userDisplay[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              userDisplay,
                              style: widget.theme.typography.body.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Não foi possível conectar com ${widget.provider!.providerName}',
                      textAlign: TextAlign.center,
                      style: widget.theme.typography.body.copyWith(
                        color: widget.theme.colorScheme.onBackground.withOpacity(0.6),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => widget.provider!.authenticate(),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAuthenticatedState() {
    // Verificar se é um provedor OAuth
    final isOAuthProvider = widget.provider is OAuthCloudProvider;
    
    if (isOAuthProvider) {
      // Para provedores OAuth: Row com lista de contas + conteúdo principal
      return Row(
        children: [
          // Lista de contas (coluna esquerda)
          AccountList(
            provider: widget.provider as OAuthCloudProvider,
            theme: widget.theme,
            width: 250,
          ),
          
          // Conteúdo principal (coluna direita)
          Expanded(
            child: FileExplorer(
              provider: widget.provider!,
              selectionConfig: const FileSelectionConfig(
                allowMultipleSelection: true,
                allowFolderSelection: true,
              ),
              onFilesSelected: widget.onFilesSelected != null 
                ? (files) => widget.onFilesSelected!(files.map((f) => f.id).toList())
                : null,
            ),
          ),
        ],
      );
    } else {
      // Para provedores não-OAuth: apenas o FileExplorer
      return FileExplorer(
        provider: widget.provider!,
        selectionConfig: const FileSelectionConfig(
          allowMultipleSelection: true,
          allowFolderSelection: true,
        ),
        onFilesSelected: widget.onFilesSelected != null 
          ? (files) => widget.onFilesSelected!(files.map((f) => f.id).toList())
          : null,
      );
    }
  }
}
