/// Represents the capabilities of a cloud storage provider
class ProviderCapabilities {
  /// Whether the provider supports file upload
  final bool canUpload;
  
  /// Whether the provider supports folder creation
  final bool canCreateFolders;
  
  /// Whether the provider supports file/folder deletion
  final bool canDelete;
  
  /// Whether the provider supports permanent deletion (bypass trash)
  final bool canPermanentDelete;
  
  /// Whether the provider supports file search by name
  final bool canSearch;
  
  /// Whether the provider supports chunked/resumable uploads
  final bool canChunkedUpload;
  
  /// Whether the provider supports file thumbnails
  final bool hasThumbnails;
  
  /// Whether the provider supports file sharing
  final bool canShare;
  
  /// Whether the provider supports moving files between folders
  final bool canMove;
  
  /// Whether the provider supports copying files
  final bool canCopy;
  
  /// Whether the provider supports renaming files/folders
  final bool canRename;
  
  /// Maximum file size for uploads (in bytes, null if unlimited)
  final int? maxUploadSize;
  
  /// Supported file types for upload (null if all types supported)
  final List<String>? supportedUploadTypes;
  
  /// Maximum number of items that can be listed in a single request
  final int maxPageSize;

  const ProviderCapabilities({
    this.canUpload = true,
    this.canCreateFolders = true,
    this.canDelete = false,
    this.canPermanentDelete = false,
    this.canSearch = false,
    this.canChunkedUpload = false,
    this.hasThumbnails = false,
    this.canShare = false,
    this.canMove = false,
    this.canCopy = false,
    this.canRename = false,
    this.maxUploadSize,
    this.supportedUploadTypes,
    this.maxPageSize = 50,
  });

  /// Creates a copy of this ProviderCapabilities with some fields replaced
  ProviderCapabilities copyWith({
    bool? canUpload,
    bool? canCreateFolders,
    bool? canDelete,
    bool? canPermanentDelete,
    bool? canSearch,
    bool? canChunkedUpload,
    bool? hasThumbnails,
    bool? canShare,
    bool? canMove,
    bool? canCopy,
    bool? canRename,
    int? maxUploadSize,
    List<String>? supportedUploadTypes,
    int? maxPageSize,
  }) {
    return ProviderCapabilities(
      canUpload: canUpload ?? this.canUpload,
      canCreateFolders: canCreateFolders ?? this.canCreateFolders,
      canDelete: canDelete ?? this.canDelete,
      canPermanentDelete: canPermanentDelete ?? this.canPermanentDelete,
      canSearch: canSearch ?? this.canSearch,
      canChunkedUpload: canChunkedUpload ?? this.canChunkedUpload,
      hasThumbnails: hasThumbnails ?? this.hasThumbnails,
      canShare: canShare ?? this.canShare,
      canMove: canMove ?? this.canMove,
      canCopy: canCopy ?? this.canCopy,
      canRename: canRename ?? this.canRename,
      maxUploadSize: maxUploadSize ?? this.maxUploadSize,
      supportedUploadTypes: supportedUploadTypes ?? this.supportedUploadTypes,
      maxPageSize: maxPageSize ?? this.maxPageSize,
    );
  }

  /// Converts this ProviderCapabilities to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'canUpload': canUpload,
      'canCreateFolders': canCreateFolders,
      'canDelete': canDelete,
      'canPermanentDelete': canPermanentDelete,
      'canSearch': canSearch,
      'canChunkedUpload': canChunkedUpload,
      'hasThumbnails': hasThumbnails,
      'canShare': canShare,
      'canMove': canMove,
      'canCopy': canCopy,
      'canRename': canRename,
      'maxUploadSize': maxUploadSize,
      'supportedUploadTypes': supportedUploadTypes,
      'maxPageSize': maxPageSize,
    };
  }

  /// Creates a ProviderCapabilities from a JSON map
  factory ProviderCapabilities.fromJson(Map<String, dynamic> json) {
    return ProviderCapabilities(
      canUpload: json['canUpload'] as bool? ?? true,
      canCreateFolders: json['canCreateFolders'] as bool? ?? true,
      canDelete: json['canDelete'] as bool? ?? false,
      canPermanentDelete: json['canPermanentDelete'] as bool? ?? false,
      canSearch: json['canSearch'] as bool? ?? false,
      canChunkedUpload: json['canChunkedUpload'] as bool? ?? false,
      hasThumbnails: json['hasThumbnails'] as bool? ?? false,
      canShare: json['canShare'] as bool? ?? false,
      canMove: json['canMove'] as bool? ?? false,
      canCopy: json['canCopy'] as bool? ?? false,
      canRename: json['canRename'] as bool? ?? false,
      maxUploadSize: json['maxUploadSize'] as int?,
      supportedUploadTypes: json['supportedUploadTypes'] != null
          ? List<String>.from(json['supportedUploadTypes'] as List)
          : null,
      maxPageSize: json['maxPageSize'] as int? ?? 50,
    );
  }
}