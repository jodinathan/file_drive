/// Represents the current state of drag and drop operations
class DragDropState {
  /// Whether a drag operation is currently active
  final bool isDragging;
  
  /// Whether the mouse is currently over the drop zone
  final bool isHovering;
  
  /// Whether the current drag contains valid files
  final bool hasValidFiles;
  
  /// Number of files being dragged
  final int fileCount;
  
  /// List of file names being dragged (for preview)
  final List<String> fileNames;
  
  /// Error message if validation failed
  final String? validationError;
  
  /// Position of the drag cursor (for animations)
  final Offset? cursorPosition;
  
  /// Type of validation applied
  final DragValidationType validationType;

  const DragDropState({
    this.isDragging = false,
    this.isHovering = false,
    this.hasValidFiles = false,
    this.fileCount = 0,
    this.fileNames = const [],
    this.validationError,
    this.cursorPosition,
    this.validationType = DragValidationType.none,
  });

  /// Whether the drop zone should show positive feedback
  bool get shouldShowAcceptFeedback => isDragging && isHovering && hasValidFiles;

  /// Whether the drop zone should show negative feedback
  bool get shouldShowRejectFeedback => isDragging && isHovering && !hasValidFiles;

  /// Whether the overlay should be visible
  bool get shouldShowOverlay => isDragging;

  /// Whether files can be dropped in the current state
  bool get canDrop => isDragging && hasValidFiles;

  /// Creates a new state for drag start
  DragDropState startDrag({
    required int fileCount,
    required List<String> fileNames,
    Offset? cursorPosition,
  }) {
    return copyWith(
      isDragging: true,
      fileCount: fileCount,
      fileNames: fileNames,
      cursorPosition: cursorPosition,
      // Reset previous state
      isHovering: false,
      hasValidFiles: false,
      validationError: null,
      validationType: DragValidationType.none,
    );
  }

  /// Creates a new state for drag enter (mouse over drop zone)
  DragDropState dragEnter({
    required bool hasValidFiles,
    String? validationError,
    DragValidationType? validationType,
    Offset? cursorPosition,
  }) {
    return copyWith(
      isHovering: true,
      hasValidFiles: hasValidFiles,
      validationError: validationError,
      validationType: validationType ?? this.validationType,
      cursorPosition: cursorPosition,
    );
  }

  /// Creates a new state for drag leave (mouse left drop zone)
  DragDropState dragLeave({Offset? cursorPosition}) {
    return copyWith(
      isHovering: false,
      cursorPosition: cursorPosition,
    );
  }

  /// Creates a new state for drag end (drag operation finished)
  DragDropState endDrag() {
    return const DragDropState();
  }

  /// Creates a new state with updated cursor position
  DragDropState updateCursor(Offset position) {
    return copyWith(cursorPosition: position);
  }

  /// Creates a copy with some fields replaced
  DragDropState copyWith({
    bool? isDragging,
    bool? isHovering,
    bool? hasValidFiles,
    int? fileCount,
    List<String>? fileNames,
    String? validationError,
    Offset? cursorPosition,
    DragValidationType? validationType,
  }) {
    return DragDropState(
      isDragging: isDragging ?? this.isDragging,
      isHovering: isHovering ?? this.isHovering,
      hasValidFiles: hasValidFiles ?? this.hasValidFiles,
      fileCount: fileCount ?? this.fileCount,
      fileNames: fileNames ?? this.fileNames,
      validationError: validationError ?? this.validationError,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      validationType: validationType ?? this.validationType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DragDropState &&
        other.isDragging == isDragging &&
        other.isHovering == isHovering &&
        other.hasValidFiles == hasValidFiles &&
        other.fileCount == fileCount &&
        other.validationError == validationError &&
        other.validationType == validationType;
  }

  @override
  int get hashCode {
    return Object.hash(
      isDragging,
      isHovering,
      hasValidFiles,
      fileCount,
      validationError,
      validationType,
    );
  }

  @override
  String toString() {
    return 'DragDropState(dragging: $isDragging, hovering: $isHovering, '
           'valid: $hasValidFiles, files: $fileCount)';
  }
}

/// Types of validation applied during drag and drop
enum DragValidationType {
  /// No validation applied
  none,
  
