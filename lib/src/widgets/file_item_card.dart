import 'package:flutter/material.dart';
import '../models/file_entry.dart';

/// A reusable card widget for displaying file entries
class FileItemCard extends StatelessWidget {
  /// The file entry to display
  final FileEntry file;
  
  /// Whether the file is selected
  final bool isSelected;
  
  /// Whether to show a checkbox for selection
  final bool showCheckbox;
  
  /// Callback when the file is tapped
  final VoidCallback? onTap;
  
  /// Callback when the checkbox is changed
  final ValueChanged<bool?>? onCheckboxChanged;
  
  /// Whether to show detailed date information
  final bool showDateInfo;

  const FileItemCard({
    super.key,
    required this.file,
    this.isSelected = false,
    this.showCheckbox = false,
    this.onTap,
    this.onCheckboxChanged,
    this.showDateInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCheckbox) ...[
            Checkbox(
              value: isSelected,
              onChanged: onCheckboxChanged,
            ),
            const SizedBox(width: 8),
          ],
          _buildFileIcon(theme),
        ],
      ),
      title: Text(
        file.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(),
      onTap: onTap,
      selected: isSelected,
    );
  }

  Widget _buildFileIcon(ThemeData theme) {
    return Icon(
      file.isFolder ? Icons.folder : Icons.description,
      color: file.isFolder
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface,
    );
  }

  Widget? _buildSubtitle() {
    final subtitleParts = <String>[];
    
    // Add size information
    if (file.size != null) {
      subtitleParts.add('${(file.size! / 1024 / 1024).toStringAsFixed(1)} MB');
    } else if (file.isFolder) {
      subtitleParts.add('Pasta');
    }
    
    // Add date information if requested
    if (showDateInfo) {
      if (file.modifiedAt != null) {
        subtitleParts.add('Modificado: ${_formatDate(file.modifiedAt!)}');
      }
      if (file.createdAt != null) {
        subtitleParts.add('Criado: ${_formatDate(file.createdAt!)}');
      }
    }
    
    return subtitleParts.isNotEmpty
        ? Text(
            subtitleParts.join(' • '),
            maxLines: showDateInfo ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          )
        : null;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      // Today
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'hoje às $hour:$minute';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'ontem';
    } else if (difference.inDays < 7) {
      // This week
      final weekdays = [
        'domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'
      ];
      return weekdays[date.weekday % 7];
    } else if (difference.inDays < 365) {
      // This year
      final months = [
        'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
        'jul', 'ago', 'set', 'out', 'nov', 'dez'
      ];
      return '${date.day} ${months[date.month - 1]}';
    } else {
      // Previous years
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}