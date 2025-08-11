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
  
  /// Last modified timestamp
  final DateTime? modifiedAt;
  
  /// List of parent folder IDs
  final List<String> parents;
  
  /// URL for file thumbnail (if available)
  final String? thumbnailUrl;
  
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

  const FileEntry({
    required this.id,
    required this.name,
    required this.isFolder,
    this.size,
    this.mimeType,
    this.modifiedAt,
    this.parents = const [],
    this.thumbnailUrl,
    this.downloadUrl,
    this.canDownload = true,
    this.canDelete = false,
    this.canShare = false,
    this.metadata = const {},
  });

  /// Creates a copy of this FileEntry with some fields replaced
  FileEntry copyWith({
    String? id,
    String? name,
    bool? isFolder,
    int? size,
    String? mimeType,
    DateTime? modifiedAt,
    List<String>? parents,
    String? thumbnailUrl,
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
      modifiedAt: modifiedAt ?? this.modifiedAt,
      parents: parents ?? this.parents,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
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
      'modifiedAt': modifiedAt?.toIso8601String(),
      'parents': parents,
      'thumbnailUrl': thumbnailUrl,
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
      modifiedAt: json['modifiedAt'] != null 
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
      parents: List<String>.from(json['parents'] as List? ?? []),
      thumbnailUrl: json['thumbnailUrl'] as String?,
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