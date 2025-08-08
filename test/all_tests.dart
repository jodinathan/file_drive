import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'models/oauth_types_test.dart' as oauth_types_tests;
import 'providers/cloud_provider_test.dart' as cloud_provider_tests;
import 'providers/google_drive_provider_test.dart' as google_drive_provider_tests;
import 'widgets/file_drive_widget_test.dart' as file_drive_widget_tests;
import 'widgets/provider_tab_test.dart' as provider_tab_tests;
// import 'server/oauth_handler_test.dart' as oauth_handler_tests; // Temporarily disabled - server not implemented
import 'integration/oauth_flow_integration_test.dart' as integration_tests;

// Import test utilities
import 'test_helpers.dart';

/// Main test suite that runs all tests with timeout protection
void main() {
  // Global test setup
  setUpAll(() {
    TestEnvironment.setUp();
    print('Starting FileDrive Test Suite with timeout protection...');
  });
  
  // Global test cleanup
  tearDownAll(() {
    TestEnvironment.tearDown();
    print('FileDrive Test Suite completed.');
  });
  
  group('FileDrive Test Suite', () {
    group('Models Tests', () {
      oauth_types_tests.main();
    });

    group('Providers Tests', () {
      cloud_provider_tests.main();
      google_drive_provider_tests.main();
    });

    group('Widgets Tests', () {
      file_drive_widget_tests.main();
      provider_tab_tests.main();
    });

    // Server tests temporarily disabled
    // group('Server Tests', () {
    //   oauth_handler_tests.main();
    // });

    group('Integration Tests', () {
      integration_tests.main();
    });
  });
}