  /// Files validated successfully
  valid,
  
  /// Files rejected due to invalid type
  invalidType,
  
  /// Files rejected due to size limit
  sizeLimit,
  
  /// Files rejected due to count limit
  countLimit,
  
  /// Files rejected due to permission issues
  permissionDenied,
  
  /// Multiple validation errors
  multiple;

  /// Human-readable error message for this validation type
  String get errorMessage {
    switch (this) {
      case DragValidationType.none:
        return '';
      case DragValidationType.valid:
        return 'Files are valid';
      case DragValidationType.invalidType:
        return 'Some files have invalid types';
      case DragValidationType.sizeLimit:
        return 'Some files exceed size limit';
      case DragValidationType.countLimit:
        return 'Too many files selected';
      case DragValidationType.permissionDenied:
        return 'Permission denied for upload';
      case DragValidationType.multiple:
        return 'Multiple validation errors';
    }
  }

  /// Whether this represents a valid state
  bool get isValid => this == DragValidationType.valid;

  /// Whether this represents an error state
  bool get isError => this != DragValidationType.none && 
                     this != DragValidationType.valid;
}

/// Configuration for drag and drop validation
class DragDropConfig {
  /// Maximum file size in bytes (null for no limit)
  final int? maxFileSize;
  
  /// Maximum number of files (null for no limit)
  final int? maxFileCount;
  
  /// Allowed file extensions (null for no restriction)
  final List<String>? allowedExtensions;
  
  /// Allowed MIME types (null for no restriction)
  final List<String>? allowedMimeTypes;
  
  /// Whether to allow folders
  final bool allowFolders;
  
  /// Custom validation function
  final bool Function(List<String> fileNames)? customValidator;

  const DragDropConfig({
    this.maxFileSize,
    this.maxFileCount,
    this.allowedExtensions,
    this.allowedMimeTypes,
    this.allowFolders = false,
    this.customValidator,
  });

  /// Creates a config that allows all files
  factory DragDropConfig.allowAll() {
    return const DragDropConfig();
  }

  /// Creates a config for images only
  factory DragDropConfig.imagesOnly({int? maxSize}) {
    return DragDropConfig(
      maxFileSize: maxSize,
      allowedExtensions: ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'],
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/bmp', 'image/webp'],
    );
  }

  /// Creates a config for documents only
  factory DragDropConfig.documentsOnly({int? maxSize}) {
    return DragDropConfig(
      maxFileSize: maxSize,
      allowedExtensions: ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt'],
      allowedMimeTypes: [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'text/plain',
      ],
    );
  }

  /// Validates a list of file names against this config
  DragValidationType validateFiles(List<String> fileNames) {
    final errors = <DragValidationType>[];

    // Check file count
    if (maxFileCount != null && fileNames.length > maxFileCount!) {
      errors.add(DragValidationType.countLimit);
    }

    // Check file extensions
    if (allowedExtensions != null) {
      final hasInvalidExtension = fileNames.any((name) {
        final extension = name.toLowerCase();
        return !allowedExtensions!.any((ext) => extension.endsWith(ext.toLowerCase()));
      });
      
      if (hasInvalidExtension) {
        errors.add(DragValidationType.invalidType);
      }
    }

    // Custom validation
    if (customValidator != null && !customValidator!(fileNames)) {
      errors.add(DragValidationType.permissionDenied);
    }

    if (errors.isEmpty) {
      return DragValidationType.valid;
    } else if (errors.length == 1) {
      return errors.first;
    } else {
      return DragValidationType.multiple;
    }
  }
}

/// Offset class for cursor position (if not available from Flutter)
class Offset {
  final double dx;
  final double dy;

  const Offset(this.dx, this.dy);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Offset && other.dx == dx && other.dy == dy;
  }

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'Offset($dx, $dy)';
}