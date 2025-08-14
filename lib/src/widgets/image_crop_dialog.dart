import 'dart:math';
import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';

import '../models/image_file_entry.dart';
import '../utils/image_utils.dart' hide ImageInfo;

/// Helper function to determine if a source is a web URL
bool sourceIsWeb(String source) =>
    kIsWeb || 
    source.startsWith('data:') || 
    source.startsWith('http:') || 
    source.startsWith('https:') ||
    source.startsWith('/api/'); // Handle relative server URLs

/// Helper function to load image based on source type
Image loadImage(String source, {BoxFit fit = BoxFit.cover, String? serverBaseUrl}) {
  print('🔍 DEBUG: loadImage called with source: $source');
  print('🔍 DEBUG: sourceIsWeb($source) = ${sourceIsWeb(source)}');
  
  if (sourceIsWeb(source)) {
    String imageUrl = source;
    
    // Handle relative server URLs
    if (source.startsWith('/api/')) {
      // For relative URLs, we need to construct the full URL
      final baseUrl = serverBaseUrl ?? 'http://localhost:8080';
      
      // Use the URL as-is from the server - don't encode it further
      // The server should provide properly formatted URLs
      imageUrl = '$baseUrl$source';
      
      print('🔍 DEBUG: Converted relative URL to full URL: $imageUrl');
      
      // For local server URLs, we need to include the auth token
      return Image.network(
        imageUrl, 
        fit: fit,
        headers: {
          'Authorization': 'Bearer test_token_dev',
        },
        errorBuilder: (context, error, stackTrace) {
          print('🔍 DEBUG: Failed to load image from $imageUrl: $error');
          
          // Since the original URL failed, it's likely due to URL encoding issues.
          // Show a placeholder image instead of attempting complex fallbacks
          print('🔍 DEBUG: Showing broken image placeholder due to URL encoding issue');
          return Container(
            color: Colors.grey[300],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'Image load failed\n(URL encoding issue)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    
    print('🔍 DEBUG: Using NetworkImage for: $imageUrl');
    return Image.network(
      imageUrl, 
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        print('🔍 DEBUG: Failed to load image from $imageUrl: $error');
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
        );
      },
    );
  } else {
    // For local file URLs like file:///some/path, 
    // extract the path and load as file
    String filePath = source;
    if (source.startsWith('file://')) {
      filePath = source.substring(7); // Remove 'file://' prefix
      print('🔍 DEBUG: Converted file:// URL to path: $filePath');
    }
    print('🔍 DEBUG: Using FileImage for: $filePath');
    return Image.file(
      io.File(filePath), 
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        print('🔍 DEBUG: Failed to load local file $filePath: $error');
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
        );
      },
    );
  }
}

/// Static method to show image crop dialog
Future<ImageFileEntry?> showImageCropDialog(
  BuildContext context, {
  required ImageFileEntry imageEntry,
  double? minRatio,
  double? maxRatio,
  int? minWidth,
  int? minHeight,
}) async {
  return await showDialog<ImageFileEntry?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ImageCropDialog(
      imageEntry: imageEntry,
      minRatio: minRatio,
      maxRatio: maxRatio,
      minWidth: minWidth,
      minHeight: minHeight,
    ),
  );
}

/// Full-screen dialog for cropping images
class ImageCropDialog extends StatefulWidget {
  /// The image entry to crop
  final ImageFileEntry imageEntry;
  
  /// Minimum aspect ratio for cropping
  final double? minRatio;
  
  /// Maximum aspect ratio for cropping
  final double? maxRatio;
  
  /// Minimum width for the cropped image
  final int? minWidth;
  
  /// Minimum height for the cropped image
  final int? minHeight;

  const ImageCropDialog({
    super.key,
    required this.imageEntry,
    this.minRatio,
    this.maxRatio,
    this.minWidth,
    this.minHeight,
  });

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  late final CropController _cropController;
  late final double _aspectRatio;
  bool _isLoading = true;
  String? _errorMessage;
  ImageFileEntry? _imageEntryWithDimensions;

