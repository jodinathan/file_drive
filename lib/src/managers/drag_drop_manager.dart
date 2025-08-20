import 'package:flutter/foundation.dart';
import '../models/drag_drop_state.dart';
import '../models/file_entry.dart';
import '../utils/app_logger.dart';

/// Manager for handling drag and drop operations with validation
class DragDropManager extends ChangeNotifier {
  DragDropState _state = const DragDropState();
  DragDropConfig? _config;
  
  /// Callback when files are dropped and validated
  final void Function(List<String> files)? onFilesDropped;
  
  /// Callback when drag state changes
  final void Function(DragDropState state)? onStateChanged;

  DragDropManager({
    this.onFilesDropped,
    this.onStateChanged,
    DragDropConfig? config,
  }) : _config = config;

  /// Current drag and drop state
  DragDropState get state => _state;

  /// Current configuration
  DragDropConfig? get config => _config;

  /// Whether drag operation is active
  bool get isDragging => _state.isDragging;

  /// Whether mouse is hovering over drop zone
  bool get isHovering => _state.isHovering;

  /// Whether current files are valid for drop
  bool get hasValidFiles => _state.hasValidFiles;

  /// Whether overlay should be shown
  bool get shouldShowOverlay => _state.shouldShowOverlay;

  /// Updates the drag and drop configuration
  void updateConfig(DragDropConfig? config) {
    _config = config;
    
    // Re-validate current files if drag is active
    if (_state.isDragging) {
      _validateCurrentFiles();
    }
  }

  /// Starts a drag operation
  void startDrag({
    required List<String> fileNames,
    Offset? cursorPosition,
  }) {
    AppLogger.info('Starting drag with ${fileNames.length} files', 
                   component: 'DragDropManager');

    _state = _state.startDrag(
      fileCount: fileNames.length,
      fileNames: fileNames,
      cursorPosition: cursorPosition,
    );

    _validateCurrentFiles();
    notifyListeners();
    onStateChanged?.call(_state);
  }

  /// Updates drag position
  void updateDragPosition(Offset position) {
    if (!_state.isDragging) return;

    _state = _state.updateCursor(position);
    notifyListeners();
    onStateChanged?.call(_state);
  }

  /// Handles drag enter (mouse enters drop zone)
  void dragEnter({
    Offset? cursorPosition,
    FileEntry? targetFolder,
  }) {
    if (!_state.isDragging) return;


    final validation = _validateFiles(
      _state.fileNames,
      targetFolder: targetFolder,
    );

    _state = _state.dragEnter(
      hasValidFiles: validation.isValid,
      validationError: validation.isValid ? null : validation.errorMessage,
      validationType: validation,
      cursorPosition: cursorPosition,
    );

    notifyListeners();
    onStateChanged?.call(_state);
  }

  /// Handles drag leave (mouse leaves drop zone)
  void dragLeave({Offset? cursorPosition}) {
    if (!_state.isDragging) return;


    _state = _state.dragLeave(cursorPosition: cursorPosition);
    notifyListeners();
    onStateChanged?.call(_state);
  }

  /// Handles drag over with real-time validation
  void dragOver({
    required List<String> fileNames,
    Offset? cursorPosition,
    FileEntry? targetFolder,
  }) {
    if (!_state.isDragging) return;

    // Update file list if changed
    if (!_areFileListsEqual(_state.fileNames, fileNames)) {
      _state = _state.copyWith(
        fileNames: fileNames,
        fileCount: fileNames.length,
      );
    }

    // Validate files
    final validation = _validateFiles(fileNames, targetFolder: targetFolder);

    _state = _state.copyWith(
      hasValidFiles: validation.isValid,
      validationError: validation.isValid ? null : validation.errorMessage,
      validationType: validation,
      cursorPosition: cursorPosition,
    );

    notifyListeners();
    onStateChanged?.call(_state);
  }

  /// Handles file drop
  void dropFiles({
    required List<String> fileNames,
    FileEntry? targetFolder,
  }) {
    if (!_state.isDragging) return;

    AppLogger.info('Files dropped: ${fileNames.length} files', 
                   component: 'DragDropManager');

    // Final validation
    final validation = _validateFiles(fileNames, targetFolder: targetFolder);

    if (validation.isValid) {
      AppLogger.success('Files validated successfully for drop', 
                       component: 'DragDropManager');
      onFilesDropped?.call(fileNames);
    } else {
      AppLogger.warning('Files failed validation on drop: ${validation.errorMessage}', 
                       component: 'DragDropManager');
    }

    endDrag();
  }

