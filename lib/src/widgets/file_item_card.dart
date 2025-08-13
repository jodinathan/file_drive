import 'package:flutter/material.dart';
import '../models/file_entry.dart';

/// A reusable card widget for displaying file entries
class FileItemCard extends StatefulWidget {
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

  const FileItemCard({
    super.key,
    required this.file,
    this.isSelected = false,
    this.showCheckbox = false,
    this.onTap,
    this.onCheckboxChanged,
  });

  @override
  State<FileItemCard> createState() => _FileItemCardState();
}

class _FileItemCardState extends State<FileItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _getBackgroundColor(theme),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showCheckbox) ...[
                Checkbox(
                  value: widget.isSelected,
                  onChanged: widget.onCheckboxChanged,
                ),
                const SizedBox(width: 8),
              ],
              _buildFileIcon(theme),
            ],
          ),
          title: Text(
            widget.file.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: _buildSubtitle(),
          onTap: widget.onTap,
          selected: widget.isSelected,
        ),
      ),
    );
  }

  Color _getBackgroundColor(ThemeData theme) {
    if (widget.isSelected) {
      return theme.colorScheme.primaryContainer.withOpacity(0.3);
    } else if (_isHovered) {
      return theme.colorScheme.surfaceVariant.withOpacity(0.5);
    } else {
      return Colors.transparent;
    }
  }

  Widget _buildFileIcon(ThemeData theme) {
    return Icon(
      widget.file.isFolder ? Icons.folder : Icons.description,
      color: widget.file.isFolder
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface,
    );
  }

  Widget? _buildSubtitle() {
    final lines = <String>[];
    
    // Primeira linha: tamanho ou "Pasta"
    if (widget.file.size != null) {
      lines.add('${(widget.file.size! / 1024 / 1024).toStringAsFixed(1)} MB');
    } else if (widget.file.isFolder) {
      lines.add('Pasta');
    }
    
    // Segunda linha: informações de data
    final dateParts = <String>[];
    if (widget.file.createdAt != null) {
      dateParts.add('Criado: ${_formatDate(widget.file.createdAt!)}');
    }
    if (widget.file.modifiedAt != null) {
      dateParts.add('Modificado: ${_formatDate(widget.file.modifiedAt!)}');
    }
    
    if (dateParts.isNotEmpty) {
      lines.add(dateParts.join(' • '));
    }
    
    return lines.isNotEmpty
        ? Text(
            lines.join('\n'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.2),
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