/// Represents a file or folder entry from a cloud storage provider
class FileEntry {
  /// Unique identifier from the provider
  final String id;
  
  /// Display name of the file or folder
  final String name;
  
  /// Whether this entry is a folder
  final bool isFolder;
  
  /// File size in bytes (null for folders)
  final int? size;
  
  /// MIME type of the file (null for folders)
  final String? mimeType;
  
  /// Creation timestamp
  final DateTime? createdAt;
  
  /// Last modified timestamp
  final DateTime? modifiedAt;
  
  /// List of parent folder IDs
  final List<String> parents;
  
  /// URL for file thumbnail (if available)
  final String? thumbnailUrl;
  
  /// Whether this file has a thumbnail available
  final bool hasThumbnail;
  
  /// Thumbnail version for cache invalidation
  final String? thumbnailVersion;
  
  /// Download URL (if available)
  final String? downloadUrl;
  
  /// Whether the file can be downloaded
  final bool canDownload;
  
  /// Whether the file can be deleted
  final bool canDelete;
  
  /// Whether the file can be shared
  final bool canShare;
  
  /// Additional metadata from the provider
  final Map<String, dynamic> metadata;

  FileEntry({
    required this.id,
    required this.name,
    required this.isFolder,
    this.size,
    this.mimeType,
    this.createdAt,
    this.modifiedAt,
    this.parents = const [],
    this.thumbnailUrl,
    this.hasThumbnail = false,
    this.thumbnailVersion,
    this.downloadUrl,
    this.canDownload = true,
    this.canDelete = false,
    this.canShare = false,
    this.metadata = const {},
  }) : assert(id.isNotEmpty, 'ID cannot be empty'),
       assert(name.isNotEmpty, 'Name cannot be empty'),
       assert(thumbnailUrl == null || Uri.tryParse(thumbnailUrl) != null, 'thumbnailUrl must be a valid URL'),
       assert(downloadUrl == null || Uri.tryParse(downloadUrl) != null, 'downloadUrl must be a valid URL');

  /// Whether this folder can have subfolders created in it
  bool get canCreateSubfolders {
    if (!isFolder) return false;
    
    // Check if creation is explicitly disabled in metadata
    final canCreate = metadata['canCreateSubfolders'];
    if (canCreate is bool) return canCreate;
    
    // Default to true for folders unless explicitly disabled
    return true;
  }

  /// Whether files can be uploaded to this folder
  bool get canUploadFiles {
    if (!isFolder) return false;
    
    // Check if upload is explicitly disabled in metadata
    final canUpload = metadata['canUploadFiles'];
    if (canUpload is bool) return canUpload;
    
    // Default to true for folders unless explicitly disabled
    return true;
  }

  /// Gets the maximum file size allowed for uploads to this folder
  int? get maxUploadSize {
    final maxSize = metadata['maxUploadSize'];
    if (maxSize is int) return maxSize;
    return null; // No limit
  }

  /// Gets allowed file types for uploads to this folder
  List<String>? get allowedFileTypes {
    final types = metadata['allowedFileTypes'];
    if (types is List) return List<String>.from(types);
    return null; // All types allowed
  }

  /// Whether this entry is in a shared folder
  bool get isInSharedFolder {
    final shared = metadata['isShared'];
    if (shared is bool) return shared;
    return false;
  }

  /// Gets the quota information for this folder
  FolderQuota? get quota {
    final quotaData = metadata['quota'];
    if (quotaData is Map<String, dynamic>) {
      return FolderQuota.fromJson(quotaData);
    }
    return null;
  }

  /// Validates if a file can be uploaded to this folder
  FileUploadValidation validateUpload({
    required String fileName,
    required int fileSize,
    String? mimeType,
  }) {
    if (!isFolder) {
      return FileUploadValidation.error('Cannot upload to a file');
    }

    if (!canUploadFiles) {
      return FileUploadValidation.error('Upload not allowed in this folder');
    }

    // Check file size limit
    final maxSize = maxUploadSize;
    if (maxSize != null && fileSize > maxSize) {
      return FileUploadValidation.error('File size exceeds limit');
    }

    // Check file type restrictions
    final allowedTypes = allowedFileTypes;
    if (allowedTypes != null && allowedTypes.isNotEmpty) {
      final extension = fileName.toLowerCase().split('.').last;
      final mimeTypeAllowed = mimeType != null && allowedTypes.contains(mimeType);
      final extensionAllowed = allowedTypes.any((type) => 
          type.toLowerCase() == extension || 
          type.toLowerCase() == '.$extension');
      
      if (!mimeTypeAllowed && !extensionAllowed) {
        return FileUploadValidation.error('File type not allowed');
      }
    }

    // Check quota if available
    final folderQuota = quota;
    if (folderQuota != null && !folderQuota.canUpload(fileSize)) {
      return FileUploadValidation.error('Not enough space available');
    }

    return FileUploadValidation.success();
  }

