import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:file_drive/src/providers/base/cloud_provider.dart';
import 'package:file_drive/src/models/oauth_types.dart';
import 'package:file_drive/src/models/file_drive_config.dart';
import 'dart:async';

/// Test helpers and utilities for FileDrive tests

/// Mock implementation of CloudProvider for testing
class MockTestCloudProvider extends BaseCloudProvider {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userInfo;
  String _providerName;
  String _providerIcon;
  Color _providerColor;
  ProviderCapabilities _capabilities;

  MockTestCloudProvider({
    String providerName = 'Test Provider',
    String providerIcon = 'test_icon.svg',
    Color providerColor = Colors.blue,
    ProviderCapabilities? capabilities,
  }) : _providerName = providerName,
       _providerIcon = providerIcon,
       _providerColor = providerColor,
       _capabilities = capabilities ?? ProviderCapabilities.standard();

  @override
  String get providerName => _providerName;

  @override
  String get providerIcon => _providerIcon;

  @override
  Color get providerColor => _providerColor;

  @override
  ProviderCapabilities get capabilities => _capabilities;

  @override
  Future<bool> authenticate() async {
    updateStatus(ProviderStatus.connecting);
    await Future.delayed(Duration(milliseconds: 100));
    _isAuthenticated = true;
    updateStatus(ProviderStatus.connected);
    return true;
  }

  @override
  Future<void> logout() async {
    _isAuthenticated = false;
    _userInfo = null;
    updateStatus(ProviderStatus.disconnected);
  }

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<Map<String, dynamic>?> fetchUserInfo() async {
    return _userInfo;
  }

  @override
  Future<bool> performAuthValidation() async {
    return _isAuthenticated;
  }

  @override
  Future<bool> performAuthRefresh() async {
    return _isAuthenticated;
  }

  // Test helpers
  void setAuthenticated(bool authenticated) {
    _isAuthenticated = authenticated;
    updateStatus(authenticated ? ProviderStatus.connected : ProviderStatus.disconnected);
  }

  void setUserInfo(Map<String, dynamic>? userInfo) {
    _userInfo = userInfo;
  }

  void simulateError() {
    updateStatus(ProviderStatus.error);
  }

  void simulateTokenExpired() {
    updateStatus(ProviderStatus.tokenExpired);
  }
}

/// Test utilities
class TestUtils {
  /// Create a test widget wrapped in MaterialApp
  static Widget wrapInMaterialApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  /// Create a test FileDriveConfig with mock providers
  static FileDriveConfig createTestConfig({
    List<CloudProvider>? providers,
    FileDriveTheme? theme,
  }) {
    return FileDriveConfig(
      providers: providers ?? [MockTestCloudProvider()],
      theme: theme ?? FileDriveTheme.light(),
    );
  }

  /// Create multiple test providers
  static List<CloudProvider> createTestProviders(int count) {
    return List.generate(count, (index) => MockTestCloudProvider(
      providerName: 'Test Provider ${index + 1}',
      providerColor: Colors.primaries[index % Colors.primaries.length],
    ));
  }

  /// Wait for all microtasks to complete
  static Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(Duration.zero);
  }

  /// Create a test OAuth callback
  static OAuthCallback createTestCallback({
    String? code,
    String? state,
    String? error,
    String? errorDescription,
  }) {
    if (error != null) {
      return OAuthCallback(
        error: error,
        errorDescription: errorDescription,
        state: state,
      );
    }
    return OAuthCallback(
      code: code ?? 'test_code',
      state: state ?? 'test_state',
    );
  }

  /// Create a test AuthResult
  static AuthResult createTestAuthResult({
    bool success = true,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    if (success) {
      return AuthResult.success(
        accessToken: accessToken ?? 'test_access_token',
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        metadata: metadata ?? {},
      );
    } else {
      return AuthResult.failure(error ?? 'Test error');
    }
  }

  /// Create test OAuth parameters
  static OAuthParams createTestOAuthParams({
    String? clientId,
    String? redirectUri,
    List<String>? scopes,
    String? state,
  }) {
    return OAuthParams(
      clientId: clientId ?? 'test_client_id',
      redirectUri: redirectUri ?? 'http://localhost:8080/callback',
      scopes: scopes ?? ['scope1', 'scope2'],
      state: state,
    );
  }
}

