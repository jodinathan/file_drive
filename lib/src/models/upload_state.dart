import '../providers/base_cloud_provider.dart';

/// Represents the current state of an upload operation
class UploadState {
  /// Unique identifier for this upload
  final String id;
  
  /// Name of the file being uploaded
  final String fileName;
  
  /// File size in bytes
  final int fileSize;
  
  /// Current upload progress
  final UploadProgress progress;
  
  /// Target folder ID (null for root)
  final String? parentFolderId;
  
  /// Provider type handling this upload
  final String providerType;
  
  /// Account ID for the upload
  final String accountId;
  
  /// MIME type of the file
  final String? mimeType;
  
  /// Number of retry attempts made
  final int retryCount;
  
  /// Maximum retry attempts allowed
  final int maxRetries;
  
  /// Additional metadata for the upload
  final Map<String, dynamic> metadata;

  const UploadState({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.progress,
    this.parentFolderId,
    required this.providerType,
    required this.accountId,
    this.mimeType,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.metadata = const {},
  });

  /// Whether this upload is currently active (uploading or waiting)
  bool get isActive => progress.status == UploadStatus.uploading || 
                      progress.status == UploadStatus.waiting;

  /// Whether this upload can be paused
  bool get canPause => progress.status == UploadStatus.uploading;

  /// Whether this upload can be resumed
  bool get canResume => progress.status == UploadStatus.paused;

  /// Whether this upload can be cancelled
  bool get canCancel => !progress.status.isTerminal;

  /// Whether this upload can be retried
  bool get canRetry => progress.status == UploadStatus.error && 
                      retryCount < maxRetries;

  /// Whether this upload has finished (successfully or not)
  bool get isFinished => progress.status.isTerminal;

  /// Whether this upload completed successfully
  bool get isCompleted => progress.status == UploadStatus.completed;

  /// Whether this upload failed
  bool get hasFailed => progress.status == UploadStatus.error;

  /// Whether this upload was cancelled
  bool get wasCancelled => progress.status == UploadStatus.cancelled;

  /// Progress percentage as a string
  String get progressPercent => '${(progress.progress * 100).toStringAsFixed(1)}%';

  /// Human-readable file size
  String get formattedFileSize => _formatBytes(fileSize.toDouble());

  /// Human-readable uploaded size
  String get formattedUploadedSize => _formatBytes(progress.uploaded.toDouble());

  /// Creates a new upload state with updated progress
  UploadState updateProgress(UploadProgress newProgress) {
    return copyWith(progress: newProgress);
  }

  /// Creates a new upload state with incremented retry count
  UploadState incrementRetry() {
    return copyWith(
      retryCount: retryCount + 1,
      progress: progress.copyWith(status: UploadStatus.retrying),
    );
  }

  /// Creates a new upload state marked as paused
  UploadState pause() {
    return copyWith(
      progress: progress.copyWith(status: UploadStatus.paused),
    );
  }

  /// Creates a new upload state marked as cancelled
  UploadState cancel() {
    return copyWith(
      progress: progress.copyWith(status: UploadStatus.cancelled),
    );
  }

  /// Creates a new upload state marked as failed
  UploadState fail(String error) {
    return copyWith(
      progress: progress.copyWith(
        status: UploadStatus.error,
        error: error,
      ),
    );
  }

  /// Creates a new upload state marked as completed
  UploadState complete() {
    return copyWith(
      progress: progress.copyWith(
        status: UploadStatus.completed,
        uploaded: fileSize,
      ),
    );
  }

  /// Creates a copy with some fields replaced
  UploadState copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    UploadProgress? progress,
    String? parentFolderId,
    String? providerType,
    String? accountId,
    String? mimeType,
    int? retryCount,
    int? maxRetries,
    Map<String, dynamic>? metadata,
  }) {
    return UploadState(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      progress: progress ?? this.progress,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      providerType: providerType ?? this.providerType,
      accountId: accountId ?? this.accountId,
      mimeType: mimeType ?? this.mimeType,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Creates a new upload state from file information
  factory UploadState.fromFile({
    required String fileName,
    required int fileSize,
    required String providerType,
    required String accountId,
    String? parentFolderId,
    String? mimeType,
    int maxRetries = 3,
    Map<String, dynamic> metadata = const {},
  }) {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${fileName.hashCode}';
    final progress = UploadProgress.starting(
      fileName: fileName,
      total: fileSize,
    );

    return UploadState(
      id: id,
      fileName: fileName,
      fileSize: fileSize,
      progress: progress,
      parentFolderId: parentFolderId,
      providerType: providerType,
      accountId: accountId,
      mimeType: mimeType,
      maxRetries: maxRetries,
      metadata: metadata,
    );
  }

  static String _formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UploadState && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UploadState(id: $id, file: $fileName, status: ${progress.status}, '
           'progress: $progressPercent)';
  }
}