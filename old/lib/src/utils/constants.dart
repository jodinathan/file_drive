/// Constants used throughout the FileDrive widget
library;

// Import app configuration
import '../config/app_config.dart';

/// 🖥️ CONFIGURAÇÃO DO SERVIDOR (onde buscar OAuth)
class ServerConfig {
  static const String host = AppConfig.serverHost;
  static const int port = AppConfig.serverPort;
  static const String baseUrl = AppConfig.serverBaseUrl;

  /// 📍 ENDPOINTS
  static const String authEndpoint = AppConfig.authEndpoint;
  static const String callbackEndpoint = '/auth/callback';
  static const String refreshEndpoint = '/auth/refresh';
  static const String revokeEndpoint = '/auth/revoke';
}





/// UI Constants
class UIConstants {
  /// Layout dimensions
  static const double sidebarWidth = 300.0;
  static const double minSidebarWidth = 250.0;
  static const double maxSidebarWidth = 400.0;
  
  /// Spacing
  static const double defaultSpacing = 16.0;
  static const double smallSpacing = 8.0;
  static const double largeSpacing = 24.0;
  
  /// Border radius
  static const double defaultBorderRadius = 8.0;
  static const double smallBorderRadius = 4.0;
  static const double largeBorderRadius = 12.0;
  
  /// Animation durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);
  
  /// Provider colors
  static const Map<String, int> providerColors = {
    'Google Drive': 0xFF4285F4,
    'OneDrive': 0xFF0078D4,
    'Dropbox': 0xFF0061FF,
    'Local': 0xFF757575,
  };
}

/// Error messages
class ErrorMessages {
  static const String authenticationFailed = 'Authentication failed';
  static const String tokenExpired = 'Token has expired';
  static const String networkError = 'Network error occurred';
  static const String invalidCredentials = 'Invalid credentials';
  static const String accessDenied = 'Access denied';
  static const String unknownError = 'An unknown error occurred';
  
  /// Get user-friendly error message
  static String getUserFriendlyMessage(String error) {
    switch (error.toLowerCase()) {
      case 'access_denied':
        return accessDenied;
      case 'invalid_grant':
        return tokenExpired;
      case 'invalid_client':
        return invalidCredentials;
      default:
        return unknownError;
    }
  }
}

/// Provider names
class ProviderNames {
  static const String googleDrive = 'Google Drive';
  static const String oneDrive = 'OneDrive';
  static const String dropbox = 'Dropbox';
  static const String local = 'Local';
}

/// File type constants
class FileTypes {
  static const List<String> imageTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/svg+xml',
  ];
  
  static const List<String> documentTypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain',
  ];
  
  static const List<String> videoTypes = [
    'video/mp4',
    'video/webm',
    'video/ogg',
    'video/avi',
    'video/mov',
  ];
  
  static const List<String> audioTypes = [
    'audio/mp3',
    'audio/wav',
    'audio/ogg',
    'audio/aac',
    'audio/flac',
  ];
}

/// Storage limits
class StorageLimits {
  /// Maximum file size (100MB)
  static const int maxFileSize = 100 * 1024 * 1024;
  
  /// Maximum files per upload
  static const int maxFilesPerUpload = 10;
  
  /// Maximum folder depth
  static const int maxFolderDepth = 20;
}

/// API endpoints for example server
class ServerEndpoints {
  static const String baseUrl = 'http://localhost:8080';
  static const String authGoogle = '$baseUrl/auth/google';
  static const String authCallback = '$baseUrl/auth/callback';
  static const String validateToken = '$baseUrl/auth/validate';
  static const String refreshToken = '$baseUrl/auth/refresh';
  static const String revokeToken = '$baseUrl/auth/revoke';
}
