import 'package:flutter/material.dart';
import '../models/upload_state.dart';
import '../providers/base_cloud_provider.dart';
import '../theme/app_constants.dart';

/// Widget for displaying individual upload progress with actions
class UploadProgressWidget extends StatelessWidget {
  /// The upload state to display
  final UploadState uploadState;
  
  /// Callback when user wants to pause upload
  final VoidCallback? onPause;
  
  /// Callback when user wants to resume upload
  final VoidCallback? onResume;
  
  /// Callback when user wants to cancel upload
  final VoidCallback? onCancel;
  
  /// Callback when user wants to retry upload
  final VoidCallback? onRetry;
  
  /// Callback when user wants to remove completed/failed upload from list
  final VoidCallback? onRemove;
  
  /// Whether to show detailed information
  final bool showDetails;
  
  /// Whether to show action buttons
  final bool showActions;

  const UploadProgressWidget({
    super.key,
    required this.uploadState,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onRemove,
    this.showDetails = true,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingS,
        vertical: AppConstants.paddingXS,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: AppConstants.spacingS),
            _buildProgressBar(context),
            if (showDetails) ...[
              const SizedBox(height: AppConstants.spacingS),
              _buildDetails(context),
            ],
            if (showActions && _hasAvailableActions()) ...[
              const SizedBox(height: AppConstants.spacingM),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // File icon based on type
        Icon(
          _getFileIcon(),
          size: 24,
          color: _getStatusColor(context),
        ),
        const SizedBox(width: AppConstants.spacingS),
        
        // File name and status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uploadState.fileName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _getStatusText(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getStatusColor(context),
                ),
              ),
            ],
          ),
        ),
        
        // Progress percentage
        Text(
          uploadState.progressPercent,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: _getStatusColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: uploadState.progress.progress,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(context)),
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${uploadState.formattedUploadedSize} / ${uploadState.formattedFileSize}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (uploadState.progress.speed > 0 && uploadState.isActive)
              Text(
                _formatSpeed(uploadState.progress.speed),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context) {
    final details = <Widget>[];

    // Upload speed and ETA
    if (uploadState.isActive && uploadState.progress.speed > 0) {
      final eta = uploadState.progress.estimatedTimeRemaining;
      details.add(
        _buildDetailRow(
          context,
          'Velocidade',
          _formatSpeed(uploadState.progress.speed),
        ),
      );
      
      if (eta != null) {
        details.add(
          _buildDetailRow(
            context,
            'Tempo restante',
            _formatDuration(eta),
          ),
        );
      }
    }

    // Elapsed time for active uploads
    if (uploadState.isActive) {
      details.add(
        _buildDetailRow(
          context,
          'Tempo decorrido',
          _formatDuration(uploadState.progress.elapsedTime),
        ),
      );
    }

    // Error message
    if (uploadState.progress.error != null) {
      details.add(
        Container(
          padding: const EdgeInsets.all(AppConstants.paddingS),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
            border: Border.all(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: Text(
                  uploadState.progress.error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Retry count
    if (uploadState.retryCount > 0) {
      details.add(
        _buildDetailRow(
          context,
          'Tentativas',
          '${uploadState.retryCount}/${uploadState.maxRetries}',
        ),
      );
    }

    return Column(
      children: details.map((detail) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: detail,
      )).toList(),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final actions = <Widget>[];

    // Pause button
    if (uploadState.canPause && onPause != null) {
      actions.add(
        IconButton(
          onPressed: onPause,
          icon: const Icon(Icons.pause),
          tooltip: 'Pausar upload',
          style: IconButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    // Resume button
    if (uploadState.canResume && onResume != null) {
      actions.add(
        IconButton(
          onPressed: onResume,
          icon: const Icon(Icons.play_arrow),
          tooltip: 'Retomar upload',
          style: IconButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    // Retry button
    if (uploadState.canRetry && onRetry != null) {
      actions.add(
        IconButton(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          tooltip: 'Tentar novamente',
          style: IconButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    // Cancel button
    if (uploadState.canCancel && onCancel != null) {
      actions.add(
        IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          tooltip: 'Cancelar upload',
          style: IconButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
      );
    }

    // Remove button (for completed/failed uploads)
    if (uploadState.isFinished && onRemove != null) {
      actions.add(
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.clear),
          tooltip: 'Remover da lista',
          style: IconButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: actions,
    );
  }

  IconData _getFileIcon() {
    final fileName = uploadState.fileName.toLowerCase();
    final mimeType = uploadState.mimeType?.toLowerCase();

    // Image files
    if (mimeType?.startsWith('image/') == true ||
        fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png') ||
        fileName.endsWith('.gif') ||
        fileName.endsWith('.bmp') ||
        fileName.endsWith('.webp')) {
      return Icons.image;
    }

    // Document files
    if (mimeType?.contains('pdf') == true || fileName.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }

    if (mimeType?.contains('word') == true ||
        fileName.endsWith('.doc') ||
        fileName.endsWith('.docx')) {
      return Icons.description;
    }

    if (mimeType?.contains('excel') == true ||
        mimeType?.contains('spreadsheet') == true ||
        fileName.endsWith('.xls') ||
        fileName.endsWith('.xlsx') ||
        fileName.endsWith('.csv')) {
      return Icons.grid_on;
    }

    if (mimeType?.contains('powerpoint') == true ||
        mimeType?.contains('presentation') == true ||
        fileName.endsWith('.ppt') ||
        fileName.endsWith('.pptx')) {
      return Icons.slideshow;
    }

    // Video files
    if (mimeType?.startsWith('video/') == true ||
        fileName.endsWith('.mp4') ||
        fileName.endsWith('.avi') ||
        fileName.endsWith('.mov') ||
        fileName.endsWith('.mkv')) {
      return Icons.videocam;
    }

    // Audio files
    if (mimeType?.startsWith('audio/') == true ||
        fileName.endsWith('.mp3') ||
        fileName.endsWith('.wav') ||
        fileName.endsWith('.flac') ||
        fileName.endsWith('.aac')) {
      return Icons.audiotrack;
    }

    // Archive files
    if (fileName.endsWith('.zip') ||
        fileName.endsWith('.rar') ||
        fileName.endsWith('.7z') ||
        fileName.endsWith('.tar') ||
        fileName.endsWith('.gz')) {
      return Icons.archive;
    }

    // Text files
    if (mimeType?.startsWith('text/') == true || fileName.endsWith('.txt')) {
      return Icons.text_snippet;
    }

    // Default file icon
    return Icons.insert_drive_file;
  }

  Color _getStatusColor(BuildContext context) {
    switch (uploadState.progress.status) {
      case UploadStatus.waiting:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case UploadStatus.uploading:
      case UploadStatus.retrying:
        return Theme.of(context).colorScheme.primary;
      case UploadStatus.paused:
        return Theme.of(context).colorScheme.tertiary;
      case UploadStatus.completed:
        return Theme.of(context).colorScheme.primary;
      case UploadStatus.error:
        return Theme.of(context).colorScheme.error;
      case UploadStatus.cancelled:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _getStatusText() {
    switch (uploadState.progress.status) {
      case UploadStatus.waiting:
        return 'Aguardando...';
      case UploadStatus.uploading:
        return 'Fazendo upload...';
      case UploadStatus.paused:
        return 'Pausado';
      case UploadStatus.completed:
        return 'Concluído';
      case UploadStatus.error:
        return 'Erro';
      case UploadStatus.cancelled:
        return 'Cancelado';
      case UploadStatus.retrying:
        return 'Tentando novamente...';
    }
  }

  bool _hasAvailableActions() {
    return (uploadState.canPause && onPause != null) ||
        (uploadState.canResume && onResume != null) ||
        (uploadState.canRetry && onRetry != null) ||
        (uploadState.canCancel && onCancel != null) ||
        (uploadState.isFinished && onRemove != null);
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}