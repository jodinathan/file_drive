import 'dart:async';
import '../test_helpers.dart';

/// Mock implementation of FlutterWebAuth2 to prevent external dependencies and infinite loops
class MockFlutterWebAuth2 {
  static String? _mockResult;
  static Exception? _mockException;
  static Duration _mockDelay = Duration(milliseconds: 100);
  static bool _shouldTimeout = false;
  
  /// Set a successful authentication result
  static void setMockResult(String result) {
    _mockResult = result;
    _mockException = null;
    _shouldTimeout = false;
  }
  
  /// Set an exception to be thrown
  static void setMockException(Exception exception) {
    _mockException = exception;
    _mockResult = null;
    _shouldTimeout = false;
  }
  
  /// Set delay for authentication simulation
  static void setMockDelay(Duration delay) {
    _mockDelay = delay;
  }
  
  /// Set whether authentication should timeout
  static void setShouldTimeout(bool shouldTimeout) {
    _shouldTimeout = shouldTimeout;
  }
  
  /// Reset all mock settings
  static void reset() {
    _mockResult = null;
    _mockException = null;
    _mockDelay = Duration(milliseconds: 100);
    _shouldTimeout = false;
  }
  
  /// Mock authenticate method with timeout protection
  static Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  }) async {
    return TestTimeouts.withTimeout(
      _performAuthentication(),
      timeout: TestTimeouts.integrationTestTimeout,
      description: 'OAuth authentication',
    );
  }
  
  static Future<String> _performAuthentication() async {
    // Simulate network delay
    await Future.delayed(_mockDelay);
    
    if (_shouldTimeout) {
      // Simulate a hanging operation by waiting for a very long time
      throw TimeoutException('OAuth authentication timed out', TestTimeouts.integrationTestTimeout);
    }
    
    if (_mockException != null) {
      throw _mockException!;
    }
    
    return _mockResult ?? 'com.test.app://oauth?code=default_test_code&state=default_test_state';
  }
}

/// OAuth test utilities for safe testing
class OAuthTestUtils {
  /// Create a successful OAuth callback URL
  static String createSuccessCallback({
    String code = 'test_auth_code',
    String state = 'test_state',
    String scheme = 'com.test.app',
  }) {
    return '$scheme://oauth?code=$code&state=$state';
  }
  
  /// Create an OAuth error callback URL
  static String createErrorCallback({
    String error = 'access_denied',
    String? errorDescription,
    String state = 'test_state',
    String scheme = 'com.test.app',
  }) {
    var url = '$scheme://oauth?error=$error&state=$state';
    if (errorDescription != null) {
      url += '&error_description=${Uri.encodeComponent(errorDescription)}';
    }
    return url;
  }
  
  /// Set up mock for successful OAuth flow
  static void setupSuccessfulOAuth({
    String? code,
    String? state,
    String? scheme,
  }) {
    MockFlutterWebAuth2.setMockResult(
      createSuccessCallback(
        code: code ?? 'test_auth_code',
        state: state ?? 'test_state',
        scheme: scheme ?? 'com.test.app',
      ),
    );
  }
  
  /// Set up mock for OAuth error
  static void setupOAuthError({
    String error = 'access_denied',
    String? errorDescription,
    String state = 'test_state',
    String scheme = 'com.test.app',
  }) {
    MockFlutterWebAuth2.setMockResult(
      createErrorCallback(
        error: error,
        errorDescription: errorDescription,
        state: state,
        scheme: scheme,
      ),
    );
  }
  
  /// Set up mock for OAuth cancellation
  static void setupOAuthCancellation() {
    MockFlutterWebAuth2.setMockException(
      Exception('User canceled OAuth authentication'),
    );
  }
  
  /// Set up mock for OAuth timeout
  static void setupOAuthTimeout() {
    MockFlutterWebAuth2.setShouldTimeout(true);
  }
}