import 'package:flutter/material.dart';
import '../models/selection_config.dart';

/// Widget that displays allowed file types as compact text
class SelectionTypeChips extends StatelessWidget {
  final SelectionConfig selectionConfig;

  const SelectionTypeChips({
    super.key,
    required this.selectionConfig,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show if all types are allowed
    if (selectionConfig.allowedMimeTypes == null || 
        selectionConfig.allowedMimeTypes!.isEmpty) {
      return const SizedBox.shrink();
    }

    final typeNames = _getTypeNames();
    final typesText = typeNames.join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            'Allowed types: ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              typesText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  List<String> _getTypeNames() {
    final types = <String>{};
    
    for (final mimeType in selectionConfig.allowedMimeTypes!) {
      if (mimeType == 'image/*') {
        types.add('Images');
      } else if (mimeType == 'video/*') {
        types.add('Videos');
      } else if (mimeType == 'audio/*') {
        types.add('Audio');
      } else if (mimeType == 'text/*') {
        types.add('Text');
      } else if (mimeType == 'application/pdf') {
        types.add('PDF');
      } else if (mimeType.startsWith('application/vnd.ms-') || 
                 mimeType.startsWith('application/vnd.openxmlformats-')) {
        types.add('Office');
      } else if (mimeType.contains('/')) {
        // Extract subtype for specific MIME types
        final parts = mimeType.split('/');
        if (parts.length == 2) {
          types.add(parts[1].toUpperCase());
        }
      } else {
        types.add(mimeType);
      }
    }
    
    return types.toList()..sort();
  }
}