import 'package:flutter/material.dart';
import '../models/upload_state.dart';
import '../theme/app_constants.dart';
import 'upload_progress_widget.dart';

/// Widget for displaying a list of uploads with filtering and actions
class UploadListWidget extends StatefulWidget {
  /// List of upload states to display
  final List<UploadState> uploads;
  
  /// Callback when user wants to pause an upload
  final void Function(String uploadId)? onPause;
  
  /// Callback when user wants to resume an upload
  final void Function(String uploadId)? onResume;
  
  /// Callback when user wants to cancel an upload
  final void Function(String uploadId)? onCancel;
  
  /// Callback when user wants to retry an upload
  final void Function(String uploadId)? onRetry;
  
  /// Callback when user wants to remove an upload from list
  final void Function(String uploadId)? onRemove;
  
  /// Callback when user wants to clear all completed uploads
  final VoidCallback? onClearCompleted;
  
  /// Callback when user wants to cancel all active uploads
  final VoidCallback? onCancelAll;
  
  /// Whether to show the header with actions
  final bool showHeader;
  
  /// Whether to show upload details
  final bool showDetails;
  
  /// Maximum height of the widget
  final double? maxHeight;

  const UploadListWidget({
    super.key,
    required this.uploads,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onRemove,
    this.onClearCompleted,
    this.onCancelAll,
    this.showHeader = true,
    this.showDetails = true,
    this.maxHeight,
  });

  @override
  State<UploadListWidget> createState() => _UploadListWidgetState();
}

class _UploadListWidgetState extends State<UploadListWidget> {
  UploadFilter _currentFilter = UploadFilter.all;
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.uploads.isEmpty) {
      return _buildEmptyState(context);
    }

    final filteredUploads = _getFilteredUploads();

    return Container(
      constraints: widget.maxHeight != null 
          ? BoxConstraints(maxHeight: widget.maxHeight!)
          : null,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showHeader) _buildHeader(context),
          if (_isExpanded) _buildUploadList(context, filteredUploads),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingL),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            'Nenhum upload em andamento',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Os uploads aparecerão aqui conforme você faz upload de arquivos',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final activeCount = widget.uploads.where((u) => u.isActive).length;
    final completedCount = widget.uploads.where((u) => u.isCompleted).length;
    final failedCount = widget.uploads.where((u) => u.hasFailed).length;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppConstants.radiusM),
          topRight: Radius.circular(AppConstants.radiusM),
        ),
      ),
      child: Column(
        children: [
          // Title and expand/collapse button
          Row(
            children: [
              Icon(
                Icons.cloud_upload,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: Text(
                  'Uploads (${widget.uploads.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                tooltip: _isExpanded ? 'Recolher' : 'Expandir',
              ),
            ],
          ),

          if (_isExpanded) ...[
            const SizedBox(height: AppConstants.spacingM),
            
            // Status counts
            Row(
              children: [
                _buildStatusChip(
                  context,
                  'Ativos',
                  activeCount,
                  Theme.of(context).colorScheme.primary,
                  UploadFilter.active,
                ),
                const SizedBox(width: AppConstants.spacingS),
                _buildStatusChip(
                  context,
                  'Concluídos',
                  completedCount,
                  Colors.green,
                  UploadFilter.completed,
                ),
                const SizedBox(width: AppConstants.spacingS),
                _buildStatusChip(
                  context,
                  'Falhas',
                  failedCount,
                  Theme.of(context).colorScheme.error,
                  UploadFilter.failed,
                ),
                const Spacer(),
                _buildHeaderActions(context),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    String label,
    int count,
    Color color,
    UploadFilter filter,
  ) {
    final isSelected = _currentFilter == filter;
    
    return GestureDetector(
      onTap: () => setState(() {
        _currentFilter = _currentFilter == filter ? UploadFilter.all : filter;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingS,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$label ($count)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected ? color : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Clear completed button
        if (widget.uploads.any((u) => u.isCompleted) && widget.onClearCompleted != null)
          TextButton.icon(
            onPressed: widget.onClearCompleted,
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Limpar'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              textStyle: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        
        // Cancel all button
        if (widget.uploads.any((u) => u.isActive) && widget.onCancelAll != null)
          TextButton.icon(
            onPressed: () => _showCancelAllDialog(context),
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('Cancelar Todos'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              textStyle: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildUploadList(BuildContext context, List<UploadState> uploads) {
    if (uploads.isEmpty && _currentFilter != UploadFilter.all) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Text(
          'Nenhum upload encontrado para o filtro selecionado',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: uploads.length,
        itemBuilder: (context, index) {
          final upload = uploads[index];
          return UploadProgressWidget(
            uploadState: upload,
            showDetails: widget.showDetails,
            onPause: widget.onPause != null 
                ? () => widget.onPause!(upload.id)
                : null,
            onResume: widget.onResume != null 
                ? () => widget.onResume!(upload.id)
                : null,
            onCancel: widget.onCancel != null 
                ? () => widget.onCancel!(upload.id)
                : null,
            onRetry: widget.onRetry != null 
                ? () => widget.onRetry!(upload.id)
                : null,
            onRemove: widget.onRemove != null 
                ? () => widget.onRemove!(upload.id)
                : null,
          );
        },
      ),
    );
  }

  List<UploadState> _getFilteredUploads() {
    switch (_currentFilter) {
      case UploadFilter.all:
        return widget.uploads;
      case UploadFilter.active:
        return widget.uploads.where((u) => u.isActive).toList();
      case UploadFilter.completed:
        return widget.uploads.where((u) => u.isCompleted).toList();
      case UploadFilter.failed:
        return widget.uploads.where((u) => u.hasFailed || u.wasCancelled).toList();
    }
  }

  void _showCancelAllDialog(BuildContext context) {
    final activeUploads = widget.uploads.where((u) => u.isActive).length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar todos os uploads'),
        content: Text(
          'Deseja realmente cancelar todos os $activeUploads uploads em andamento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onCancelAll?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancelar Todos'),
          ),
        ],
      ),
    );
  }
}

/// Filter options for upload list
enum UploadFilter {
  all,
  active,
  completed,
  failed;

  String get label {
    switch (this) {
      case UploadFilter.all:
        return 'Todos';
      case UploadFilter.active:
        return 'Ativos';
      case UploadFilter.completed:
        return 'Concluídos';
      case UploadFilter.failed:
        return 'Falhas';
    }
  }
}