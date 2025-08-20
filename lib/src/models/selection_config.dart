import '../models/file_entry.dart';

/// Configuration for file selection mode
class SelectionConfig {
  /// Minimum number of files that must be selected
  final int minSelection;
  
  /// Maximum number of files that can be selected
  final int maxSelection;
  
  /// Allowed MIME types for selection (null means all types allowed)
  /// Supports wildcards like 'image/*', 'video/*', etc.
  final List<String>? allowedMimeTypes;
  
  /// User-friendly hint about allowed file types (e.g., "Only images and PDFs are allowed")
  final String? mimeTypeHint;
  
  /// Whether folders can be selected (always false as per requirements)
  final bool allowFolders;
  
  /// Callback function called when selection is confirmed (required)
  final void Function(List<FileEntry> selectedFiles) onSelectionConfirm;

  const SelectionConfig({
    this.minSelection = 1,
    this.maxSelection = 10,
    this.allowedMimeTypes,
    this.mimeTypeHint,
    this.allowFolders = false,
    required this.onSelectionConfirm,
  });

  /// Creates a selection config for images only
  factory SelectionConfig.images({
    int minSelection = 1,
    int maxSelection = 10,
    String? mimeTypeHint,
    required void Function(List<FileEntry> selectedFiles) onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection,
      maxSelection: maxSelection,
      allowedMimeTypes: const ['image/*'],
      mimeTypeHint: mimeTypeHint ?? 'Only image files are allowed',
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Creates a selection config for documents only
  factory SelectionConfig.documents({
    int minSelection = 1,
    int maxSelection = 10,
    String? mimeTypeHint,
    required void Function(List<FileEntry> selectedFiles) onSelectionConfirm,
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
      mimeTypeHint: mimeTypeHint ?? 'Only document files (PDF, Word, Excel, PowerPoint, Text) are allowed',
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Creates a selection config for videos only
  factory SelectionConfig.videos({
    int minSelection = 1,
    int maxSelection = 5,
    String? mimeTypeHint,
    required void Function(List<FileEntry> selectedFiles) onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection,
      maxSelection: maxSelection,
      allowedMimeTypes: const ['video/*'],
      mimeTypeHint: mimeTypeHint ?? 'Only video files are allowed',
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Creates a selection config for audio files only
  factory SelectionConfig.audio({
    int minSelection = 1,
    int maxSelection = 10,
    String? mimeTypeHint,
    required void Function(List<FileEntry> selectedFiles) onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection,
      maxSelection: maxSelection,
      allowedMimeTypes: const ['audio/*'],
      mimeTypeHint: mimeTypeHint ?? 'Only audio files are allowed',
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Creates a selection config for single file selection
  factory SelectionConfig.singleFile({
    List<String>? allowedMimeTypes,
    String? mimeTypeHint,
    required void Function(List<FileEntry> selectedFiles) onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: 1,
      maxSelection: 1,
      allowedMimeTypes: allowedMimeTypes,
      mimeTypeHint: mimeTypeHint,
      allowFolders: false,
      onSelectionConfirm: onSelectionConfirm,
    );
  }

  /// Creates a selection config for multiple file selection
  factory SelectionConfig.multipleFiles({
    int minSelection = 1,
    int maxSelection = 10,
    List<String>? allowedMimeTypes,
    String? mimeTypeHint,
    required void Function(List<FileEntry> selectedFiles) onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection,
      maxSelection: maxSelection,
      allowedMimeTypes: allowedMimeTypes,
      mimeTypeHint: mimeTypeHint,
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
      return _matchesMimeType(entry.mimeType, allowedMimeTypes!);
    }
    
    return true;
  }

  /// Checks if a file's MIME type matches any of the allowed patterns
  /// Supports wildcards like 'image/*', 'video/*', etc.
  bool _matchesMimeType(String? fileMimeType, List<String> allowedTypes) {
    if (fileMimeType == null) return false;
    
    for (final allowedType in allowedTypes) {
      if (_isWildcardMatch(fileMimeType, allowedType)) {
        return true;
      }
    }
    
    return false;
  }

  /// Checks if a MIME type matches a pattern (supports wildcard '*')
  bool _isWildcardMatch(String mimeType, String pattern) {
    // Exact match
    if (mimeType == pattern) return true;
    
    // Wildcard match (e.g., 'image/*' matches 'image/png')
    if (pattern.endsWith('/*')) {
      final prefix = pattern.substring(0, pattern.length - 2);
      return mimeType.startsWith('$prefix/');
    }
    
    // Special case: '*/*' or '*' matches everything
    if (pattern == '*/*' || pattern == '*') return true;
    
    return false;
  }

  /// Gets a user-friendly description of allowed file types
  String getTypeDescription() {
    if (allowedMimeTypes == null || allowedMimeTypes!.isEmpty) {
      return 'All file types';
    }

    final types = <String>[];
    for (final mimeType in allowedMimeTypes!) {
      if (mimeType == 'image/*') {
        types.add('Images');
      } else if (mimeType == 'video/*') {
        types.add('Videos');
      } else if (mimeType == 'audio/*') {
        types.add('Audio');
      } else if (mimeType == 'text/*') {
        types.add('Text files');
      } else if (mimeType == 'application/pdf') {
        types.add('PDF');
      } else if (mimeType.startsWith('application/vnd.ms-') || 
                 mimeType.startsWith('application/vnd.openxmlformats-')) {
        types.add('Office documents');
      } else {
        // For specific types, extract the subtype
        final parts = mimeType.split('/');
        if (parts.length == 2) {
          types.add(parts[1].toUpperCase());
        } else {
          types.add(mimeType);
        }
      }
    }

    if (types.length == 1) {
      return types.first;
    } else if (types.length == 2) {
      return '${types[0]} and ${types[1]}';
    } else {
      final lastType = types.removeLast();
      return '${types.join(', ')}, and $lastType';
    }
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
    String? mimeTypeHint,
    bool? allowFolders,
    void Function(List<FileEntry> selectedFiles)? onSelectionConfirm,
  }) {
    return SelectionConfig(
      minSelection: minSelection ?? this.minSelection,
      maxSelection: maxSelection ?? this.maxSelection,
      allowedMimeTypes: allowedMimeTypes ?? this.allowedMimeTypes,
      mimeTypeHint: mimeTypeHint ?? this.mimeTypeHint,
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
        other.mimeTypeHint == mimeTypeHint &&
        _listEquals(other.allowedMimeTypes, allowedMimeTypes);
  }

  @override
  int get hashCode {
    return minSelection.hashCode ^
        maxSelection.hashCode ^
        allowFolders.hashCode ^
        (mimeTypeHint?.hashCode ?? 0) ^
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