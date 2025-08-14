import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';
import 'dart:math';

import '../models/image_file_entry.dart';
import '../models/crop_config.dart';
import '../utils/image_utils.dart';
import '../utils/image_dimension_detector.dart';

/// Widget for the dedicated crop panel with two-column layout
class CropPanelWidget extends StatefulWidget {
  /// List of selected image files to crop
  final List<ImageFileEntry> imageFiles;

  /// Crop configuration
  final CropConfig? cropConfig;

  /// Callback when all crops are completed
  final Function(List<ImageFileEntry>) onCropCompleted;

  /// Callback when the crop process is cancelled
  final VoidCallback onCancel;

  const CropPanelWidget({
    super.key,
    required this.imageFiles,
    required this.onCropCompleted,
    required this.onCancel,
    this.cropConfig,
  });

  @override
  State<CropPanelWidget> createState() => _CropPanelWidgetState();
}

class _CropPanelWidgetState extends State<CropPanelWidget> {
  late List<ImageFileEntry> _croppedFiles;
  int _currentIndex = 0;
  CropController? _cropController;
  bool _isLoadingImage = false;
  String? _errorMessage;
  final Map<String, Size> _detectedDimensions = {}; // Cache for detected dimensions

  @override
  void initState() {
    super.initState();
    _croppedFiles = List.from(widget.imageFiles);
    _detectMissingDimensions(); // Detect dimensions for images without them
    _initializeCropController();
  }

  @override
  void dispose() {
    _cropController?.dispose();
    super.dispose();
  }

  /// Detects dimensions for images that don't have them
  Future<void> _detectMissingDimensions() async {
    print('🔍 Starting dimension detection for images without dimensions...');
    
    for (int i = 0; i < _croppedFiles.length; i++) {
      final file = _croppedFiles[i];
      
      // Skip if we already have dimensions
      if (file.width != null && file.height != null && file.width! > 0 && file.height! > 0) {
        print('✅ Image ${file.name} already has dimensions: ${file.width}x${file.height}');
        continue;
      }
      
      // Skip if no download URL
      if (file.downloadUrl == null) {
        print('⚠️ Image ${file.name} has no download URL, skipping dimension detection');
        continue;
      }
      
      try {
        print('🔍 Detecting dimensions for ${file.name}...');
        final imageUrl = ImageDimensionDetector.buildCompleteUrl(file.downloadUrl!);
        final dimensions = await ImageDimensionDetector.detectNetworkImageDimensions(imageUrl);
        
        if (dimensions != null) {
          print('✅ Detected dimensions for ${file.name}: ${dimensions.width.toInt()}x${dimensions.height.toInt()}');
          
          // Cache the dimensions
          _detectedDimensions[file.id] = dimensions;
          
          // Update the file entry with detected dimensions
          final updatedFile = file.copyWith(
            width: dimensions.width.toInt(),
            height: dimensions.height.toInt(),
          );
          
          setState(() {
            _croppedFiles[i] = updatedFile;
          });
        } else {
          print('❌ Failed to detect dimensions for ${file.name}');
        }
      } catch (e) {
        print('❌ Error detecting dimensions for ${file.name}: $e');
      }
    }
    
    print('✅ Dimension detection completed');
  }