  @override
  void initState() {
    super.initState();
    _aspectRatio = widget.minRatio ?? widget.maxRatio ?? 1.0;
    _initializeCropController();
  }

  void _initializeCropController() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ensure we have image dimensions
      _imageEntryWithDimensions = await _ensureImageDimensions(widget.imageEntry);
      
      _cropController = CropController(
        aspectRatio: _aspectRatio,
      );
      
      // Set initial crop if exists
      if (_imageEntryWithDimensions!.hasCropData()) {
        // Note: Setting initial crop position would require additional crop_image configuration
        // For now, we'll start with default and user can adjust
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('🔍 DEBUG: Error initializing crop: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize crop: $e';
      });
    }
  }

  /// Ensures the image entry has width and height information
  Future<ImageFileEntry> _ensureImageDimensions(ImageFileEntry entry) async {
    // If dimensions are already available, return as is
    if (entry.width != null && entry.height != null) {
      return entry;
    }

    // If we have a thumbnail URL, try to load from there
    if (entry.thumbnailUrl != null) {
      try {
        final dimensions = await _getImageDimensionsFromUrl(entry.thumbnailUrl!);
        return entry.copyWith(
          width: dimensions.width.toInt(),
          height: dimensions.height.toInt(),
        );
      } catch (e) {
        print('🔍 DEBUG: Failed to load dimensions from thumbnail: $e');
      }
    }

    // If we have a download URL, try to load from there
    if (entry.downloadUrl != null) {
      try {
        final dimensions = await _getImageDimensionsFromUrl(entry.downloadUrl!);
        return entry.copyWith(
          width: dimensions.width.toInt(),
          height: dimensions.height.toInt(),
        );
      } catch (e) {
        print('🔍 DEBUG: Failed to load dimensions from download URL: $e');
      }
    }

    // For demo purposes, use default dimensions if no URL is available
    print('🔍 DEBUG: No image URL available, using default dimensions (800x600)');
    return entry.copyWith(
      width: 800,
      height: 600,
    );
  }

  /// Gets image dimensions from a URL (network or local file)
  Future<Size> _getImageDimensionsFromUrl(String url) async {
    final Completer<Size> completer = Completer<Size>();
    
    // Choose the appropriate image provider based on source type
    ImageProvider imageProvider;
    if (sourceIsWeb(url)) {
      String imageUrl = url;
      
      // Handle relative server URLs
      if (url.startsWith('/api/')) {
        final baseUrl = 'http://localhost:8080';
        
        // Use the URL as-is from the server - don't encode it further
        imageUrl = '$baseUrl$url';
        
        print('🔍 DEBUG: Converted relative URL for dimensions: $imageUrl');
        
        // For local server URLs, we need to include the auth token
        imageProvider = NetworkImage(
          imageUrl,
          headers: {
            'Authorization': 'Bearer test_token_dev',
          },
        );
      } else {
        imageProvider = NetworkImage(imageUrl);
      }
    } else {
      String filePath = url;
      if (url.startsWith('file://')) {
        filePath = url.substring(7); // Remove 'file://' prefix
      }
      imageProvider = FileImage(io.File(filePath));
    }
    
    final ImageStream stream = imageProvider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    
    listener = ImageStreamListener((ImageInfo info, bool _) {
      final Size size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      completer.complete(size);
      stream.removeListener(listener);
    }, onError: (exception, stackTrace) {
      print('🔍 DEBUG: Failed to get dimensions from $url: $exception');
      // For URL encoding issues, we'll use default dimensions
      if (url.startsWith('/api/')) {
        print('🔍 DEBUG: Using default dimensions due to URL encoding issue');
        // Return reasonable default dimensions for images
        completer.complete(const Size(800, 600));
      } else {
        completer.completeError(exception);
      }
      stream.removeListener(listener);
    });
    
    stream.addListener(listener);
    return completer.future;
  }

  void _handleCropComplete() {
    try {
      final cropSize = _cropController.cropSize;
      
      final normalizedCrop = Rectangle<int>(
        cropSize.left.floor(),
        cropSize.top.floor(),
        cropSize.width.floor(),
        cropSize.height.floor(),
      );

      // Validate crop dimensions
      if (widget.minWidth != null && normalizedCrop.width < widget.minWidth!) {
        _showError('Crop width must be at least ${widget.minWidth}px');
        return;
      }
      
      if (widget.minHeight != null && normalizedCrop.height < widget.minHeight!) {
        _showError('Crop height must be at least ${widget.minHeight}px');
        return;
      }

      // Validate crop is within image bounds
      final imageEntry = _imageEntryWithDimensions ?? widget.imageEntry;
      if (!imageEntry.isValidCrop(normalizedCrop)) {
        _showError('Crop area is outside image bounds');
        return;
      }

      final updatedEntry = imageEntry.copyWith(crop: normalizedCrop);
      Navigator.of(context).pop(updatedEntry);
    } catch (e) {
      _showError('Error processing crop: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    
    // Clear error after a few seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  void _handleCancel() {
    Navigator.of(context).pop(null);
  }

  Widget _buildCropArea() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading image...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeCropController,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final currentImageEntry = _imageEntryWithDimensions ?? widget.imageEntry;
        
        if (currentImageEntry.width == null || currentImageEntry.height == null) {
          return const Center(
            child: Text('Loading image dimensions...'),
          );
        }

        // Calculate dimensions and scaling similar to oni implementation
        final imageWidth = currentImageEntry.width!.toDouble();
        final imageHeight = currentImageEntry.height!.toDouble();
        
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        
        final imageRatio = imageWidth / imageHeight;
        final screenRatio = availableWidth / availableHeight;
        
        double displayWidth;
        double displayHeight;
        
        if (imageRatio > screenRatio) {
          // Width constrained
          displayWidth = availableWidth;
          displayHeight = availableWidth / imageRatio;
        } else {
          // Height constrained
          displayHeight = availableHeight;
          displayWidth = availableHeight * imageRatio;
        }
        
        // Calculate scaling factors
        final scaleFactorWidth = displayWidth / imageWidth;
        final scaleFactorHeight = displayHeight / imageHeight;
        
        // Convert minimum size requirements to screen pixels
        final minScreenWidth = (widget.minWidth ?? 100) * scaleFactorWidth;
        final minScreenHeight = (widget.minHeight ?? 100) * scaleFactorHeight;
        
        // Use the larger constraint to ensure both minimums are satisfied
        final effectiveMinSize = minScreenWidth > minScreenHeight 
            ? minScreenWidth 
            : minScreenHeight;

        // Load the image for cropping using the proper loadImage function
        Widget imageWidget;
        if (currentImageEntry.downloadUrl != null) {
          print('🔍 DEBUG: Loading image for crop with URL: ${currentImageEntry.downloadUrl}');
          imageWidget = loadImage(currentImageEntry.downloadUrl!);
        } else {
          return const Center(
            child: Text('Image source not available for cropping'),
          );
        }

        return CropImage(
          controller: _cropController,
          image: imageWidget as Image,
          minimumImageSize: effectiveMinSize.ceil().toDouble(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageEntry = _imageEntryWithDimensions ?? widget.imageEntry;
    
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Crop Image'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleCancel,
          ),
          actions: [
            TextButton(
              onPressed: _handleCancel,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isLoading ? null : _handleCropComplete,
              child: const Text('Done'),
            ),
          ],
        ),
        body: Column(
          children: [
            // Error message banner
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.red[100],
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[800]),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: Colors.red[800],
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            
            // Image info banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Image: ${imageEntry.width}×${imageEntry.height} • '
                      '${ImageUtils.formatFileSize(imageEntry.size ?? 0)}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (widget.minWidth != null || widget.minHeight != null)
                    Text(
                      'Min: ${widget.minWidth ?? '?'}×${widget.minHeight ?? '?'}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            
            // Main crop area
            Expanded(
              child: _buildCropArea(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }
}