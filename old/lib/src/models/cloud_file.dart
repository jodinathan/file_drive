/// Cloud file implementation
library;

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'cloud_item.dart';

/// Specific implementation for cloud files
class CloudFile extends CloudItem {
  final int size;
  final String mimeType;
  final String? thumbnailUrl;
  final String? downloadUrl;
  final bool isShared;
  final FilePermissions permissions;
  
  CloudFile({
    required String id,
    required String name,
    String? parentId,
    required DateTime createdAt,
    required DateTime modifiedAt,
    required this.size,
    required this.mimeType,
    this.thumbnailUrl,
    this.downloadUrl,
    this.isShared = false,
    this.permissions = const FilePermissions(),
    Map<String, dynamic> metadata = const {},
  }) : super(
    id: id,
    name: name,
    parentId: parentId,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    type: CloudItemType.file,
    metadata: metadata,
  );
  
  /// Returns formatted file size (e.g., "1.5 MB")
  String get formattedSize => _formatFileSize(size);
  
  /// Returns file extension in lowercase
  String get fileExtension => name.split('.').last.toLowerCase();
  
  /// Returns true if the file type supports preview
  bool get hasPreview => _supportedPreviewTypes.contains(mimeType);
  
  /// Returns true if the file is an image
  bool get isImage => mimeType.startsWith('image/');
  
  /// Returns true if the file is a video
  bool get isVideo => mimeType.startsWith('video/');
  
  /// Returns true if the file is a document
  bool get isDocument => _documentTypes.contains(mimeType);
  
  /// Returns appropriate icon for the file type
  IconData get fileIcon => _getFileIcon();
  
  /// Returns color associated with the file type
  Color get fileColor => _getFileColor();
  
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  static const Set<String> _supportedPreviewTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/svg+xml',
    'text/plain',
    'application/pdf',
  };
  
  static const Set<String> _documentTypes = {
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/html',
    'text/css',
    'text/javascript',
    'application/json',
    'application/xml',
  };
  
  IconData _getFileIcon() {
    if (isImage) return Icons.image;
    if (isVideo) return Icons.video_file;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) return Icons.table_chart;
    if (mimeType.contains('powerpoint') || mimeType.contains('presentation')) return Icons.slideshow;
    if (mimeType.startsWith('text/')) return Icons.text_snippet;
    if (mimeType.startsWith('audio/')) return Icons.audio_file;
    if (mimeType.contains('zip') || mimeType.contains('archive')) return Icons.archive;
    return Icons.insert_drive_file;
  }
  
  Color _getFileColor() {
    if (isImage) return Colors.green;
    if (isVideo) return Colors.red;
    if (mimeType == 'application/pdf') return Colors.red.shade700;
    if (mimeType.contains('word') || mimeType.contains('document')) return Colors.blue;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) return Colors.green.shade700;
    if (mimeType.contains('powerpoint') || mimeType.contains('presentation')) return Colors.orange;
    if (mimeType.startsWith('text/')) return Colors.grey;
    if (mimeType.startsWith('audio/')) return Colors.purple;
    if (mimeType.contains('zip') || mimeType.contains('archive')) return Colors.brown;
    return Colors.grey.shade600;
  }
  
  @override
  String toString() => 'CloudFile{id: $id, name: $name, size: $formattedSize, mimeType: $mimeType}';
}