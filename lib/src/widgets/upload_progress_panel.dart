import 'package:flutter/material.dart';
import '../models/file_operations.dart';

class UploadProgressPanel extends StatelessWidget {
  final List<UploadProgress> uploads;
  final Function(String) onCancelUpload;

  const UploadProgressPanel({
    Key? key,
    required this.uploads,
    required this.onCancelUpload,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (uploads.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Uploads (${uploads.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.expand_less),
                  onPressed: () {
                    // TODO: Implement collapse functionality
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: uploads.length,
              itemBuilder: (context, index) {
                final upload = uploads[index];
                return _buildUploadItem(context, upload);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadItem(BuildContext context, UploadProgress upload) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upload.fileName,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: upload.percentage / 100,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _getStatusText(upload),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(upload.status),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${upload.percentage.toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(
              upload.status == UploadStatus.uploading
                  ? Icons.cancel
                  : Icons.close,
              size: 20,
            ),
            onPressed: () => onCancelUpload(upload.uploadId),
          ),
        ],
      ),
    );
  }

  String _getStatusText(UploadProgress upload) {
    switch (upload.status) {
      case UploadStatus.pending:
        return 'Aguardando...';
      case UploadStatus.uploading:
        return 'Enviando...';
      case UploadStatus.paused:
        return 'Pausado';
      case UploadStatus.completed:
        return 'Concluído';
      case UploadStatus.failed:
        return upload.error ?? 'Erro';
      case UploadStatus.cancelled:
        return 'Cancelado';
    }
  }

  Color _getStatusColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return Colors.orange;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.paused:
        return Colors.yellow;
      case UploadStatus.completed:
        return Colors.green;
      case UploadStatus.failed:
        return Colors.red;
      case UploadStatus.cancelled:
        return Colors.grey;
    }
  }
}