  /// Validates if a subfolder can be created in this folder
  FolderCreationValidation validateSubfolderCreation({
    required String folderName,
  }) {
    if (!isFolder) {
      return FolderCreationValidation.error('Cannot create folder inside a file');
    }

    if (!canCreateSubfolders) {
      return FolderCreationValidation.error('Subfolder creation not allowed');
    }

    // Validate folder name
    if (folderName.trim().isEmpty) {
      return FolderCreationValidation.error('Folder name cannot be empty');
    }

    // Check for invalid characters (basic validation)
    final invalidChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    for (final char in invalidChars) {
      if (folderName.contains(char)) {
        return FolderCreationValidation.error('Invalid character: $char');
      }
    }

    // Check length limit
    if (folderName.length > 255) {
      return FolderCreationValidation.error('Folder name too long');
    }

    return FolderCreationValidation.success();
  }

  /// Creates a copy of this FileEntry with some fields replaced
  FileEntry copyWith({
    String? id,
    String? name,
    bool? isFolder,
    int? size,
    String? mimeType,
    DateTime? createdAt,
    DateTime? modifiedAt,
    List<String>? parents,
    String? thumbnailUrl,
    bool? hasThumbnail,
    String? thumbnailVersion,
    String? downloadUrl,
    bool? canDownload,
    bool? canDelete,
    bool? canShare,
    Map<String, dynamic>? metadata,
  }) {
    return FileEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      isFolder: isFolder ?? this.isFolder,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      parents: parents ?? this.parents,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      hasThumbnail: hasThumbnail ?? this.hasThumbnail,
      thumbnailVersion: thumbnailVersion ?? this.thumbnailVersion,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      canDownload: canDownload ?? this.canDownload,
      canDelete: canDelete ?? this.canDelete,
      canShare: canShare ?? this.canShare,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Converts this FileEntry to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isFolder': isFolder,
      'size': size,
      'mimeType': mimeType,
      'createdAt': createdAt?.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
      'parents': parents,
      'thumbnailUrl': thumbnailUrl,
      'hasThumbnail': hasThumbnail,
      'thumbnailVersion': thumbnailVersion,
      'downloadUrl': downloadUrl,
      'canDownload': canDownload,
      'canDelete': canDelete,
      'canShare': canShare,
      'metadata': metadata,
    };
  }

  /// Creates a FileEntry from a JSON map
  factory FileEntry.fromJson(Map<String, dynamic> json) {
    return FileEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      isFolder: json['isFolder'] as bool,
      size: json['size'] as int?,
      mimeType: json['mimeType'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      modifiedAt: json['modifiedAt'] != null 
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
      parents: List<String>.from(json['parents'] as List? ?? []),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      hasThumbnail: json['hasThumbnail'] as bool? ?? false,
      thumbnailVersion: json['thumbnailVersion'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      canDownload: json['canDownload'] as bool? ?? true,
      canDelete: json['canDelete'] as bool? ?? false,
      canShare: json['canShare'] as bool? ?? false,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FileEntry(id: $id, name: $name, isFolder: $isFolder)';
  }
}

/// Validation result for file uploads
class FileUploadValidation {
  /// Whether the validation passed
  final bool isValid;
  
  /// Error message if validation failed
  final String? error;

  const FileUploadValidation._(this.isValid, this.error);

  /// Creates a successful validation result
  factory FileUploadValidation.success() {
    return const FileUploadValidation._(true, null);
  }

  /// Creates a failed validation result
  factory FileUploadValidation.error(String message) {
    return FileUploadValidation._(false, message);
  }
}

/// Validation result for folder creation
class FolderCreationValidation {
  /// Whether the validation passed
  final bool isValid;
  
  /// Error message if validation failed
  final String? error;

  const FolderCreationValidation._(this.isValid, this.error);

  /// Creates a successful validation result
  factory FolderCreationValidation.success() {
    return const FolderCreationValidation._(true, null);
  }

  /// Creates a failed validation result
  factory FolderCreationValidation.error(String message) {
    return FolderCreationValidation._(false, message);
  }
}

/// Represents folder quota information
class FolderQuota {
  /// Total space in bytes
  final int total;
  
  /// Used space in bytes
  final int used;
  
  /// Available space in bytes
  int get available => total - used;
  
  /// Whether there's enough space for a file
  bool canUpload(int fileSize) => available >= fileSize;
  
  /// Usage percentage (0.0 to 1.0)
  double get usagePercentage => total > 0 ? used / total : 0.0;

  const FolderQuota({
    required this.total,
    required this.used,
  });

  /// Creates quota from JSON data
  factory FolderQuota.fromJson(Map<String, dynamic> json) {
    return FolderQuota(
      total: json['total'] as int,
      used: json['used'] as int,
    );
  }

  /// Converts quota to JSON
  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'used': used,
    };
  }
}

/// Represents a paginated list of file entries
class FileListPage {
  /// List of file entries in this page
  final List<FileEntry> entries;
  
  /// Token for loading the next page (null if no more pages)
  final String? nextPageToken;
  
  /// Whether there are more pages available
  final bool hasMore;
  
  /// Total number of items (if known by the provider)
  final int? totalCount;

  const FileListPage({
    required this.entries,
    this.nextPageToken,
    this.hasMore = false,
    this.totalCount,
  });

  /// Creates an empty page
  factory FileListPage.empty() {
    return const FileListPage(entries: []);
  }

  /// Combines this page with another page
  FileListPage combine(FileListPage other) {
    return FileListPage(
      entries: [...entries, ...other.entries],
      nextPageToken: other.nextPageToken,
      hasMore: other.hasMore,
      totalCount: other.totalCount ?? totalCount,
    );
  }
}