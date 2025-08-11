/// Cloud item base classes and types
library;

import 'package:flutter/material.dart';

/// Base class for all cloud items (files and folders)
abstract class CloudItem {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final CloudItemType type;
  final Map<String, dynamic> metadata;
  
  CloudItem({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    required this.modifiedAt,
    required this.type,
    this.metadata = const {},
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CloudItem{id: $id, name: $name, type: $type}';
}

/// Enum defining the type of cloud item
enum CloudItemType { file, folder }

/// File permissions structure
class FilePermissions {
  final bool canRead;
  final bool canWrite;
  final bool canDelete;
  final bool canShare;
  
  const FilePermissions({
    this.canRead = true,
    this.canWrite = false,
    this.canDelete = false,
    this.canShare = false,
  });
  
  bool get isReadOnly => canRead && !canWrite && !canDelete;
  bool get hasFullAccess => canRead && canWrite && canDelete && canShare;
}

/// Folder permissions structure
class FolderPermissions {
  final bool canRead;
  final bool canWrite;
  final bool canDelete;
  final bool canCreateFiles;
  final bool canCreateFolders;
  
  const FolderPermissions({
    this.canRead = true,
    this.canWrite = false,
    this.canDelete = false,
    this.canCreateFiles = false,
    this.canCreateFolders = false,
  });
  
  bool get isReadOnly => canRead && !canWrite && !canDelete;
  bool get hasFullAccess => canRead && canWrite && canDelete && canCreateFiles && canCreateFolders;
}