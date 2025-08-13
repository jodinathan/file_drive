import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/upload_state.dart';
import '../providers/base_cloud_provider.dart';
import '../utils/app_logger.dart';

/// Central manager for handling file uploads with queue management and retry logic
class UploadManager extends ChangeNotifier {
  final Map<String, UploadState> _uploads = {};
  final Queue<String> _uploadQueue = Queue<String>();
  final Map<String, StreamSubscription> _activeUploads = {};
  final Map<String, Completer<void>> _uploadCompleters = {};
  
  int _maxConcurrentUploads = 3;
  bool _isPaused = false;
  bool _isProcessingQueue = false;

  /// Gets all uploads as an unmodifiable list
  List<UploadState> get uploads => _uploads.values.toList();

  /// Gets active uploads count
  int get activeUploadsCount => _activeUploads.length;

  /// Gets uploads in queue count
  int get queuedUploadsCount => _uploadQueue.length;

  /// Gets completed uploads count
  int get completedUploadsCount => 
      _uploads.values.where((u) => u.isCompleted).length;

  /// Gets failed uploads count
  int get failedUploadsCount => 
      _uploads.values.where((u) => u.hasFailed).length;

  /// Whether the upload manager is paused
  bool get isPaused => _isPaused;

  /// Whether there are any active uploads
  bool get hasActiveUploads => _activeUploads.isNotEmpty;

  /// Maximum concurrent uploads allowed
  int get maxConcurrentUploads => _maxConcurrentUploads;

  /// Sets maximum concurrent uploads
  set maxConcurrentUploads(int value) {
    if (value > 0 && value <= 10) {
      _maxConcurrentUploads = value;
      _processQueue();
    }
  }

  /// Adds a new upload to the queue
  Future<void> addUpload({
    required String fileName,
    required int fileSize,
    required Stream<List<int>> fileStream,
    required BaseCloudProvider provider,
    String? parentFolderId,
    String? mimeType,
    Map<String, dynamic> metadata = const {},
  }) async {
    final uploadState = UploadState.fromFile(
      fileName: fileName,
      fileSize: fileSize,
      providerType: provider.providerType,
      accountId: provider.currentAccount?.id ?? 'unknown',
      parentFolderId: parentFolderId,
      mimeType: mimeType,
      metadata: metadata,
    );

    AppLogger.info('Adding upload: ${uploadState.fileName}', component: 'UploadManager');

    _uploads[uploadState.id] = uploadState;
    _uploadQueue.add(uploadState.id);
    
    // Store the file stream for later use
    _uploads[uploadState.id] = uploadState.copyWith(
      metadata: {
        ...uploadState.metadata,
        '_fileStream': fileStream,
        '_provider': provider,
      },
    );

    notifyListeners();
    _processQueue();
  }

  /// Pauses a specific upload
  void pauseUpload(String uploadId) {
    final upload = _uploads[uploadId];
    if (upload == null || !upload.canPause) return;

    AppLogger.info('Pausing upload: ${upload.fileName}', component: 'UploadManager');

    _cancelActiveUpload(uploadId);
    _uploads[uploadId] = upload.pause();
    notifyListeners();
  }

  /// Resumes a specific upload
  void resumeUpload(String uploadId) {
    final upload = _uploads[uploadId];
    if (upload == null || !upload.canResume) return;

    AppLogger.info('Resuming upload: ${upload.fileName}', component: 'UploadManager');

    _uploads[uploadId] = upload.copyWith(
      progress: upload.progress.copyWith(status: UploadStatus.waiting),
    );
    
    _uploadQueue.addFirst(uploadId);
    notifyListeners();
    _processQueue();
  }

  /// Cancels a specific upload
  void cancelUpload(String uploadId) {
    final upload = _uploads[uploadId];
    if (upload == null || !upload.canCancel) return;

    AppLogger.info('Cancelling upload: ${upload.fileName}', component: 'UploadManager');

    _cancelActiveUpload(uploadId);
    _uploadQueue.remove(uploadId);
    _uploads[uploadId] = upload.cancel();
    notifyListeners();
  }

  /// Retries a failed upload
  void retryUpload(String uploadId) {
    final upload = _uploads[uploadId];
    if (upload == null || !upload.canRetry) return;

    AppLogger.info('Retrying upload: ${upload.fileName}', component: 'UploadManager');

    final retriedUpload = upload.incrementRetry();
    _uploads[uploadId] = retriedUpload;
    _uploadQueue.addFirst(uploadId);
    notifyListeners();
    _processQueue();
  }

  /// Removes a finished upload from the list
  void removeUpload(String uploadId) {
    final upload = _uploads[uploadId];
    if (upload == null || !upload.isFinished) return;

    AppLogger.info('Removing upload: ${upload.fileName}', component: 'UploadManager');

    _uploads.remove(uploadId);
    _uploadCompleters.remove(uploadId);
    notifyListeners();
  }

  /// Pauses all uploads
  void pauseAll() {
    AppLogger.info('Pausing all uploads', component: 'UploadManager');
    
    _isPaused = true;
    
    // Cancel all active uploads
    final activeIds = _activeUploads.keys.toList();
    for (final id in activeIds) {
      final upload = _uploads[id];
      if (upload != null && upload.isActive) {
        _cancelActiveUpload(id);
        _uploads[id] = upload.pause();
      }
    }
    
    notifyListeners();
  }