  Future<void> _initializeCropController() async {
    if (_currentIndex >= _croppedFiles.length) return;

    setState(() {
      _isLoadingImage = true;
      _errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100)); // Give UI time to update
      
      _cropController?.dispose();
      _cropController = CropController(
        aspectRatio: widget.cropConfig?.effectiveAspectRatio,
        defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
      );
      
      setState(() {
        _isLoadingImage = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingImage = false;
        _errorMessage = 'Error loading image: $e';
      });
    }
  }

  void _applyCrop() {
    if (_cropController == null || _currentIndex >= _croppedFiles.length) return;

    try {
      final cropSize = _cropController!.cropSize;
      final normalizedCrop = Rectangle<int>(
        cropSize.left.floor(),
        cropSize.top.floor(),
        cropSize.width.floor(),
        cropSize.height.floor(),
      );

      // Validate crop dimensions using CropConfig
      if (widget.cropConfig != null && !widget.cropConfig!.isValidCrop(normalizedCrop.width, normalizedCrop.height)) {
        final config = widget.cropConfig!;
        String errorMessage = 'Crop dimensions do not meet requirements:\n';
        
        if (config.minWidth != null && normalizedCrop.width < config.minWidth!) {
          errorMessage += '• Width must be at least ${config.minWidth}px (current: ${normalizedCrop.width}px)\n';
        }
        if (config.minHeight != null && normalizedCrop.height < config.minHeight!) {
          errorMessage += '• Height must be at least ${config.minHeight}px (current: ${normalizedCrop.height}px)\n';
        }
        if (config.maxWidth != null && normalizedCrop.width > config.maxWidth!) {
          errorMessage += '• Width must be at most ${config.maxWidth}px (current: ${normalizedCrop.width}px)\n';
        }
        if (config.maxHeight != null && normalizedCrop.height > config.maxHeight!) {
          errorMessage += '• Height must be at most ${config.maxHeight}px (current: ${normalizedCrop.height}px)\n';
        }
        
        final cropRatio = normalizedCrop.width / normalizedCrop.height;
        if (config.effectiveMinRatio != null && cropRatio < config.effectiveMinRatio!) {
          errorMessage += '• Aspect ratio too low (current: ${cropRatio.toStringAsFixed(2)}, min: ${config.effectiveMinRatio!.toStringAsFixed(2)})\n';
        }
        if (config.effectiveMaxRatio != null && cropRatio > config.effectiveMaxRatio!) {
          errorMessage += '• Aspect ratio too high (current: ${cropRatio.toStringAsFixed(2)}, max: ${config.effectiveMaxRatio!.toStringAsFixed(2)})\n';
        }

        setState(() {
          _errorMessage = errorMessage.trim();
        });
        return;
      }

      // Apply crop to current file
      final updatedEntry = _croppedFiles[_currentIndex].copyWith(crop: normalizedCrop);
      setState(() {
        _croppedFiles[_currentIndex] = updatedEntry;
        _errorMessage = null;
      });

      _moveToNext();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing crop: $e';
      });
    }
  }

  void _moveToNext() {
    if (_currentIndex < _croppedFiles.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _initializeCropController();
    } else {
      // All files processed
      widget.onCropCompleted(_croppedFiles);
    }
  }

  void _selectImage(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      _initializeCropController();
    }
  }

  /// Gets appropriate dimension text for an image
  String _getImageDimensionsText(ImageFileEntry file) {
    if (file.width != null && file.height != null && file.width! > 0 && file.height! > 0) {
      return ImageUtils.formatImageDimensions(file.width!, file.height!);
    }
    
    // Check if we have detected dimensions in cache
    final cachedDimensions = _detectedDimensions[file.id];
    if (cachedDimensions != null) {
      return ImageUtils.formatImageDimensions(
        cachedDimensions.width.toInt(),
        cachedDimensions.height.toInt(),
      );
    }
    
    return 'Detectando...';
  }

  @override
  Widget build(BuildContext context) {
    final showLeftColumn = widget.imageFiles.length > 1;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.imageFiles.length > 1 ? 'Crop Images' : 'Crop Image'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
      ),
      body: Row(
        children: [
          // Left column - Image list (only show if multiple images)
          if (showLeftColumn)
            Container(
              width: 300,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Progress indicator
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Progress',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const Spacer(),
                          Text(
                            '${_currentIndex + 1} of ${_croppedFiles.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_currentIndex + 1) / _croppedFiles.length,
                        backgroundColor: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
                
                // Image list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _croppedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _croppedFiles[index];
                      final isCurrentFile = index == _currentIndex;
                      final isCropped = file.hasCropData();
                      final isCompleted = index < _currentIndex || isCropped;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: isCurrentFile 
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: ListTile(
                          leading: Stack(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.grey[100],
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: file.thumbnailUrl != null
                                      ? Image.network(
                                          _buildCompleteUrl(file.thumbnailUrl!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => 
                                              const Icon(Icons.image, size: 20),
                                        )
                                      : const Icon(Icons.image, size: 20),
                                ),
                              ),
                              if (isCompleted)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: isCropped ? Colors.green : Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCropped ? Icons.crop : Icons.check,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            file.name,
                            style: TextStyle(
                              fontWeight: isCurrentFile ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _getImageDimensionsText(file),
                            style: const TextStyle(fontSize: 10),
                          ),
                          onTap: () => _selectImage(index),
                          trailing: isCurrentFile 
                              ? const Icon(Icons.arrow_forward, size: 16)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Right column - Crop interface
          Expanded(
            child: Column(
              children: [
                // Current image info
                if (_currentIndex < _croppedFiles.length)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _croppedFiles[_currentIndex].name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getImageDimensionsText(_croppedFiles[_currentIndex]),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (widget.cropConfig != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Crop: ${widget.cropConfig!.description}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                
                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Row(
                      children: [
                        Icon(
                          Icons.error,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Crop area
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: _isLoadingImage
                        ? const Center(child: CircularProgressIndicator())
                        : _currentIndex < _croppedFiles.length && _cropController != null
                            ? _buildCropInterface()
                            : const Center(child: Text('No image to crop')),
                  ),
                ),
                
                // Action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      FilledButton(
                        onPressed: _applyCrop,
                        child: Text(
                          _currentIndex == _croppedFiles.length - 1 
                              ? 'Finish' 
                              : 'Next',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a complete URL from a potentially relative URL
  String _buildCompleteUrl(String url) {
    return ImageDimensionDetector.buildCompleteUrl(url);
  }

  Widget _buildCropInterface() {
    final currentFile = _croppedFiles[_currentIndex];
    
    if (currentFile.downloadUrl == null) {
      return const Center(
        child: Text('Image not available for cropping'),
      );
    }

    // Build complete URL if needed
    String imageUrl = _buildCompleteUrl(currentFile.downloadUrl!);

    print('🔍 DEBUG: Loading image for crop with URL: $imageUrl');

    return CropImage(
      controller: _cropController!,
      image: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading image from URL: $imageUrl');
          print('❌ Error: $error');
          return const Center(
            child: Text('Error loading image'),
          );
        },
      ),
      paddingSize: 25.0,
      alwaysMove: true,
    );
  }
}