/// Custom matchers for testing
class TestMatchers {
  /// Matcher for ProviderStatus
  static Matcher isProviderStatus(ProviderStatus expected) {
    return equals(expected);
  }

  /// Matcher for checking if a provider is authenticated
  static Matcher isAuthenticated() {
    return predicate<CloudProvider>((provider) => provider.isAuthenticated, 'is authenticated');
  }

  /// Matcher for checking if a provider is not authenticated
  static Matcher isNotAuthenticated() {
    return predicate<CloudProvider>((provider) => !provider.isAuthenticated, 'is not authenticated');
  }

  /// Matcher for checking if an AuthResult is successful
  static Matcher isSuccessfulAuthResult() {
    return predicate<AuthResult>((result) => result.success, 'is successful auth result');
  }

  /// Matcher for checking if an AuthResult is failed
  static Matcher isFailedAuthResult() {
    return predicate<AuthResult>((result) => !result.success, 'is failed auth result');
  }

  /// Matcher for checking if an OAuthCallback is successful
  static Matcher isSuccessfulCallback() {
    return predicate<OAuthCallback>((callback) => callback.isSuccess, 'is successful callback');
  }

  /// Matcher for checking if an OAuthCallback has error
  static Matcher hasCallbackError() {
    return predicate<OAuthCallback>((callback) => callback.hasError, 'has callback error');
  }
}

/// Test data generators
class TestDataGenerator {
  static const List<String> sampleProviderNames = [
    'Google Drive',
    'Dropbox',
    'OneDrive',
    'Box',
    'iCloud Drive',
  ];

  static const List<Color> sampleColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
  ];

  /// Generate random provider name
  static String randomProviderName() {
    return sampleProviderNames[DateTime.now().millisecondsSinceEpoch % sampleProviderNames.length];
  }

  /// Generate random color
  static Color randomColor() {
    return sampleColors[DateTime.now().millisecondsSinceEpoch % sampleColors.length];
  }

  /// Generate test user info
  static Map<String, dynamic> generateUserInfo({
    String? name,
    String? email,
    String? id,
  }) {
    return {
      'id': id ?? 'test_user_${DateTime.now().millisecondsSinceEpoch}',
      'name': name ?? 'Test User',
      'email': email ?? 'test@example.com',
      'picture': 'https://example.com/avatar.jpg',
    };
  }

  /// Generate test token data
  static Map<String, dynamic> generateTokenData({
    String? accessToken,
    String? refreshToken,
    int? expiresIn,
  }) {
    return {
      'access_token': accessToken ?? 'access_token_${DateTime.now().millisecondsSinceEpoch}',
      'refresh_token': refreshToken ?? 'refresh_token_${DateTime.now().millisecondsSinceEpoch}',
      'expires_in': expiresIn ?? 3600,
      'token_type': 'Bearer',
      'scope': 'read write',
    };
  }
}

/// Test environment setup
class TestEnvironment {
  static void setUp() {
    // Set up test environment
    WidgetsFlutterBinding.ensureInitialized();
  }

  static void tearDown() {
    // Clean up test environment
  }

  /// Mock HTTP responses for testing
  static Map<String, String> get mockHttpResponses => {
    'userinfo_success': '''
    {
      "id": "123456789",
      "email": "test@example.com",
      "name": "Test User",
      "picture": "https://example.com/avatar.jpg"
    }
    ''',
    'token_success': '''
    {
      "access_token": "test_access_token",
      "refresh_token": "test_refresh_token",
      "expires_in": 3600,
      "token_type": "Bearer"
    }
    ''',
    'error_response': '''
    {
      "error": "invalid_request",
      "error_description": "Invalid request"
    }
    ''',
  };
}
