/// OAuth scopes that can be requested from cloud storage providers
///
/// This enum provides a generic, provider-agnostic way to specify
/// OAuth permissions needed by the application.
enum OAuthScope {
  /// Read access to user's files
  readFiles,

  /// Write access to user's files (create, modify, delete)
  writeFiles,

  /// Permission to create folders/directories
  createFolders,

  /// Permission to delete files and folders
  deleteFiles,

  /// Permission to share files and folders with others
  shareFiles,

  /// Read access to user's profile information
  readProfile,

  /// Access to file metadata (without content)
  readMetadata,

  /// Permission to move files between folders
  moveFiles,

  /// Permission to copy files
  copyFiles,

  /// Permission to rename files and folders
  renameFiles;

  /// Returns a human-readable description of this scope
  String get description {
    switch (this) {
      case OAuthScope.readFiles:
        return 'Read access to your files';
      case OAuthScope.writeFiles:
        return 'Create, modify and delete your files';
      case OAuthScope.createFolders:
        return 'Create new folders';
      case OAuthScope.deleteFiles:
        return 'Delete files and folders';
      case OAuthScope.shareFiles:
        return 'Share files and folders with others';
      case OAuthScope.readProfile:
        return 'Access to your profile information';
      case OAuthScope.readMetadata:
        return 'Read file information without content';
      case OAuthScope.moveFiles:
        return 'Move files between folders';
      case OAuthScope.copyFiles:
        return 'Copy files and folders';
      case OAuthScope.renameFiles:
        return 'Rename files and folders';
    }
  }

  static const required = {
    OAuthScope.readFiles,
    OAuthScope.writeFiles,
    OAuthScope.createFolders,
    OAuthScope.readProfile,
  };
}