  /// Ends the drag operation
  void endDrag() {
    if (!_state.isDragging) return;

    AppLogger.info('Ending drag operation', component: 'DragDropManager');

    _state = _state.endDrag();
    notifyListeners();
    onStateChanged?.call(_state);
  }

  /// Validates current files in drag state
  void _validateCurrentFiles() {
    if (!_state.isDragging) return;

    final validation = _validateFiles(_state.fileNames);

    _state = _state.copyWith(
      hasValidFiles: validation.isValid,
      validationError: validation.isValid ? null : validation.errorMessage,
      validationType: validation,
    );
  }

  /// Validates files against current configuration and target folder
  DragValidationType _validateFiles(
    List<String> fileNames, {
    FileEntry? targetFolder,
  }) {
    if (fileNames.isEmpty) {
      return DragValidationType.none;
    }

    // Validate against target folder if provided
    if (targetFolder != null) {
      final folderValidation = _validateAgainstFolder(fileNames, targetFolder);
      if (folderValidation != DragValidationType.valid) {
        return folderValidation;
      }
    }

    // Validate against global config if provided
    if (_config != null) {
      final configValidation = _config!.validateFiles(fileNames);
      if (configValidation != DragValidationType.valid) {
        return configValidation;
      }
    }

    return DragValidationType.valid;
  }

  /// Validates files against a specific target folder
  DragValidationType _validateAgainstFolder(
    List<String> fileNames,
    FileEntry targetFolder,
  ) {
    if (!targetFolder.isFolder) {
      return DragValidationType.permissionDenied;
    }

    if (!targetFolder.canUploadFiles) {
      return DragValidationType.permissionDenied;
    }

    // Check each file against folder restrictions
    for (final fileName in fileNames) {
      // Estimate file size (we don't have real size in drag state)
      const estimatedSize = 1024 * 1024; // 1MB estimate
      
      final validation = targetFolder.validateUpload(
        fileName: fileName,
        fileSize: estimatedSize,
      );

      if (!validation.isValid) {
        if (validation.error?.contains('size') == true) {
          return DragValidationType.sizeLimit;
        } else if (validation.error?.contains('type') == true) {
          return DragValidationType.invalidType;
        } else {
          return DragValidationType.permissionDenied;
        }
      }
    }

    return DragValidationType.valid;
  }

  /// Checks if two file lists are equal
  bool _areFileListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    
    return true;
  }

  /// Sets custom validation error
  void setCustomError(String error) {
    if (!_state.isDragging) return;

    _state = _state.copyWith(
      hasValidFiles: false,
      validationError: error,
      validationType: DragValidationType.permissionDenied,
    );

    notifyListeners();
    onStateChanged?.call(_state);
  }

  /// Clears any validation errors
  void clearError() {
    if (!_state.isDragging) return;

    _validateCurrentFiles();
    notifyListeners();
    onStateChanged?.call(_state);
  }

  /// Gets detailed validation info for debugging
  DragValidationInfo getValidationInfo() {
    return DragValidationInfo(
      isDragging: _state.isDragging,
      isHovering: _state.isHovering,
      hasValidFiles: _state.hasValidFiles,
      fileCount: _state.fileCount,
      validationType: _state.validationType,
      validationError: _state.validationError,
      hasConfig: _config != null,
    );
  }

  /// Creates a config for specific file types
  static DragDropConfig createConfigForTypes({
    List<String>? allowedExtensions,
    List<String>? allowedMimeTypes,
    int? maxFileSize,
    int? maxFileCount,
  }) {
    return DragDropConfig(
      allowedExtensions: allowedExtensions,
      allowedMimeTypes: allowedMimeTypes,
      maxFileSize: maxFileSize,
      maxFileCount: maxFileCount,
    );
  }

  @override
  String toString() {
    return 'DragDropManager(state: $_state, hasConfig: ${_config != null})';
  }
}

/// Validation information for debugging and monitoring
class DragValidationInfo {
  final bool isDragging;
  final bool isHovering;
  final bool hasValidFiles;
  final int fileCount;
  final DragValidationType validationType;
  final String? validationError;
  final bool hasConfig;

  const DragValidationInfo({
    required this.isDragging,
    required this.isHovering,
    required this.hasValidFiles,
    required this.fileCount,
    required this.validationType,
    required this.validationError,
    required this.hasConfig,
  });

  @override
  String toString() {
    return 'DragValidationInfo(dragging: $isDragging, valid: $hasValidFiles, '
           'files: $fileCount, type: $validationType, hasConfig: $hasConfig)';
  }
}