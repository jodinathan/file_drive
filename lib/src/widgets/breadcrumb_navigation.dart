/// Breadcrumb navigation widget for folder hierarchy
library;

import 'package:flutter/material.dart';
import '../models/cloud_folder.dart';
import '../models/file_drive_config.dart';

/// Widget for displaying and navigating folder hierarchy
class BreadcrumbNavigation extends StatelessWidget {
  final List<CloudFolder> currentPath;
  final Function(String?) onNavigate;
  final FileDriveTheme theme;
  
  const BreadcrumbNavigation({
    Key? key,
    required this.currentPath,
    required this.onNavigate,
    required this.theme,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Home button
          InkWell(
            onTap: () => onNavigate(null),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.home,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Home',
                    style: theme.typography.body.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Path segments
          ...currentPath.asMap().entries.map((entry) {
            final index = entry.key;
            final folder = entry.value;
            final isLast = index == currentPath.length - 1;
            
            return Row(
              children: [
                // Separator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                
                // Folder name
                if (isLast)
                  Text(
                    folder.name,
                    style: theme.typography.body.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  InkWell(
                    onTap: () => onNavigate(folder.id),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        folder.name,
                        style: theme.typography.body.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }).toList(),
          
          // Spacer to push overflow menu to the right
          const Spacer(),
          
          // Overflow menu for small screens
          if (currentPath.length > 3)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              itemBuilder: (context) => currentPath.map((folder) {
                return PopupMenuItem<String>(
                  value: folder.id,
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(folder.name),
                    ],
                  ),
                );
              }).toList(),
              onSelected: onNavigate,
            ),
        ],
      ),
    );
  }
}

/// Compact breadcrumb for mobile layouts
class CompactBreadcrumbNavigation extends StatelessWidget {
  final List<CloudFolder> currentPath;
  final Function(String?) onNavigate;
  final FileDriveTheme theme;
  
  const CompactBreadcrumbNavigation({
    Key? key,
    required this.currentPath,
    required this.onNavigate,
    required this.theme,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final currentFolder = currentPath.isNotEmpty ? currentPath.last : null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          if (currentPath.isNotEmpty)
            IconButton(
              onPressed: () {
                if (currentPath.length > 1) {
                  onNavigate(currentPath[currentPath.length - 2].id);
                } else {
                  onNavigate(null);
                }
              },
              icon: Icon(
                Icons.arrow_back,
                color: theme.colorScheme.primary,
              ),
            ),
          
          // Current folder name or Home
          Expanded(
            child: Text(
              currentFolder?.name ?? 'Home',
              style: theme.typography.title.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Folder menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.folder_open,
              color: theme.colorScheme.primary,
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: null,
                child: Row(
                  children: [
                    Icon(
                      Icons.home,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Home'),
                  ],
                ),
              ),
              ...currentPath.map((folder) {
                return PopupMenuItem<String>(
                  value: folder.id,
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(folder.name),
                    ],
                  ),
                );
              }).toList(),
            ],
            onSelected: onNavigate,
          ),
        ],
      ),
    );
  }
}