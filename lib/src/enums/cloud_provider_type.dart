/// Cloud provider types supported by the file cloud system
/// 
/// This enum provides type-safe identification of cloud storage providers
/// and eliminates the need for string-based provider identification.
enum CloudProviderType {
  /// Google Drive cloud storage provider
  googleDrive('Google Drive'),
  
  /// Microsoft OneDrive cloud storage provider  
  oneDrive('OneDrive'),
  
  /// Dropbox cloud storage provider
  dropbox('Dropbox'),
  
  /// Custom/Enterprise cloud storage provider
  custom('Custom Provider'),
  
  /// Local development server (for testing)
  localServer('Local Server');

  /// Creates a CloudProviderType with the given display name
  const CloudProviderType(this.displayName);
  
  /// Human-readable display name for this provider
  final String displayName;
  
  /// Returns the provider identifier string for backwards compatibility
  /// This should be phased out in favor of direct enum usage
  @Deprecated('Use enum directly instead of string identifier')
  String get identifier => name;
}