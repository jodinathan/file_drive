import '../models/file_entry.dart';

/// Configuration for file selection mode
class SelectionConfig {
  /// Minimum number of files that must be selected
  final int minSelection;
  
  /// Maximum number of files that can be selected
  final int maxSelection;
  
  /// Allowed MIME types for selection (null means all types allowed)
  final List<String>? allowedMimeTypes;
  
  /// Whether folders can be selected (always false as per requirements)
  final bool allowFolders;
  
  /// Callback function called when selection is confirmed (optional)
  final void Function(List<FileEntry> selectedFiles)? onSelectionConfirm;

  const SelectionConfig({
    this.minSelection = 1,
    this.maxSelection = 10,
    this.allowedMimeTypes,
    this.allowFolders = false,
    this.onSelectionConfirm,
  });

  /// Creates a selection config for images only
  factory SelectionConfig.images({
    int minSelection = 1,
    int maxSelection = 10,
    void Function(List<FileEntry> selectedFiles)? onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection,
      maxSelection: maxSelection,
      allowedMimeTypes: const [
        'image/jpeg',
        'image/png',
        'image/gif',
        'image/webp',
        'image/bmp',
        'image/tiff',
        'image/svg+xml',
      ],
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Creates a selection config for documents only
  factory SelectionConfig.documents({
    int minSelection = 1,
    int maxSelection = 10,
    void Function(List<FileEntry> selectedFiles)? onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection,
      maxSelection: maxSelection,
      allowedMimeTypes: const [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'text/plain',
        'text/rtf',
        'application/rtf',
      ],
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Creates a selection config for videos only
  factory SelectionConfig.videos({
    int minSelection = 1,
    int maxSelection = 5,
    void Function(List<FileEntry> selectedFiles)? onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection,
      maxSelection: maxSelection,
      allowedMimeTypes: const [
        'video/mp4',
        'video/avi',
        'video/quicktime',
        'video/x-msvideo',
        'video/webm',
        'video/ogg',
        'video/3gpp',
        'video/x-ms-wmv',
      ],
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Creates a selection config for audio files only
  factory SelectionConfig.audio({
    int minSelection = 1,
    int maxSelection = 10,
    void Function(List<FileEntry> selectedFiles)? onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection,
      maxSelection: maxSelection,
      allowedMimeTypes: const [
        'audio/mpeg',
        'audio/mp4',
        'audio/wav',
        'audio/ogg',
        'audio/webm',
        'audio/aac',
        'audio/flac',
        'audio/x-ms-wma',
      ],
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Creates a selection config for single file selection
  factory SelectionConfig.singleFile({
    List<String>? allowedMimeTypes,
    void Function(List<FileEntry> selectedFiles)? onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: 1,
      maxSelection: 1,
      allowedMimeTypes: allowedMimeTypes,
      allowFolders: false,
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Creates a selection config for multiple file selection
  factory SelectionConfig.multipleFiles({
    int minSelection = 1,
    int maxSelection = 10,
    List<String>? allowedMimeTypes,
    void Function(List<FileEntry> selectedFiles)? onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection,
      maxSelection: maxSelection,
      allowedMimeTypes: allowedMimeTypes,
      allowFolders: false,
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Validates if a file entry can be selected based on this configuration
  bool canSelect(FileEntry entry) {
    // Check if folders are allowed
    if (entry.isFolder && !allowFolders) {
      return false;
    }
    
    // Check MIME type restrictions
    if (allowedMimeTypes != null && !entry.isFolder) {
      return allowedMimeTypes!.contains(entry.mimeType);
    }
    
    return true;
  }

  /// Validates current selection against this configuration
  SelectionValidationResult validateSelection(List<FileEntry> selectedFiles) {
    // Check minimum selection
    if (selectedFiles.length < minSelection) {
      return SelectionValidationResult.invalid(
        'Please select at least $minSelection item${minSelection > 1 ? 's' : ''}',
      );
    }
    
    // Check maximum selection
    if (selectedFiles.length > maxSelection) {
      return SelectionValidationResult.invalid(
        'You can select at most $maxSelection item${maxSelection > 1 ? 's' : ''}',
      );
    }
    
    // Check individual file types
    for (final file in selectedFiles) {
      if (!canSelect(file)) {
        return SelectionValidationResult.invalid(
          'File "${file.name}" is not allowed in current selection',
        );
      }
    }
    
    return SelectionValidationResult.valid();
  }

  /// Creates a copy of this config with the specified changes
  SelectionConfig copyWith({
    int? minSelection,
    int? maxSelection,
    List<String>? allowedMimeTypes,
    bool? allowFolders,
    void Function(List<FileEntry> selectedFiles)? onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection ?? this.minSelection,
      maxSelection: maxSelection ?? this.maxSelection,
      allowedMimeTypes: allowedMimeTypes ?? this.allowedMimeTypes,
      allowFolders: allowFolders ?? this.allowFolders,
      onSelectionConfirm: onSelectionConfirm ?? this.onSelectionConfirm,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SelectionConfig &&
        other.minSelection == minSelection &&
        other.maxSelection == maxSelection &&
        other.allowFolders == allowFolders &&
        _listEquals(other.allowedMimeTypes, allowedMimeTypes);
  }

  @override
  int get hashCode {
    return minSelection.hashCode ^
        maxSelection.hashCode ^
        allowFolders.hashCode ^
        (allowedMimeTypes?.hashCode ?? 0);
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

/// Result of selection validation
class SelectionValidationResult {
  final bool isValid;
  final String? errorMessage;

  const SelectionValidationResult._(this.isValid, this.errorMessage);

  factory SelectionValidationResult.valid() {
    return const SelectionValidationResult._(true, null);
  }

  factory SelectionValidationResult.invalid(String message) {
    return SelectionValidationResult._(false, message);
  }
}