/// File Cloud Widget - A Flutter widget for accessing cloud storage providers
library;

// Export public models
export 'src/models/file_entry.dart';
export 'src/models/cloud_account.dart';
export 'src/models/account_status.dart';
export 'src/models/provider_capabilities.dart';
export 'src/models/selection_config.dart';
export 'src/models/crop_config.dart';

// Export storage interfaces
export 'src/storage/account_storage.dart';
export 'src/storage/shared_preferences_account_storage.dart';

// Export provider interfaces
export 'src/providers/base_cloud_provider.dart';
export 'src/providers/google_drive_provider.dart';

// Export authentication
export 'src/auth/oauth_config.dart';
export 'src/auth/oauth_manager.dart';

// Export theme and constants
export 'src/theme/app_theme.dart';
export 'src/theme/app_constants.dart';

// Export main widget
export 'src/widgets/file_cloud_widget.dart';
export 'src/widgets/file_item_card.dart';
export 'src/widgets/thumbnail_image.dart';