/// File toolbar widget with actions and controls
library;

import 'package:flutter/material.dart';
import '../models/search_models.dart';
import '../models/file_drive_config.dart';
import '../widgets/file_explorer.dart';

/// Toolbar with file operation buttons and controls
class FileToolbar extends StatelessWidget {
  final VoidCallback? onUpload;
  final VoidCallback? onCreateFolder;
  final VoidCallback? onDelete;
  final Function(String)? onSearch;
  final int selectedCount;
  final ViewMode viewMode;
  final Function(ViewMode) onViewModeChanged;
  final SortOption sortOption;
  final Function(SortOption) onSortChanged;
  final FileDriveTheme theme;
  
  const FileToolbar({
    Key? key,
    this.onUpload,
    this.onCreateFolder,
    this.onDelete,
    this.onSearch,
    required this.selectedCount,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.sortOption,
    required this.onSortChanged,
    required this.theme,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          // Main toolbar row
          Row(
            children: [
              // Action buttons
              if (onUpload != null)
                ElevatedButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              
              if (onUpload != null && onCreateFolder != null)
                const SizedBox(width: 8),
              
              if (onCreateFolder != null)
                OutlinedButton.icon(
                  onPressed: onCreateFolder,
                  icon: const Icon(Icons.create_new_folder, size: 18),
                  label: const Text('Nova Pasta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              
              const SizedBox(width: 16),
              
              // Delete button (shown only when items are selected)
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  tooltip: 'Excluir selecionados',
                ),
              
              const Spacer(),
              
              // Search field
              if (onSearch != null)
                SizedBox(
                  width: 250,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar arquivos...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: onSearch,
                  ),
                ),
              
              if (onSearch != null)
                const SizedBox(width: 16),
              
              // View mode toggle
              _ViewModeToggle(
                viewMode: viewMode,
                onChanged: onViewModeChanged,
                theme: theme,
              ),
              
              const SizedBox(width: 8),
              
              // Sort menu
              _SortMenu(
                sortOption: sortOption,
                onChanged: onSortChanged,
                theme: theme,
              ),
            ],
          ),
          
          // Selection info (shown when items are selected)
          if (selectedCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$selectedCount ${selectedCount == 1 ? 'item selecionado' : 'itens selecionados'}',
                    style: theme.typography.caption.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// View mode toggle widget
class _ViewModeToggle extends StatelessWidget {
  final ViewMode viewMode;
  final Function(ViewMode) onChanged;
  final FileDriveTheme theme;
  
  const _ViewModeToggle({
    required this.viewMode,
    required this.onChanged,
    required this.theme,
  });
  
  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      isSelected: [
        viewMode == ViewMode.grid,
        viewMode == ViewMode.list,
        viewMode == ViewMode.details,
      ],
      onPressed: (index) {
        switch (index) {
          case 0:
            onChanged(ViewMode.grid);
            break;
          case 1:
            onChanged(ViewMode.list);
            break;
          case 2:
            onChanged(ViewMode.details);
            break;
        }
      },
      borderRadius: BorderRadius.circular(4),
      children: const [
        Tooltip(
          message: 'Grade',
          child: Icon(Icons.grid_view, size: 18),
        ),
        Tooltip(
          message: 'Lista',
          child: Icon(Icons.view_list, size: 18),
        ),
        Tooltip(
          message: 'Detalhes',
          child: Icon(Icons.view_headline, size: 18),
        ),
      ],
    );
  }
}

/// Sort options menu
class _SortMenu extends StatelessWidget {
  final SortOption sortOption;
  final Function(SortOption) onChanged;
  final FileDriveTheme theme;
  
  const _SortMenu({
    required this.sortOption,
    required this.onChanged,
    required this.theme,
  });
  
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortOption>(
      icon: Icon(
        Icons.sort,
        color: theme.colorScheme.onSurface,
      ),
      tooltip: 'Ordenar',
      itemBuilder: (context) => SortOption.values.map((option) {
        return PopupMenuItem<SortOption>(
          value: option,
          child: Row(
            children: [
              Icon(
                _getSortIcon(option),
                size: 16,
                color: sortOption == option 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 12),
              Text(
                option.displayName,
                style: TextStyle(
                  fontWeight: sortOption == option 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                  color: sortOption == option 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (sortOption == option) ...[
                const Spacer(),
                Icon(
                  Icons.check,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onSelected: onChanged,
    );
  }
  
  IconData _getSortIcon(SortOption option) {
    switch (option) {
      case SortOption.nameAsc:
      case SortOption.nameDesc:
        return Icons.sort_by_alpha;
      case SortOption.dateAsc:
      case SortOption.dateDesc:
        return Icons.schedule;
      case SortOption.sizeAsc:
      case SortOption.sizeDesc:
        return Icons.data_usage;
      case SortOption.typeAsc:
      case SortOption.typeDesc:
        return Icons.category;
    }
  }
}

/// Compact toolbar for mobile layouts
class CompactFileToolbar extends StatelessWidget {
  final VoidCallback? onUpload;
  final VoidCallback? onCreateFolder;
  final VoidCallback? onDelete;
  final Function(String)? onSearch;
  final int selectedCount;
  final ViewMode viewMode;
  final Function(ViewMode) onViewModeChanged;
  final SortOption sortOption;
  final Function(SortOption) onSortChanged;
  final FileDriveTheme theme;
  
  const CompactFileToolbar({
    Key? key,
    this.onUpload,
    this.onCreateFolder,
    this.onDelete,
    this.onSearch,
    required this.selectedCount,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.sortOption,
    required this.onSortChanged,
    required this.theme,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          // Top row with main actions
          Row(
            children: [
              // More actions menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.add),
                tooltip: 'Adicionar',
                itemBuilder: (context) => [
                  if (onUpload != null)
                    const PopupMenuItem<String>(
                      value: 'upload',
                      child: ListTile(
                        leading: Icon(Icons.upload_file),
                        title: Text('Upload de Arquivos'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (onCreateFolder != null)
                    const PopupMenuItem<String>(
                      value: 'folder',
                      child: ListTile(
                        leading: Icon(Icons.create_new_folder),
                        title: Text('Nova Pasta'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'upload':
                      onUpload?.call();
                      break;
                    case 'folder':
                      onCreateFolder?.call();
                      break;
                  }
                },
              ),
              
              const Spacer(),
              
              // Delete button
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                ),
              
              // View mode
              _ViewModeToggle(
                viewMode: viewMode,
                onChanged: onViewModeChanged,
                theme: theme,
              ),
              
              // Sort menu
              _SortMenu(
                sortOption: sortOption,
                onChanged: onSortChanged,
                theme: theme,
              ),
            ],
          ),
          
          // Search field (if enabled)
          if (onSearch != null) ...[
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar arquivos...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: onSearch,
            ),
          ],
          
          // Selection info
          if (selectedCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$selectedCount selecionado${selectedCount > 1 ? 's' : ''}',
                    style: theme.typography.caption.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}