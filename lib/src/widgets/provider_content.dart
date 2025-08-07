/// Provider content area widget
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';
import 'auth_screen.dart';
import 'file_explorer.dart';

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
  
  Widget _buildErrorState() {
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
            Text(
              'Não foi possível conectar com ${widget.provider!.providerName}',
              textAlign: TextAlign.center,
              style: widget.theme.typography.body.copyWith(
                color: widget.theme.colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => widget.provider!.authenticate(),
                  child: const Text('Tentar Novamente'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => widget.provider!.logout(),
                  child: const Text('Resetar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAuthenticatedState() {
    // Show FileExplorer directly after successful authentication
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
