/// File Cloud Widget - A Flutter widget for accessing cloud storage providers
library;

// Export public models
export 'src/models/file_entry.dart';
export 'src/models/image_file_entry.dart';
export 'src/models/cloud_account.dart';
export 'src/models/account_status.dart';
export 'src/models/provider_capabilities.dart';
export 'src/models/selection_config.dart';
export 'src/models/crop_config.dart';
export 'src/models/provider_configuration.dart';
export 'src/models/base_provider_configuration.dart';
export 'src/models/oauth_provider_configuration.dart';
export 'src/models/local_provider_configuration.dart';
export 'src/models/ready_provider_configuration.dart';

// Export enums
export 'src/enums/cloud_provider_type.dart';
export 'src/enums/oauth_scope.dart';
export 'src/enums/provider_scope_mapper.dart';

// Export storage interfaces
export 'src/storage/account_storage.dart';
export 'src/storage/shared_preferences_account_storage.dart';

// Export provider interfaces
export 'src/providers/base_cloud_provider.dart';
export 'src/providers/oauth_cloud_provider.dart';
export 'src/providers/google_drive_provider.dart';
export 'src/providers/dropbox_provider.dart';
export 'src/providers/custom_provider.dart';
export 'src/providers/local_server_provider.dart';

// Export factory
export 'src/factory/cloud_provider_factory.dart';

// Export authentication
export 'src/auth/oauth_config.dart';
export 'src/auth/oauth_manager.dart';

// Export theme and constants
export 'src/theme/app_theme.dart';
export 'src/theme/app_constants.dart';

// Export utilities
export 'src/utils/app_logger.dart';

// Export main widgets
export 'src/widgets/file_cloud_widget.dart';
export 'src/widgets/file_item_card.dart';
export 'src/widgets/thumbnail_image.dart';
export 'src/widgets/search_bar_widget.dart';
export 'src/widgets/crop_panel_widget.dart';
export 'src/widgets/upload_progress_widget.dart';
export 'src/widgets/upload_list_widget.dart';