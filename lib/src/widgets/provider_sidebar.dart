/// Provider sidebar widget
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';
import 'provider_tab.dart';

/// Sidebar widget showing list of available providers
class ProviderSidebar extends StatelessWidget {
  final List<CloudProvider> providers;
  final CloudProvider? selectedProvider;
  final Function(CloudProvider) onProviderSelected;
  final FileDriveTheme theme;
  
  const ProviderSidebar({
    Key? key,
    required this.providers,
    required this.selectedProvider,
    required this.onProviderSelected,
    required this.theme,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _buildProviderList(),
          ),
          _buildFooter(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: theme.layout.padding,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_queue,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Provedores',
            style: theme.typography.title.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProviderList() {
    if (providers.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        vertical: theme.layout.spacing / 2,
      ),
      shrinkWrap: true,
      itemCount: providers.length,
      itemBuilder: (context, index) {
        final provider = providers[index];
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.layout.spacing / 2,
            vertical: 2,
          ),
          child: ProviderTab(
            provider: provider,
            isSelected: provider == selectedProvider,
            onTap: () => onProviderSelected(provider),
            theme: theme,
          ),
        );
      },
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: theme.layout.padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum provedor\nconfigurado',
              textAlign: TextAlign.center,
              style: theme.typography.body.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFooter() {
    return Container(
      padding: theme.layout.padding,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '${providers.length} ${providers.length == 1 ? 'provedor' : 'provedores'}',
              style: theme.typography.caption.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          if (selectedProvider != null)
            _buildConnectionIndicator(),
        ],
      ),
    );
  }
  
  Widget _buildConnectionIndicator() {
    final provider = selectedProvider!;
    
    return StreamBuilder<ProviderStatus>(
      stream: provider.statusStream,
      initialData: provider.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ProviderStatus.disconnected;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIcon(status),
            const SizedBox(width: 4),
            Text(
              _getStatusText(status),
              style: theme.typography.caption.copyWith(
                color: _getStatusColor(status),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildStatusIcon(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.connected:
        return Icon(
          Icons.check_circle,
          size: 16,
          color: Colors.green,
        );
      case ProviderStatus.connecting:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        );
      case ProviderStatus.error:
        return Icon(
          Icons.error,
          size: 16,
          color: Colors.red,
        );
      case ProviderStatus.tokenExpired:
        return Icon(
          Icons.access_time,
          size: 16,
          color: Colors.orange,
        );
      case ProviderStatus.needsReauth:
        return Icon(
          Icons.warning,
          size: 16,
          color: Colors.orange,
        );
      default:
        return Icon(
          Icons.cloud_off,
          size: 16,
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        );
    }
  }
  
  String _getStatusText(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.connected:
        return 'Conectado';
      case ProviderStatus.connecting:
        return 'Conectando...';
      case ProviderStatus.error:
        return 'Erro';
      case ProviderStatus.tokenExpired:
        return 'Expirado';
      case ProviderStatus.needsReauth:
        return 'Requer reauth';
      default:
        return 'Desconectado';
    }
  }
  
  Color _getStatusColor(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.connected:
        return Colors.green;
      case ProviderStatus.connecting:
        return theme.colorScheme.primary;
      case ProviderStatus.error:
        return Colors.red;
      case ProviderStatus.tokenExpired:
        return Colors.orange;
      case ProviderStatus.needsReauth:
        return Colors.orange;
      default:
        return theme.colorScheme.onSurface.withOpacity(0.6);
    }
  }
}

/// Compact provider selector for mobile
class CompactProviderSelector extends StatelessWidget {
  final List<CloudProvider> providers;
  final CloudProvider? selectedProvider;
  final Function(CloudProvider) onProviderSelected;
  final FileDriveTheme theme;
  
  const CompactProviderSelector({
    Key? key,
    required this.providers,
    required this.selectedProvider,
    required this.onProviderSelected,
    required this.theme,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: theme.layout.spacing),
      child: DropdownButton<CloudProvider>(
        value: selectedProvider,
        isExpanded: true,
        hint: const Text('Selecione um provedor'),
        items: providers.map((provider) {
          return DropdownMenuItem<CloudProvider>(
            value: provider,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: provider.providerColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(provider.providerName),
              ],
            ),
          );
        }).toList(),
        onChanged: (provider) {
          if (provider != null) {
            onProviderSelected(provider);
          }
        },
      ),
    );
  }
}
