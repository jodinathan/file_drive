import 'package:flutter/material.dart';

import '../models/image_file_entry.dart';
import '../utils/image_utils.dart';
import 'file_item_card.dart';

/// Specialized card for displaying image files
class ImageFileItemCard extends StatelessWidget {
  /// The image file entry to display
  final ImageFileEntry imageEntry;
  
  /// Whether this item is selected
  final bool isSelected;
  
  /// Whether to show selection checkbox
  final bool showCheckbox;
  
  /// Whether the provider supports thumbnails
  final bool providerSupportsThumbnails;
  
  /// Callback when the item is tapped
  final VoidCallback? onTap;
  
  /// Callback when checkbox state changes
  final ValueChanged<bool?>? onCheckboxChanged;

  const ImageFileItemCard({
    super.key,
    required this.imageEntry,
    this.isSelected = false,
    this.showCheckbox = false,
    this.providerSupportsThumbnails = true,
    this.onTap,
    this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context) {
    // For non-image files, fall back to the standard FileItemCard
    if (!imageEntry.isImage) {
      return FileItemCard(
        file: imageEntry,
        isSelected: isSelected,
        showCheckbox: showCheckbox,
        providerSupportsThumbnails: providerSupportsThumbnails,
        onTap: onTap,
        onCheckboxChanged: onCheckboxChanged,
      );
    }

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox (if enabled)
              if (showCheckbox) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: onCheckboxChanged,
                ),
                const SizedBox(width: 8),
              ],
              
              // Image thumbnail or icon
              _buildImageThumbnail(),
              const SizedBox(width: 12),
              
              // File information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File name with crop indicator
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            imageEntry.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isSelected 
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Crop indicator
                        if (imageEntry.hasCropData()) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green[300]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.crop,
                                  size: 12,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Cropped',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Image dimensions and file size
                    Row(
                      children: [
                        if (imageEntry.width != null && imageEntry.height != null) ...[
                          Icon(
                            Icons.photo_size_select_actual,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ImageUtils.formatImageDimensions(
                              imageEntry.width!,
                              imageEntry.height!,
                            ),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (imageEntry.hasCropData()) ...[
                            Text(
                              ' → ${ImageUtils.formatImageDimensions(
                                imageEntry.getEffectiveCrop().width,
                                imageEntry.getEffectiveCrop().height,
                              )}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                        ],
                        
                        if (imageEntry.size != null) ...[
                          Icon(
                            Icons.storage,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ImageUtils.formatFileSize(imageEntry.size!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    // MIME type
                    if (imageEntry.mimeType != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        imageEntry.mimeType!.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a complete URL from a potentially relative URL
  String _buildCompleteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url; // Already complete
    }
    if (url.startsWith('/')) {
      // Relative URL - build complete URL
      // For local server, try to get base URL from current context or use default
      final defaultBaseUrl = 'http://localhost:8080';
      return '$defaultBaseUrl$url';
    }
    return url; // Return as-is for other cases
  }

  Widget _buildImageThumbnail() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: (imageEntry.thumbnailUrl != null && providerSupportsThumbnails)
            ? Image.network(
                _buildCompleteUrl(imageEntry.thumbnailUrl!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildImageIcon(),
              )
            : _buildImageIcon(),
      ),
    );
  }

  Widget _buildImageIcon() {
    IconData iconData;
    Color iconColor;
    
    switch (imageEntry.mimeType?.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        iconData = Icons.image;
        iconColor = Colors.orange[600]!;
        break;
      case 'image/png':
        iconData = Icons.image;
        iconColor = Colors.blue[600]!;
        break;
      case 'image/gif':
        iconData = Icons.gif;
        iconColor = Colors.purple[600]!;
        break;
      case 'image/webp':
        iconData = Icons.image;
        iconColor = Colors.green[600]!;
        break;
      default:
        iconData = Icons.image;
        iconColor = Colors.grey[600]!;
    }

    return Stack(
      children: [
        Center(
          child: Icon(
            iconData,
            color: iconColor,
            size: 24,
          ),
        ),
        if (imageEntry.hasCropData())
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.green[600],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.crop,
                color: Colors.white,
                size: 8,
              ),
            ),
          ),
      ],
    );
  }
}