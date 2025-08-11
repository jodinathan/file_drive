/// Cloud folder implementation
library;

import 'package:flutter/material.dart';
import 'cloud_item.dart';

/// Specific implementation for cloud folders
class CloudFolder extends CloudItem {
  final int itemCount;
  final bool isEmpty;
  final FolderPermissions permissions;
  
  CloudFolder({
    required String id,
    required String name,
    String? parentId,
    required DateTime createdAt,
    required DateTime modifiedAt,
    this.itemCount = 0,
    this.permissions = const FolderPermissions(),
    Map<String, dynamic> metadata = const {},
  }) : isEmpty = itemCount == 0,
       super(
    id: id,
    name: name,
    parentId: parentId,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    type: CloudItemType.folder,
    metadata: metadata,
  );
  
  /// Returns formatted item count (e.g., "5 items", "1 item", "Empty")
  String get formattedItemCount {
    if (isEmpty) return 'Empty';
    if (itemCount == 1) return '1 item';
    return '$itemCount items';
  }
  
  /// Returns appropriate icon for the folder
  IconData get folderIcon {
    if (isEmpty) return Icons.folder_outlined;
    return Icons.folder;
  }
  
  /// Returns color for the folder
  Color get folderColor {
    if (isEmpty) return Colors.grey.shade400;
    return Colors.amber.shade600;
  }
  
  /// Returns true if the folder can be navigated into
  bool get canNavigate => permissions.canRead;
  
  /// Returns true if new files can be uploaded to this folder
  bool get canUploadFiles => permissions.canCreateFiles;
  
  /// Returns true if new folders can be created inside this folder
  bool get canCreateSubfolders => permissions.canCreateFolders;
  
  /// Returns true if this folder can be modified
  bool get canModify => permissions.canWrite;
  
  @override
  String toString() => 'CloudFolder{id: $id, name: $name, itemCount: $itemCount}';
}