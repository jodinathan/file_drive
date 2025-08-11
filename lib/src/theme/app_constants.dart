/// UI Constants for consistent spacing and sizing
class AppConstants {
  // Spacing constants
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  
  // Padding constants
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  
  // Margin constants
  static const double marginXS = 4.0;
  static const double marginS = 8.0;
  static const double marginM = 16.0;
  static const double marginL = 24.0;
  static const double marginXL = 32.0;
  
  // Border radius constants
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;
  static const double radiusXXL = 24.0;
  
  // Icon sizes
  static const double iconXS = 16.0;
  static const double iconS = 20.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;
  
  // Avatar sizes
  static const double avatarS = 24.0;
  static const double avatarM = 32.0;
  static const double avatarL = 48.0;
  static const double avatarXL = 64.0;
  
  // Layout dimensions
  static const double providerListWidth = 280.0;
  static const double providerCardHeight = 120.0;
  static const double accountCarouselHeight = 80.0;
  static const double fileItemHeight = 64.0;
  static const double toolbarHeight = 56.0;
  static const double searchFieldHeight = 40.0;
  
  // Minimum touch target size (accessibility)
  static const double minTouchTarget = 44.0;
  
  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // Debounce durations
  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const Duration tapDebounce = Duration(milliseconds: 300);
  
  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;
  
  // File size limits (in bytes)
  static const int maxUploadSize = 100 * 1024 * 1024; // 100MB default
  
  // Supported MIME types for common file filters
  static const List<String> imageMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
    'image/tiff',
    'image/svg+xml',
  ];
  
  static const List<String> documentMimeTypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/rtf',
    'application/rtf',
  ];
  
  static const List<String> videoMimeTypes = [
    'video/mp4',
    'video/avi',
    'video/quicktime',
    'video/x-msvideo',
    'video/webm',
    'video/ogg',
    'video/3gpp',
    'video/x-ms-wmv',
  ];
  
  static const List<String> audioMimeTypes = [
    'audio/mpeg',
    'audio/mp4',
    'audio/wav',
    'audio/ogg',
    'audio/webm',
    'audio/aac',
    'audio/flac',
    'audio/x-ms-wma',
  ];
  
  // Error retry configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  // Cache configuration
  static const Duration cacheExpiry = Duration(minutes: 5);
  static const int maxCacheSize = 100; // number of cached pages
  
  // Provider logos asset paths
  static const Map<String, String> providerLogos = {
    'google_drive': 'assets/logos/google_drive.png',
    'dropbox': 'assets/logos/dropbox.png',
    'onedrive': 'assets/logos/onedrive.png',
  };
  
  // Default fallback logo
  static const String defaultProviderLogo = 'assets/logos/cloud_default.png';
  
  // Validation constants
  static const int maxFolderNameLength = 255;
  static const int maxFileNameLength = 255;
  static const int minSearchQueryLength = 2;
  
  // Selection mode limits
  static const int defaultMinSelection = 1;
  static const int defaultMaxSelection = 10;
}