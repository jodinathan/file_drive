/// Factory for creating appropriate token storage based on platform
library;

import 'package:flutter/foundation.dart';
import 'token_storage.dart';
import 'shared_preferences_token_storage.dart';
import 'hybrid_token_storage.dart';

// Conditional imports
import 'web_token_storage_stub.dart'
    if (dart.library.html) 'web_token_storage.dart';

/// Factory class for creating token storage instances
class TokenStorageFactory {
  /// Create appropriate token storage for current platform
  static TokenStorage create() {
    print('🏭 [Factory] Creating token storage for platform: ${kIsWeb ? "Web" : "Desktop"}');
    if (kIsWeb) {
      print('🏭 [Factory] Using WebTokenStorage');
      return WebTokenStorage();
    } else {
      print('🏭 [Factory] Using HybridTokenStorage for better persistence');
      return HybridTokenStorage();
    }
  }
}