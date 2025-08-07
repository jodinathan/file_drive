/// Provider content area widget
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';
import 'auth_screen.dart';

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
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 40,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Conectado com Sucesso!',
              style: widget.theme.typography.title.copyWith(
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Autenticação OAuth realizada com ${widget.provider!.providerName}',
              textAlign: TextAlign.center,
              style: widget.theme.typography.body.copyWith(
                color: widget.theme.colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            _buildConnectionInfo(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => _testConnection(),
                  child: const Text('Testar Conexão'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => widget.provider!.logout(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Desconectar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(widget.theme.layout.borderRadius),
        border: Border.all(
          color: widget.theme.colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: widget.theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Informações da Conexão',
                style: widget.theme.typography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Provedor', widget.provider!.providerName),
          _buildInfoRow('Status', 'Autenticado'),
          _buildInfoRow('Token', 'Válido'),
          // Additional info for OAuth providers
          _buildInfoRow('Tipo', 'OAuth 2.0'),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: widget.theme.typography.caption.copyWith(
                color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Text(
            value,
            style: widget.theme.typography.caption.copyWith(
              color: widget.theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  void _testConnection() async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Testando conexão...'),
        backgroundColor: widget.theme.colorScheme.primary,
      ),
    );
    
    try {
      final isValid = await widget.provider!.validateAuth();
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isValid ? 'Conexão válida!' : 'Falha na conexão',
          ),
          backgroundColor: isValid ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao testar conexão'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
