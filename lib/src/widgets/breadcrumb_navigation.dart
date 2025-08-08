/// Breadcrumb navigation widget for folder hierarchy
library;

import 'package:flutter/material.dart';
import '../models/cloud_folder.dart';
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';

/// Widget for displaying and navigating folder hierarchy
class BreadcrumbNavigation extends StatefulWidget {
  final List<CloudFolder> currentPath;
  final Function(String?) onNavigate;
  final FileDriveTheme theme;
  final CloudProvider? provider;
  
  const BreadcrumbNavigation({
    Key? key,
    required this.currentPath,
    required this.onNavigate,
    required this.theme,
    this.provider,
  }) : super(key: key);
  
  @override
  State<BreadcrumbNavigation> createState() => _BreadcrumbNavigationState();
}

class _BreadcrumbNavigationState extends State<BreadcrumbNavigation> {
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: widget.theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Home button
          InkWell(
            onTap: () => widget.onNavigate(null),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.home,
                    size: 16,
                    color: widget.theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Home',
                    style: widget.theme.typography.body.copyWith(
                      color: widget.theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Path segments
          ...widget.currentPath.asMap().entries.map((entry) {
            final index = entry.key;
            final folder = entry.value;
            final isLast = index == widget.currentPath.length - 1;
            
            return Row(
              children: [
                // Separator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: widget.theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                
                // Folder name
                if (isLast)
                  Text(
                    folder.name,
                    style: widget.theme.typography.body.copyWith(
                      color: widget.theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  InkWell(
                    onTap: () => widget.onNavigate(folder.id),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        folder.name,
                        style: widget.theme.typography.body.copyWith(
                          color: widget.theme.colorScheme.primary,
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
          if (widget.currentPath.length > 3)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz,
                color: widget.theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              itemBuilder: (context) => widget.currentPath.map((folder) {
                return PopupMenuItem<String>(
                  value: folder.id,
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder,
                        size: 16,
                        color: widget.theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(folder.name),
                    ],
                  ),
                );
              }).toList(),
              onSelected: widget.onNavigate,
            ),
        ],
      ),
    );
  }
}