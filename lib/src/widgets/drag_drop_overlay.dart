import 'package:flutter/material.dart';
import '../models/drag_drop_state.dart';
import '../theme/app_constants.dart';

/// Overlay widget that provides visual feedback during drag and drop operations
class DragDropOverlay extends StatefulWidget {
  /// Current drag and drop state
  final DragDropState dragDropState;
  
  /// Configuration for drag and drop validation
  final DragDropConfig? config;
  
  /// Whether the overlay should be visible
  final bool isVisible;
  
  /// Callback when files are dropped
  final void Function(List<String> files)? onFilesDropped;
  
  /// Custom message to display
  final String? customMessage;
  
  /// Custom icon to display
  final IconData? customIcon;

  const DragDropOverlay({
    super.key,
    required this.dragDropState,
    this.config,
    this.isVisible = true,
    this.onFilesDropped,
    this.customMessage,
    this.customIcon,
  });

  @override
  State<DragDropOverlay> createState() => _DragDropOverlayState();
}

class _DragDropOverlayState extends State<DragDropOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rippleController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DragDropOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle visibility changes
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _fadeController.forward();
        _scaleController.forward();
      } else {
        _fadeController.reverse();
        _scaleController.reverse();
      }
    }
    
    // Handle hover state changes
    if (widget.dragDropState.isHovering != oldWidget.dragDropState.isHovering) {
      if (widget.dragDropState.isHovering) {
        _rippleController.repeat();
      } else {
        _rippleController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible && !widget.dragDropState.shouldShowOverlay) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildOverlayContent(context),
          ),
        );
      },
    );
  }

  Widget _buildOverlayContent(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: _getOverlayColor(context),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
        ),
        child: Stack(
          children: [
            // Ripple effect for valid drops
            if (widget.dragDropState.shouldShowAcceptFeedback)
              _buildRippleEffect(context),
            
            // Main content
            Center(
              child: _buildMainContent(context),
            ),
            
            // File count indicator
            if (widget.dragDropState.fileCount > 0)
              _buildFileCountIndicator(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingXL),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          _buildIcon(context),
          
          const SizedBox(height: AppConstants.spacingL),
          
          // Main message
          _buildMessage(context),
          
          const SizedBox(height: AppConstants.spacingM),
          
          // File info
          if (widget.dragDropState.fileCount > 0)
            _buildFileInfo(context),
          
          // Error message
          if (widget.dragDropState.validationError != null)
            _buildErrorMessage(context),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    IconData icon;
    Color iconColor;
    
    if (widget.customIcon != null) {
      icon = widget.customIcon!;
      iconColor = Theme.of(context).colorScheme.primary;
    } else if (widget.dragDropState.shouldShowAcceptFeedback) {
      icon = Icons.cloud_upload;
      iconColor = Colors.green;
    } else if (widget.dragDropState.shouldShowRejectFeedback) {
      icon = Icons.block;
      iconColor = Theme.of(context).colorScheme.error;
    } else {
      icon = Icons.upload_file;
      iconColor = Theme.of(context).colorScheme.primary;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        icon,
        size: 64,
        color: iconColor,
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    String message;
    TextStyle? style;
    
    if (widget.customMessage != null) {
      message = widget.customMessage!;
      style = Theme.of(context).textTheme.headlineSmall;
    } else if (widget.dragDropState.shouldShowAcceptFeedback) {
      message = 'Solte aqui para fazer upload';
      style = Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: Colors.green,
        fontWeight: FontWeight.w600,
      );
    } else if (widget.dragDropState.shouldShowRejectFeedback) {
      message = 'Arquivos não podem ser enviados aqui';
      style = Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w600,
      );
    } else {
      message = 'Arraste arquivos aqui';
      style = Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      );
    }

    return Text(
      message,
      style: style,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildFileInfo(BuildContext context) {
    final fileCount = widget.dragDropState.fileCount;
    final fileNames = widget.dragDropState.fileNames;
    
    return Column(
      children: [
        Text(
          fileCount == 1 
              ? '1 arquivo selecionado'
              : '$fileCount arquivos selecionados',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        
        if (fileNames.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingS),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: SingleChildScrollView(
              child: Column(
                children: fileNames.take(3).map((name) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ).toList(),
              ),
            ),
          ),
          
          if (fileNames.length > 3)
            Text(
              '... e mais ${fileNames.length - 3} arquivo(s)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: AppConstants.spacingS),
          Flexible(
            child: Text(
              widget.dragDropState.validationError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCountIndicator(BuildContext context) {
    return Positioned(
      top: AppConstants.paddingM,
      right: AppConstants.paddingM,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingS,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        child: Text(
          widget.dragDropState.fileCount.toString(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRippleEffect(BuildContext context) {
    return AnimatedBuilder(
      animation: _rippleAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3 * (1 - _rippleAnimation.value)),
              width: 2 + (10 * _rippleAnimation.value),
            ),
          ),
        );
      },
    );
  }

  Color _getOverlayColor(BuildContext context) {
    if (widget.dragDropState.shouldShowAcceptFeedback) {
      return Colors.green.withValues(alpha: 0.1);
    } else if (widget.dragDropState.shouldShowRejectFeedback) {
      return Theme.of(context).colorScheme.error.withValues(alpha: 0.1);
    } else {
      return Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
    }
  }
}