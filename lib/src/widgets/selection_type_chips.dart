import 'package:flutter/material.dart';
import '../models/selection_config.dart';

/// Widget that displays allowed file types as chips
class SelectionTypeChips extends StatelessWidget {
  final SelectionConfig selectionConfig;

  const SelectionTypeChips({
    super.key,
    required this.selectionConfig,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show chips if all types are allowed
    if (selectionConfig.allowedMimeTypes == null || 
        selectionConfig.allowedMimeTypes!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(51),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'Allowed file types:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          
          // Type chips
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _buildTypeChips(context),
          ),
          
          // Hint text if provided
          if (selectionConfig.mimeTypeHint != null) ...[
            const SizedBox(height: 4),
            Text(
              selectionConfig.mimeTypeHint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTypeChips(BuildContext context) {
    final typeNames = _getTypeNames();
    
    return typeNames.map((typeName) {
      return Chip(
        label: Text(
          typeName,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        side: BorderSide.none,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }).toList();
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