  /// Resumes all uploads
  void resumeAll() {
    AppLogger.info('Resuming all uploads', component: 'UploadManager');
    
    _isPaused = false;
    
    // Resume all paused uploads
    final pausedUploads = _uploads.values
        .where((u) => u.progress.status == UploadStatus.paused)
        .toList();
    
    for (final upload in pausedUploads) {
      _uploads[upload.id] = upload.copyWith(
        progress: upload.progress.copyWith(status: UploadStatus.waiting),
      );
      
      if (!_uploadQueue.contains(upload.id)) {
        _uploadQueue.addFirst(upload.id);
      }
    }
    
    notifyListeners();
    _processQueue();
  }

  /// Cancels all active uploads
  void cancelAll() {
    AppLogger.info('Cancelling all uploads', component: 'UploadManager');
    
    final activeIds = [..._activeUploads.keys, ..._uploadQueue];
    for (final id in activeIds) {
      cancelUpload(id);
    }
  }

  /// Clears all completed uploads
  void clearCompleted() {
    AppLogger.info('Clearing completed uploads', component: 'UploadManager');
    
    final completedIds = _uploads.values
        .where((u) => u.isCompleted)
        .map((u) => u.id)
        .toList();
    
    for (final id in completedIds) {
      _uploads.remove(id);
      _uploadCompleters.remove(id);
    }
    
    notifyListeners();
  }

  /// Gets a specific upload state
  UploadState? getUpload(String uploadId) => _uploads[uploadId];

  /// Waits for a specific upload to complete
  Future<void> waitForUpload(String uploadId) async {
    final upload = _uploads[uploadId];
    if (upload == null) return;
    
    if (upload.isFinished) return;
    
    final completer = _uploadCompleters.putIfAbsent(
      uploadId,
      () => Completer<void>(),
    );
    
    return completer.future;
  }

  /// Processes the upload queue
  void _processQueue() async {
    if (_isPaused || _isProcessingQueue) return;
    if (_activeUploads.length >= _maxConcurrentUploads) return;
    if (_uploadQueue.isEmpty) return;

    _isProcessingQueue = true;

    try {
      while (_uploadQueue.isNotEmpty && 
             _activeUploads.length < _maxConcurrentUploads && 
             !_isPaused) {
        
        final uploadId = _uploadQueue.removeFirst();
        final upload = _uploads[uploadId];
        
        if (upload == null || upload.isFinished) continue;
        
        await _startUpload(uploadId);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Starts a specific upload
  Future<void> _startUpload(String uploadId) async {
    final upload = _uploads[uploadId];
    if (upload == null) return;

    AppLogger.info('Starting upload: ${upload.fileName}', component: 'UploadManager');

    // Get stored data
    final fileStream = upload.metadata['_fileStream'] as Stream<List<int>>?;
    final provider = upload.metadata['_provider'] as BaseCloudProvider?;
    
    if (fileStream == null || provider == null) {
      _uploads[uploadId] = upload.fail('Missing upload data');
      notifyListeners();
      return;
    }

    // Update status to uploading
    _uploads[uploadId] = upload.copyWith(
      progress: upload.progress.copyWith(
        status: UploadStatus.uploading,
        lastUpdate: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      // Start the upload
      final progressStream = provider.uploadFile(
        fileName: upload.fileName,
        fileBytes: fileStream,
        parentId: upload.parentFolderId,
        mimeType: upload.mimeType,
      );

      final subscription = progressStream.listen(
        (progress) => _onUploadProgress(uploadId, progress),
        onError: (error) => _onUploadError(uploadId, error),
        onDone: () => _onUploadComplete(uploadId),
      );

      _activeUploads[uploadId] = subscription;

    } catch (e) {
      _onUploadError(uploadId, e);
    }
  }

  /// Handles upload progress updates
  void _onUploadProgress(String uploadId, UploadProgress progress) {
    final upload = _uploads[uploadId];
    if (upload == null) return;

    _uploads[uploadId] = upload.updateProgress(progress);
    notifyListeners();
  }

  /// Handles upload completion
  void _onUploadComplete(String uploadId) {
    final upload = _uploads[uploadId];
    if (upload == null) return;

    AppLogger.success('Upload completed: ${upload.fileName}', component: 'UploadManager');

    _activeUploads.remove(uploadId);
    _uploads[uploadId] = upload.complete();
    
    final completer = _uploadCompleters.remove(uploadId);
    completer?.complete();
    
    notifyListeners();
    _processQueue();
  }

  /// Handles upload errors
  void _onUploadError(String uploadId, dynamic error) {
    final upload = _uploads[uploadId];
    if (upload == null) return;

    AppLogger.error('Upload failed: ${upload.fileName}', 
                   component: 'UploadManager', error: error);

    _activeUploads.remove(uploadId);
    _uploads[uploadId] = upload.fail(error.toString());
    
    final completer = _uploadCompleters.remove(uploadId);
    completer?.completeError(error);
    
    notifyListeners();
    _processQueue();
  }

  /// Cancels an active upload
  void _cancelActiveUpload(String uploadId) {
    final subscription = _activeUploads.remove(uploadId);
    subscription?.cancel();
    
    final completer = _uploadCompleters.remove(uploadId);
    completer?.completeError('Upload cancelled');
  }

  @override
  void dispose() {
    AppLogger.info('Disposing UploadManager', component: 'UploadManager');
    
    // Cancel all active uploads
    for (final subscription in _activeUploads.values) {
      subscription.cancel();
    }
    _activeUploads.clear();
    
    // Complete all pending completers
    for (final completer in _uploadCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError('Upload manager disposed');
      }
    }
    _uploadCompleters.clear();
    
    super.dispose();
  }
}