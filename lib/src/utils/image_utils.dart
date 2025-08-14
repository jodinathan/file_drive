import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

/// Type definition for image information
typedef ImageInfo = ({
  int width,
  int height,
  int size,
  String? contentType,
  String source,
  String name
});

/// Utility class for image operations
class ImageUtils {
  ImageUtils._();

  /// Supported image MIME types for cropping
  static const List<String> supportedImageTypes = [
    'image/jpeg',
    'image/jpg', 
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
  ];

  /// Supported image file extensions
  static const List<String> supportedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  ];

  /// Checks if a MIME type represents a supported image
  static bool isImageMimeType(String? mimeType) {
    if (mimeType == null) return false;
    return supportedImageTypes.contains(mimeType.toLowerCase());
  }

  /// Checks if a file extension represents a supported image
  static bool isImageExtension(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return supportedImageExtensions.contains(extension);
  }

  /// Gets image information from a file path
  static Future<ImageInfo> getImageInfo(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final decodedImage = await decodeImageFromList(bytes);
      
      // Get file name from path
      final fileName = imagePath.split('/').last;
      
      // Determine content type
      String? contentType = lookupMimeType(imagePath);
      if (contentType == null) {
        contentType = lookupMimeType('', headerBytes: bytes);
      }

      return (
        source: imagePath,
        width: decodedImage.width,
        height: decodedImage.height,
        size: bytes.length,
        contentType: contentType,
        name: fileName,
      );
    } catch (e) {
      throw ImageLoadException('Failed to load image info from $imagePath: $e');
    }
  }

  /// Gets image information from bytes
  static Future<ImageInfo> getImageInfoFromBytes(Uint8List bytes, String name) async {
    try {
      final decodedImage = await decodeImageFromList(bytes);
      
      // Determine content type from bytes
      final contentType = lookupMimeType('', headerBytes: bytes);

      return (
        source: 'bytes:$name',
        width: decodedImage.width,
        height: decodedImage.height,
        size: bytes.length,
        contentType: contentType,
        name: name,
      );
    } catch (e) {
      throw ImageLoadException('Failed to load image info from bytes: $e');
    }
  }

  /// Loads an image widget from a file path
  static Widget loadImageFromPath(String path) {
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 64,
            ),
          ),
        );
      },
    );
  }

  /// Loads an image widget from a URL
  static Widget loadImageFromUrl(String url) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / 
                  loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 64,
            ),
          ),
        );
      },
    );
  }

  /// Loads an image widget from bytes
  static Widget loadImageFromBytes(Uint8List bytes) {
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 64,
            ),
          ),
        );
      },
    );
  }

  /// Returns the list of supported image MIME types
  static List<String> getSupportedImageTypes() {
    return List.unmodifiable(supportedImageTypes);
  }

  /// Returns the list of supported image file extensions
  static List<String> getSupportedImageExtensions() {
    return List.unmodifiable(supportedImageExtensions);
  }

  /// Validates if an image has minimum dimensions
  static bool validateMinimumDimensions(int width, int height, {int? minWidth, int? minHeight}) {
    if (minWidth != null && width < minWidth) return false;
    if (minHeight != null && height < minHeight) return false;
    return true;
  }

  /// Calculates the aspect ratio of an image
  static double calculateAspectRatio(int width, int height) {
    if (height == 0) return 1.0;
    return width / height;
  }

  /// Validates if an aspect ratio is within acceptable bounds
  static bool validateAspectRatio(double aspectRatio, {double? minRatio, double? maxRatio}) {
    if (minRatio != null && aspectRatio < minRatio) return false;
    if (maxRatio != null && aspectRatio > maxRatio) return false;
    return true;
  }

  /// Formats file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Gets a readable description of image dimensions
  static String formatImageDimensions(int width, int height) {
    return '${width}×${height}';
  }

  /// Gets the file extension from a filename
  static String? getFileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return null;
    return parts.last.toLowerCase();
  }

  /// Determines if a file can be cropped based on its properties
  static bool canBeCropped(String? mimeType, String? fileName) {
    // Check MIME type first
    if (isImageMimeType(mimeType)) return true;
    
    // Fallback to file extension
    if (fileName != null && isImageExtension(fileName)) return true;
    
    return false;
  }

  /// Creates an image provider from various sources
  static ImageProvider createImageProvider(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return NetworkImage(source);
    } else if (source.startsWith('bytes:')) {
      throw ArgumentError('Use createImageProviderFromBytes for byte data');
    } else {
      return FileImage(File(source));
    }
  }

  /// Creates an image provider from bytes
  static ImageProvider createImageProviderFromBytes(Uint8List bytes) {
    return MemoryImage(bytes);
  }
}

/// Exception thrown when image loading fails
class ImageLoadException implements Exception {
  final String message;
  
  const ImageLoadException(this.message);
  
  @override
  String toString() => 'ImageLoadException: $message';
}