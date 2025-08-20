import 'dart:math' as math;
import 'file_entry.dart';
import '../utils/app_logger.dart';

/// Specialized FileEntry for image files with crop functionality
class ImageFileEntry extends FileEntry {
  /// Width of the original image in pixels
  final int? width;
  
  /// Height of the original image in pixels
  final int? height;
  
  /// Crop information as Rectangle<int> (left, top, width, height)
  final math.Rectangle<int>? crop;
  
  /// BlurHash for placeholder (optional)
  final String? blurHash;

  ImageFileEntry({
    required super.id,
    required super.name,
    required super.isFolder,
    super.size,
    super.mimeType,
    super.createdAt,
    super.modifiedAt,
    super.parents = const [],
    super.thumbnailUrl,
    super.hasThumbnail = false,
    super.thumbnailVersion,
    super.downloadUrl,
    super.canDownload = true,
    super.canDelete = false,
    super.canShare = false,
    super.metadata = const {},
    this.width,
    this.height,
    this.crop,
    this.blurHash,
  }) : assert(!isFolder, 'ImageFileEntry cannot be a folder'),
       assert(width == null || width > 0, 'Width must be positive'),
       assert(height == null || height > 0, 'Height must be positive');

  /// Whether this entry represents an image file
  bool get isImage => _isImageMimeType(mimeType);

  /// Aspect ratio of the original image
  double get aspectRatio {
    if (width == null || height == null || height == 0) return 1.0;
    return width! / height!;
  }

  /// Aspect ratio after applying crop
  double get croppedAspectRatio {
    final effectiveCrop = getEffectiveCrop();
    if (effectiveCrop.width == 0 || effectiveCrop.height == 0) return aspectRatio;
    return effectiveCrop.width / effectiveCrop.height;
  }

  /// Checks if this image can be cropped
  bool canBeCropped() {
    // Allow cropping for any image file, even without known dimensions
    // The crop dialog will handle loading the image to get dimensions
    return isImage;
  }

  /// Checks if this image has valid crop data
  bool hasCropData() {
    return crop != null && isValidCrop(crop!);
  }

  /// Returns the effective crop area (crop if available, otherwise full image)
  math.Rectangle<int> getEffectiveCrop() {
    if (crop != null && isValidCrop(crop!)) {
      return crop!;
    }
    return math.Rectangle(0, 0, width ?? 0, height ?? 0);
  }

  /// Validates if the crop rectangle is within image bounds
  bool isValidCrop(math.Rectangle<int> cropRect) {
    if (width == null || height == null) return false;
    
    return cropRect.left >= 0 &&
           cropRect.top >= 0 &&
           cropRect.right <= width! &&
           cropRect.bottom <= height! &&
           cropRect.width > 0 &&
           cropRect.height > 0;
  }

  /// Supported image MIME types for cropping
  static const List<String> supportedImageTypes = [
    'image/jpeg',
    'image/jpg', 
    'image/png',
    'image/gif',
    'image/webp',
  ];

  /// Checks if a MIME type represents a supported image
  static bool _isImageMimeType(String? mimeType) {
    AppLogger.debug('Checking MIME type: $mimeType', component: 'ImageFileEntry');
    if (mimeType == null) {
      AppLogger.debug('MIME type is null, returning false', component: 'ImageFileEntry');
      return false;
    }
    final result = supportedImageTypes.contains(mimeType.toLowerCase());
    AppLogger.debug('Supported types: $supportedImageTypes', component: 'ImageFileEntry');
    AppLogger.debug('Is supported: $result', component: 'ImageFileEntry');
    return result;
  }

  /// Factory method to create ImageFileEntry from regular FileEntry
  factory ImageFileEntry.fromFileEntry(FileEntry entry) {
    // Extract image-specific data from metadata if available
    final imageData = entry.metadata['image_data'] as Map<String, dynamic>?;
    final cropData = entry.metadata['crop_data'] as Map<String, dynamic>?;
    
    return ImageFileEntry(
      id: entry.id,
      name: entry.name,
      isFolder: entry.isFolder,
      size: entry.size,
      mimeType: entry.mimeType,
      createdAt: entry.createdAt,
      modifiedAt: entry.modifiedAt,
      parents: entry.parents,
      thumbnailUrl: entry.thumbnailUrl,
      hasThumbnail: entry.hasThumbnail,
      thumbnailVersion: entry.thumbnailVersion,
      downloadUrl: entry.downloadUrl,
      canDownload: entry.canDownload,
      canDelete: entry.canDelete,
      canShare: entry.canShare,
      metadata: entry.metadata,
      width: imageData?['width'] as int?,
      height: imageData?['height'] as int?,
      crop: _cropFromJson(cropData),
      blurHash: imageData?['blurHash'] as String?,
    );
  }

  /// Attempts to create ImageFileEntry from FileEntry if it's an image
  static ImageFileEntry? tryCreateImageFileEntry(FileEntry entry) {
    if (!_isImageMimeType(entry.mimeType)) return null;
    return ImageFileEntry.fromFileEntry(entry);
  }

  @override
  ImageFileEntry copyWith({
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
    int? width,
    int? height,
    math.Rectangle<int>? crop,
    String? blurHash,
  }) {
    // Create updated metadata with image and crop data
    final updatedMetadata = Map<String, dynamic>.from(metadata ?? this.metadata);
    
    // Store image data in metadata
    final imageData = <String, dynamic>{};
    final finalWidth = width ?? this.width;
    final finalHeight = height ?? this.height;
    final finalBlurHash = blurHash ?? this.blurHash;
    
    if (finalWidth != null) imageData['width'] = finalWidth;
    if (finalHeight != null) imageData['height'] = finalHeight;
    if (finalBlurHash != null) imageData['blurHash'] = finalBlurHash;
    if (imageData.isNotEmpty) updatedMetadata['image_data'] = imageData;
    
    // Store crop data in metadata
    final cropRect = crop ?? this.crop;
    if (cropRect != null) {
      updatedMetadata['crop_data'] = _cropToJson(cropRect);
    } else {
      updatedMetadata.remove('crop_data');
    }

    return ImageFileEntry(
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
      metadata: updatedMetadata,
      width: width ?? this.width,
      height: height ?? this.height,
      crop: cropRect,
      blurHash: blurHash ?? this.blurHash,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    
    // Image data is already stored in metadata by copyWith method
    // So we don't need to add it again here
    
    return json;
  }

  /// Creates ImageFileEntry from JSON map
  factory ImageFileEntry.fromJson(Map<String, dynamic> json) {
    final baseEntry = FileEntry.fromJson(json);
    return ImageFileEntry.fromFileEntry(baseEntry);
  }

  /// Converts Rectangle<int> to JSON map
  static Map<String, dynamic> _cropToJson(math.Rectangle<int> crop) {
    return {
      'left': crop.left,
      'top': crop.top,
      'width': crop.width,
      'height': crop.height,
    };
  }

  /// Converts JSON map to Rectangle<int>
  static math.Rectangle<int>? _cropFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    
    try {
      return math.Rectangle<int>(
        json['left'] as int,
        json['top'] as int,
        json['width'] as int,
        json['height'] as int,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'ImageFileEntry(id: $id, name: $name, size: ${width}x$height, crop: $crop)';
  }
}