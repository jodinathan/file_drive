/// Individual provider tab widget
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';

/// Individual provider tab in the sidebar
class ProviderTab extends StatefulWidget {
  final CloudProvider provider;
  final bool isSelected;
  final VoidCallback onTap;
  final FileDriveTheme theme;
  
  const ProviderTab({
    Key? key,
    required this.provider,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  }) : super(key: key);
  
  @override
  State<ProviderTab> createState() => _ProviderTabState();
}

class _ProviderTabState extends State<ProviderTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProviderStatus>(
      stream: widget.provider.statusStream,
      initialData: widget.provider.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ProviderStatus.disconnected;
        
        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: _buildTab(status),
            );
          },
        );
      },
    );
  }
  
  Widget _buildTab(ProviderStatus status) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) => _animationController.reverse(),
        onTapCancel: () => _animationController.reverse(),
        borderRadius: BorderRadius.circular(widget.theme.layout.borderRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getBackgroundColor(status),
            borderRadius: BorderRadius.circular(widget.theme.layout.borderRadius),
            border: widget.isSelected
                ? Border.all(
                    color: widget.provider.providerColor,
                    width: 2,
                  )
                : Border.all(
                    color: Colors.transparent,
                    width: 2,
                  ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.provider.providerColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _buildProviderIcon(status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.provider.providerName,
                      style: widget.theme.typography.body.copyWith(
                        fontWeight: widget.isSelected 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                        color: _getTextColor(status),
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildStatusIndicator(status),
                  ],
                ),
              ),
              if (widget.isSelected)
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: widget.provider.providerColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProviderIcon(ProviderStatus status) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.provider.providerColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.provider.providerColor.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.cloud,
            color: Colors.white,
            size: 20,
          ),
        ),
        if (status == ProviderStatus.connecting)
          Positioned.fill(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.provider.providerColor,
              ),
            ),
          ),
        if (status == ProviderStatus.error)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        if (status == ProviderStatus.connected)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildStatusIndicator(ProviderStatus status) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getStatusColor(status),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _getStatusText(status),
            style: widget.theme.typography.caption.copyWith(
              color: _getStatusColor(status),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  Color _getBackgroundColor(ProviderStatus status) {
    if (widget.isSelected) {
      return widget.provider.providerColor.withOpacity(0.1);
    }
    
    switch (status) {
      case ProviderStatus.connected:
        return Colors.green.withOpacity(0.05);
      case ProviderStatus.error:
        return Colors.red.withOpacity(0.05);
      default:
        return widget.theme.colorScheme.surface;
    }
  }
  
  Color _getTextColor(ProviderStatus status) {
    if (widget.isSelected) {
      return widget.theme.colorScheme.onSurface;
    }
    
    return widget.theme.colorScheme.onSurface.withOpacity(0.8);
  }
  
  Color _getStatusColor(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.connected:
        return Colors.green;
      case ProviderStatus.connecting:
        return widget.theme.colorScheme.primary;
      case ProviderStatus.error:
        return Colors.red;
      case ProviderStatus.tokenExpired:
        return Colors.orange;
      default:
        return widget.theme.colorScheme.onSurface.withOpacity(0.4);
    }
  }
  
  String _getStatusText(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.connected:
        return 'Conectado';
      case ProviderStatus.connecting:
        return 'Conectando...';
      case ProviderStatus.error:
        return 'Erro de conexão';
      case ProviderStatus.tokenExpired:
        return 'Token expirado';
      default:
        return 'Desconectado';
    }
  }
}
