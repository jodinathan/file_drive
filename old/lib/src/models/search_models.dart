/// Search and filter models
library;

/// Query configuration for searching cloud items
class SearchQuery {
  final String query;
  final List<String> fileTypes;
  final DateRange? dateRange;
  final SizeRange? sizeRange;
  final String? folderId;
  final int maxResults;
  final SortOption sortBy;
  final bool includeSubfolders;
  final bool exactMatch;
  
  SearchQuery({
    required this.query,
    this.fileTypes = const [],
    this.dateRange,
    this.sizeRange,
    this.folderId,
    this.maxResults = 50,
    this.sortBy = SortOption.nameAsc,
    this.includeSubfolders = true,
    this.exactMatch = false,
  });
  
  /// Returns true if the query has any filters applied
  bool get hasFilters => 
      fileTypes.isNotEmpty || 
      dateRange != null || 
      sizeRange != null || 
      folderId != null;
  
  /// Returns true if this is a simple text search
  bool get isSimpleSearch => query.isNotEmpty && !hasFilters;
  
  /// Returns true if this query will return all items
  bool get isShowAll => query.isEmpty && !hasFilters;
  
  @override
  String toString() => 'SearchQuery{query: "$query", maxResults: $maxResults, sortBy: $sortBy}';
}

/// Date range filter for searches
class DateRange {
  final DateTime start;
  final DateTime end;
  
  DateRange({required this.start, required this.end});
  
  /// Returns true if the given date falls within this range
  bool contains(DateTime date) => date.isAfter(start) && date.isBefore(end);
  
  /// Returns the duration of this date range
  Duration get duration => end.difference(start);
  
  /// Returns true if this is a single day range
  bool get isSingleDay => 
      start.year == end.year && 
      start.month == end.month && 
      start.day == end.day;
  
  @override
  String toString() => 'DateRange{start: $start, end: $end}';
}

/// Size range filter for searches
class SizeRange {
  final int minSize;
  final int maxSize;
  
  SizeRange({required this.minSize, required this.maxSize});
  
  /// Returns true if the given size falls within this range
  bool contains(int size) => size >= minSize && size <= maxSize;
  
  /// Returns formatted size range (e.g., "1 KB - 10 MB")
  String get formattedRange => '${_formatSize(minSize)} - ${_formatSize(maxSize)}';
  
  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  @override
  String toString() => 'SizeRange{minSize: $minSize, maxSize: $maxSize}';
}

/// Sort options for file listings
enum SortOption {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  sizeAsc,
  sizeDesc,
  typeAsc,
  typeDesc,
}

/// Extension methods for SortOption
extension SortOptionExtension on SortOption {
  /// Returns display name for the sort option
  String get displayName {
    switch (this) {
      case SortOption.nameAsc:
        return 'Name (A-Z)';
      case SortOption.nameDesc:
        return 'Name (Z-A)';
      case SortOption.dateAsc:
        return 'Date (Oldest first)';
      case SortOption.dateDesc:
        return 'Date (Newest first)';
      case SortOption.sizeAsc:
        return 'Size (Smallest first)';
      case SortOption.sizeDesc:
        return 'Size (Largest first)';
      case SortOption.typeAsc:
        return 'Type (A-Z)';
      case SortOption.typeDesc:
        return 'Type (Z-A)';
    }
  }
  
  /// Returns true if this is an ascending sort
  bool get isAscending {
    switch (this) {
      case SortOption.nameAsc:
      case SortOption.dateAsc:
      case SortOption.sizeAsc:
      case SortOption.typeAsc:
        return true;
      default:
        return false;
    }
  }
  
  /// Returns the field being sorted by
  String get sortField {
    switch (this) {
      case SortOption.nameAsc:
      case SortOption.nameDesc:
        return 'name';
      case SortOption.dateAsc:
      case SortOption.dateDesc:
        return 'date';
      case SortOption.sizeAsc:
      case SortOption.sizeDesc:
        return 'size';
      case SortOption.typeAsc:
      case SortOption.typeDesc:
        return 'type';
    }
  }
}

/// Predefined file type filters
class FileTypeFilters {
  static const List<String> images = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/svg+xml',
  ];
  
  static const List<String> videos = [
    'video/mp4',
    'video/avi',
    'video/mov',
    'video/wmv',
    'video/webm',
  ];
  
  static const List<String> documents = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/html',
  ];
  
  static const List<String> audio = [
    'audio/mpeg',
    'audio/wav',
    'audio/ogg',
    'audio/aac',
  ];
  
  static const List<String> archives = [
    'application/zip',
    'application/x-rar-compressed',
    'application/x-tar',
    'application/gzip',
  ];
  
  /// Returns all file types in a category
  static List<String> getFileTypes(String category) {
    switch (category.toLowerCase()) {
      case 'images':
        return images;
      case 'videos':
        return videos;
      case 'documents':
        return documents;
      case 'audio':
        return audio;
      case 'archives':
        return archives;
      default:
        return [];
    }
  }
  
  /// Returns the category for a given MIME type
  static String? getCategoryForMimeType(String mimeType) {
    if (images.contains(mimeType)) return 'Images';
    if (videos.contains(mimeType)) return 'Videos';
    if (documents.contains(mimeType)) return 'Documents';
    if (audio.contains(mimeType)) return 'Audio';
    if (archives.contains(mimeType)) return 'Archives';
    return null;
  }
}