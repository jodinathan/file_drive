/// Stub implementation for non-web platforms
library;

import 'token_storage.dart';
import 'shared_preferences_token_storage.dart';

/// Stub class that returns SharedPreferences storage for non-web platforms
class WebTokenStorage extends SharedPreferencesTokenStorage {
  // This class will never be used on non-web platforms
  // but is needed for conditional imports to work
}