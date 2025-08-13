import 'package:flutter/material.dart';

/// A widget that displays file thumbnails with fallback support
class ThumbnailImage extends StatefulWidget {
  /// The thumbnail URL to load
  final String? thumbnailUrl;
  
  /// Whether the file has a thumbnail available
  final bool hasThumbnail;
  
  /// The file MIME type for fallback icon selection
  final String? mimeType;
  
  /// Whether this is a folder
  final bool isFolder;
  
  /// Size of the thumbnail widget
  final double size;
  
  /// Border radius for the thumbnail
  final double borderRadius;
  
  /// Callback when thumbnail loading fails
  final VoidCallback? onError;

  const ThumbnailImage({
    super.key,
    this.thumbnailUrl,
    this.hasThumbnail = false,
    this.mimeType,
    this.isFolder = false,
    this.size = 40.0,
    this.borderRadius = 4.0,
    this.onError,
  });

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  bool _hasError = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // Always show fallback icon for folders
    if (widget.isFolder) {
      return _buildFallbackIcon();
    }

    // Show fallback if no thumbnail available or error occurred
    if (!widget.hasThumbnail || widget.thumbnailUrl == null || _hasError) {
      return _buildFallbackIcon();
    }

    // Show loading indicator while thumbnail is loading
    if (_isLoading) {
      return _buildLoadingIndicator();
    }

    // Try to load thumbnail image
    return _buildThumbnailImage();
  }

  Widget _buildThumbnailImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.network(
        widget.thumbnailUrl!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; FileCloudApp/1.0)',
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            });
            return child;
          }
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          });
          return _buildLoadingIndicator();
        },
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          });
          
          // Log thumbnail loading error for debugging
          print('Thumbnail loading failed for URL: ${widget.thumbnailUrl}');
          print('Error: $error');
          
          widget.onError?.call();
          return _buildFallbackIcon();
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    final theme = Theme.of(context);
    final iconData = _getIconForFileType();
    final iconColor = _getIconColor(theme);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Icon(
        iconData,
        size: widget.size * 0.6,
        color: iconColor,
      ),
    );
  }

  IconData _getIconForFileType() {
    if (widget.isFolder) {
      return Icons.folder;
    }

    final mimeType = widget.mimeType?.toLowerCase() ?? '';

    // Image files
    if (mimeType.startsWith('image/')) {
      return Icons.image;
    }

    // Video files
    if (mimeType.startsWith('video/')) {
      return Icons.videocam;
    }

    // Audio files
    if (mimeType.startsWith('audio/')) {
      return Icons.audiotrack;
    }

    // Document types
    if (mimeType.contains('pdf')) {
      return Icons.picture_as_pdf;
    }

    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description;
    }

    if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart;
    }

    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow;
    }

    // Archive files
    if (mimeType.contains('zip') || mimeType.contains('rar') || mimeType.contains('tar')) {
      return Icons.archive;
    }

    // Default file icon
    return Icons.description;
  }

  Color _getIconColor(ThemeData theme) {
    if (widget.isFolder) {
      return theme.colorScheme.primary;
    }

    final mimeType = widget.mimeType?.toLowerCase() ?? '';

    // Color coding for different file types
    if (mimeType.startsWith('image/')) {
      return Colors.green;
    }

    if (mimeType.startsWith('video/')) {
      return Colors.red;
    }

    if (mimeType.startsWith('audio/')) {
      return Colors.orange;
    }

    if (mimeType.contains('pdf')) {
      return Colors.red.shade700;
    }

    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Colors.blue;
    }

    if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Colors.green.shade700;
    }

    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Colors.orange.shade700;
    }

    return theme.colorScheme.onSurfaceVariant;
  }
}

/// A thumbnail widget specifically optimized for file lists
class FileThumbnail extends StatelessWidget {
  /// The file entry to display thumbnail for
  final String? thumbnailUrl;
  final bool hasThumbnail;
  final String? mimeType;
  final bool isFolder;

  const FileThumbnail({
    super.key,
    required this.thumbnailUrl,
    required this.hasThumbnail,
    required this.mimeType,
    required this.isFolder,
  });

  @override
  Widget build(BuildContext context) {
    return ThumbnailImage(
      thumbnailUrl: thumbnailUrl,
      hasThumbnail: hasThumbnail,
      mimeType: mimeType,
      isFolder: isFolder,
      size: 40.0,
      borderRadius: 4.0,
    );
  }
}