/// Upload and download related models
library;

import 'dart:io';
import 'dart:typed_data';

/// Configuration for file upload
class FileUpload {
  final File file;
  final String fileName;
  final String? parentFolderId;
  final Map<String, String> metadata;
  final bool overwriteExisting;
  
  FileUpload({
    required this.file,
    required this.fileName,
    this.parentFolderId,
    this.metadata = const {},
    this.overwriteExisting = false,
  });
  
  /// Returns file size in bytes
  int get fileSize => file.lengthSync();
  
  /// Returns file extension
  String get fileExtension => fileName.split('.').last.toLowerCase();
  
  /// Returns MIME type based on file extension
  String get mimeType => _getMimeType(fileExtension);
  
  static String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'html':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'js':
        return 'text/javascript';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      default:
        return 'application/octet-stream';
    }
  }
  
  @override
  String toString() => 'FileUpload{fileName: $fileName, size: $fileSize bytes}';
}

/// Progress information for file uploads
class UploadProgress {
  final String uploadId;
  final String fileName;
  final int bytesUploaded;
  final int totalBytes;
  final double percentage;
  final UploadStatus status;
  final Duration? estimatedTimeRemaining;
  final String? error;
  final DateTime startTime;
  
  UploadProgress({
    required this.uploadId,
    required this.fileName,
    required this.bytesUploaded,
    required this.totalBytes,
    required this.status,
    this.estimatedTimeRemaining,
    this.error,
    DateTime? startTime,
  }) : percentage = totalBytes > 0 ? (bytesUploaded / totalBytes) * 100 : 0,
       startTime = startTime ?? DateTime.now();
  
  /// Returns upload speed in bytes per second
  double get uploadSpeed {
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inSeconds == 0) return 0;
    return bytesUploaded / elapsed.inSeconds;
  }
  
  /// Returns formatted upload speed (e.g., "1.5 MB/s")
  String get formattedSpeed {
    final speed = uploadSpeed;
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  
  /// Returns true if upload is in progress
  bool get isActive => status == UploadStatus.uploading;
  
  /// Returns true if upload is complete
  bool get isComplete => status == UploadStatus.completed;
  
  /// Returns true if upload failed
  bool get isFailed => status == UploadStatus.failed;
  
  /// Returns true if upload can be cancelled
  bool get canCancel => status == UploadStatus.uploading || status == UploadStatus.pending;
  
  /// Returns true if upload can be retried
  bool get canRetry => status == UploadStatus.failed || status == UploadStatus.cancelled;
  
  @override
  String toString() => 'UploadProgress{fileName: $fileName, percentage: ${percentage.toStringAsFixed(1)}%, status: $status}';
}

/// Status of file upload
enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
  cancelled,
  paused,
}

/// Configuration for file download
class FileDownload {
  final String fileId;
  final String fileName;
  final String? localPath;
  final bool openAfterDownload;
  
  FileDownload({
    required this.fileId,
    required this.fileName,
    this.localPath,
    this.openAfterDownload = false,
  });
  
  @override
  String toString() => 'FileDownload{fileId: $fileId, fileName: $fileName}';
}

/// Progress information for file downloads
class DownloadProgress {
  final String downloadId;
  final String fileName;
  final int bytesDownloaded;
  final int totalBytes;
  final double percentage;
  final DownloadStatus status;
  final String? error;
  final DateTime startTime;
  
  DownloadProgress({
    required this.downloadId,
    required this.fileName,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.status,
    this.error,
    DateTime? startTime,
  }) : percentage = totalBytes > 0 ? (bytesDownloaded / totalBytes) * 100 : 0,
       startTime = startTime ?? DateTime.now();
  
  /// Returns download speed in bytes per second
  double get downloadSpeed {
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inSeconds == 0) return 0;
    return bytesDownloaded / elapsed.inSeconds;
  }
  
  /// Returns formatted download speed (e.g., "1.5 MB/s")
  String get formattedSpeed {
    final speed = downloadSpeed;
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  
  /// Returns true if download is in progress
  bool get isActive => status == DownloadStatus.downloading;
  
  /// Returns true if download is complete
  bool get isComplete => status == DownloadStatus.completed;
  
  /// Returns true if download failed
  bool get isFailed => status == DownloadStatus.failed;
  
  @override
  String toString() => 'DownloadProgress{fileName: $fileName, percentage: ${percentage.toStringAsFixed(1)}%, status: $status}';
}

/// Status of file download
enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
  paused,
}