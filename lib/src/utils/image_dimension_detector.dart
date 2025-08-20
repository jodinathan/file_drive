import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'app_logger.dart';

/// Utility class for detecting image dimensions
class ImageDimensionDetector {
  /// Detects dimensions from a network image URL
  static Future<Size?> detectNetworkImageDimensions(String imageUrl) async {
    try {
      AppLogger.debug('Detecting dimensions for URL: $imageUrl', component: 'ImageDetector');
      
      // Download image data
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        AppLogger.error('HTTP error ${response.statusCode} for URL: $imageUrl', component: 'ImageDetector');
        return null;
      }
      
      final Uint8List bytes = response.bodyBytes;
      return await _detectDimensionsFromBytes(bytes);
    } catch (e) {
      AppLogger.error('Error detecting dimensions from URL: $e', component: 'ImageDetector');
      return null;
    }
  }

  /// Detects dimensions from image bytes
  static Future<Size?> _detectDimensionsFromBytes(Uint8List bytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      final size = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );
      
      image.dispose();
      codec.dispose();
      
      AppLogger.success('Detected dimensions: ${size.width.toInt()}x${size.height.toInt()}', component: 'ImageDetector');
      return size;
    } catch (e) {
      AppLogger.error('Error detecting dimensions from bytes: $e', component: 'ImageDetector');
      return null;
    }
  }

  /// Detects dimensions from a local file
  static Future<Size?> detectLocalImageDimensions(String filePath) async {
    try {
      AppLogger.debug('Detecting dimensions for local file: $filePath', component: 'ImageDetector');
      
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.error('File does not exist: $filePath', component: 'ImageDetector');
        return null;
      }
      
      final Uint8List bytes = await file.readAsBytes();
      return await _detectDimensionsFromBytes(bytes);
    } catch (e) {
      AppLogger.error('Error detecting dimensions from local file: $e', component: 'ImageDetector');
      return null;
    }
  }

  /// Detects dimensions from an asset image
  static Future<Size?> detectAssetImageDimensions(String assetPath) async {
    try {
      AppLogger.debug('Detecting dimensions for asset: $assetPath', component: 'ImageDetector');
      
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      return await _detectDimensionsFromBytes(bytes);
    } catch (e) {
      AppLogger.error('Error detecting dimensions from asset: $e', component: 'ImageDetector');
      return null;
    }
  }

  /// Builds a complete URL from a potentially relative URL
  static String buildCompleteUrl(String url, {String defaultBaseUrl = 'http://localhost:8080'}) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url; // Already complete
    }
    if (url.startsWith('/')) {
      // Relative URL - build complete URL
      return '$defaultBaseUrl$url';
    }
    return url; // Return as-is for other cases
  }
}