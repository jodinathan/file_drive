import 'dart:math';
import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';

import '../models/image_file_entry.dart';
import '../utils/image_utils.dart';

/// Widget for cropping images with ImageFileEntry support
class ImageCropWidget extends StatefulWidget {
  /// Current image entry
  final ImageFileEntry? value;
  
  /// Callback when the image entry changes
  final ValueChanged<ImageFileEntry?> onChanged;
  
  /// Minimum aspect ratio for cropping
  final double? minRatio;
  
  /// Maximum aspect ratio for cropping
  final double? maxRatio;
  
  /// Minimum width for the cropped image
  final int? minWidth;
  
  /// Minimum height for the cropped image
  final int? minHeight;
  
  /// Whether the widget is enabled
  final bool enabled;

  const ImageCropWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.minRatio,
    this.maxRatio,
    this.minWidth,
    this.minHeight,
    this.enabled = true,
  });

  @override
  State<ImageCropWidget> createState() => _ImageCropWidgetState();
}

class _ImageCropWidgetState extends State<ImageCropWidget> {
  late final double ratio;
  CropController? _cropController;
  bool _showCrop = false;
  String? _errorMessage;

  bool get cropEnabled => ratio != 1.0;

  @override
  void initState() {
    super.initState();
    ratio = widget.minRatio ?? widget.maxRatio ?? 1.0;
  }

  Future<void> _initializeCrop() async {
    if (widget.value == null) return;
    
    setState(() {
      _errorMessage = null;
      _showCrop = true;
      _cropController = CropController(
        aspectRatio: ratio,
      );
    });
  }

  void _handleCropComplete() {
    if (_cropController == null || widget.value == null) return;

    try {
      final cropSize = _cropController!.cropSize;
      
      final normalizedCrop = Rectangle<int>(
        cropSize.left.floor(),
        cropSize.top.floor(),
        cropSize.width.floor(),
        cropSize.height.floor(),
      );

      // Validate crop dimensions
      if (widget.minWidth != null && normalizedCrop.width < widget.minWidth!) {
        setState(() {
          _errorMessage = 'Crop width must be at least ${widget.minWidth}px';
        });
        return;
      }
      
      if (widget.minHeight != null && normalizedCrop.height < widget.minHeight!) {
        setState(() {
          _errorMessage = 'Crop height must be at least ${widget.minHeight}px';
        });
        return;
      }

      final updatedEntry = widget.value!.copyWith(crop: normalizedCrop);
      widget.onChanged(updatedEntry);
      _clear();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing crop: $e';
      });
    }
  }

  void _clear() {
    setState(() {
      _showCrop = false;
      _cropController?.dispose();
      _cropController = null;
      _errorMessage = null;
    });
  }

  void _resetCrop() {
    if (widget.value != null) {
      final resetEntry = widget.value!.copyWith(crop: null);
      widget.onChanged(resetEntry);
    }
  }

  Widget _buildImagePreview() {
    if (widget.value == null) {
      return AspectRatio(
        aspectRatio: ratio,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text('No image selected'),
              ],
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: widget.value!.downloadUrl != null
            ? ImageUtils.loadImageFromUrl(widget.value!.downloadUrl!)
            : Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image, size: 64, color: Colors.grey),
                ),
              ),
      ),
    );
  }

  Widget _buildCropDialog() {
    if (!_showCrop || widget.value == null || _cropController == null) {
      return const SizedBox.shrink();
    }

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Crop Image'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _clear,
          ),
          actions: [
            TextButton(
              onPressed: _clear,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _handleCropComplete,
              child: const Text('Done'),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.red[100],
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[800]),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (widget.value?.width == null || widget.value?.height == null) {
                    return const Center(
                      child: Text('Image dimensions not available'),
                    );
                  }

                  // Calculate scaling and minimum size similar to oni implementation
                  final imageWidth = widget.value!.width!.toDouble();
                  final imageHeight = widget.value!.height!.toDouble();
                  
                  final availableWidth = constraints.maxWidth;
                  final availableHeight = constraints.maxHeight;
                  
                  final imageRatio = imageWidth / imageHeight;
                  final screenRatio = availableWidth / availableHeight;
                  
                  double displayWidth;
                  double displayHeight;
                  
                  if (imageRatio > screenRatio) {
                    displayWidth = availableWidth;
                    displayHeight = availableWidth / imageRatio;
                  } else {
                    displayHeight = availableHeight;
                    displayWidth = availableHeight * imageRatio;
                  }
                  
                  final scaleFactorWidth = displayWidth / imageWidth;
                  final scaleFactorHeight = displayHeight / imageHeight;
                  
                  final minScreenWidth = (widget.minWidth ?? 100) * scaleFactorWidth;
                  final minScreenHeight = (widget.minHeight ?? 100) * scaleFactorHeight;
                  
                  final effectiveMinSize = minScreenWidth > minScreenHeight 
                      ? minScreenWidth 
                      : minScreenHeight;

                  return widget.value!.downloadUrl != null
                      ? CropImage(
                          controller: _cropController!,
                          image: Image.network(widget.value!.downloadUrl!),
                          minimumImageSize: effectiveMinSize.ceil().toDouble(),
                        )
                      : const Center(
                          child: Text('Image source not available'),
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildImagePreview(),
        const SizedBox(height: 8),
        Row(
          children: [
            if (widget.value != null) ...[
              if (cropEnabled) ...[
                ElevatedButton.icon(
                  onPressed: widget.enabled ? _initializeCrop : null,
                  icon: const Icon(Icons.crop),
                  label: Text(widget.value!.hasCropData() ? 'Edit Crop' : 'Crop Image'),
                ),
                const SizedBox(width: 8),
                if (widget.value!.hasCropData()) ...[
                  IconButton(
                    onPressed: widget.enabled ? _resetCrop : null,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reset Crop',
                  ),
                  const SizedBox(width: 8),
                ],
              ],
              IconButton(
                onPressed: widget.enabled ? () => widget.onChanged(null) : null,
                icon: const Icon(Icons.delete),
                tooltip: 'Remove Image',
              ),
            ],
          ],
        ),
        if (widget.value?.hasCropData() == true) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.crop, size: 16, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Cropped: ${widget.value!.getEffectiveCrop().width}×${widget.value!.getEffectiveCrop().height}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Show crop dialog overlay
        if (_showCrop) _buildCropDialog(),
      ],
    );
  }

  @override
  void dispose() {
    _cropController?.dispose();
    super.dispose();
  }
}