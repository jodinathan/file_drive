import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:file_drive/src/providers/base/cloud_provider.dart';
import 'package:file_drive/src/models/oauth_types.dart';
import 'package:file_drive/src/models/file_drive_config.dart';
import 'package:file_drive/src/models/cloud_item.dart';
import 'package:file_drive/src/models/cloud_folder.dart';
import 'package:file_drive/src/models/file_operations.dart';
import 'package:file_drive/src/models/search_models.dart';
import 'test_config.dart';

/// Test helpers and utilities for FileDrive tests

/// Timeout wrapper for preventing infinite loops in tests
class TestTimeouts {
  static const Duration unitTestTimeout = Duration(seconds: 30);
  static const Duration widgetTestTimeout = Duration(minutes: 1);
  static const Duration integrationTestTimeout = Duration(minutes: 2);
  static const Duration streamEventTimeout = Duration(milliseconds: 500);
  
  /// Wraps any Future with a timeout to prevent infinite loops
  static Future<T> withTimeout<T>(
    Future<T> future, {
    Duration? timeout,
    String? description,
  }) async {
    final actualTimeout = timeout ?? unitTestTimeout;
    try {
      return await future.timeout(
        actualTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Test timeout after ${actualTimeout.inSeconds}s${description != null ? ': $description' : ''}',
            actualTimeout,
          );
        },
      );
    } catch (e) {
      print('Test timeout error: $e');
      rethrow;
    }
  }
  
  /// Wraps widget test operations with timeout
  static Future<T> withWidgetTimeout<T>(
    Future<T> future, {
    String? description,
  }) {
    return withTimeout(future, timeout: widgetTestTimeout, description: description);
  }
  
  /// Wraps integration test operations with timeout
  static Future<T> withIntegrationTimeout<T>(
    Future<T> future, {
    String? description,
  }) {
    return withTimeout(future, timeout: integrationTestTimeout, description: description);
  }
}

/// Resource management for preventing memory leaks in tests
class TestResourceManager {
  static final List<StreamSubscription> _subscriptions = [];
  static final List<Timer> _timers = [];
  static final List<Completer> _completers = [];
  
  /// Register a stream subscription for automatic disposal
  static StreamSubscription<T> registerSubscription<T>(StreamSubscription<T> subscription) {
    _subscriptions.add(subscription);
    return subscription;
  }
  
  /// Register a timer for automatic disposal
  static Timer registerTimer(Timer timer) {
    _timers.add(timer);
    return timer;
  }
  
  /// Register a completer for automatic completion on timeout
  static Completer<T> registerCompleter<T>(Completer<T> completer) {
    _completers.add(completer);
    return completer;
  }
  
  /// Dispose all registered resources
  static void disposeAll() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    
    for (final completer in _completers) {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Test cleanup', TestTimeouts.unitTestTimeout));
      }
    }
    _completers.clear();
  }
  
  /// Create a safe stream subscription that's automatically managed
  static StreamSubscription<T> safeStreamListen<T>(
    Stream<T> stream,
    void Function(T) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    return registerSubscription(subscription);
  }
}

/// Safe widget test utilities
class SafeWidgetTestUtils {
  /// Safe pump that prevents infinite rebuild loops
  static Future<void> safePump(WidgetTester tester, [Duration? duration]) async {
    return TestTimeouts.withWidgetTimeout(
      tester.pump(duration),
      description: 'Widget pump operation',
    );
  }
  
  /// Safe pumpAndSettle that prevents infinite animation loops
  static Future<void> safePumpAndSettle(
    WidgetTester tester, [
    Duration timeout = const Duration(seconds: 10),
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
    Duration interval = const Duration(milliseconds: 100),
  ]) async {
    return TestTimeouts.withWidgetTimeout(
      tester.pumpAndSettle(timeout, phase, interval),
      description: 'Widget pumpAndSettle operation',
    );
  }
  
  /// Wait for widget to be in expected state with timeout
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < timeout) {
      await tester.pump(interval);
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    
    throw TimeoutException(
      'Widget not found within ${timeout.inSeconds}s: $finder',
      timeout,
    );
  }
}

/// Mock implementation of CloudProvider for testing
class MockTestCloudProvider extends BaseCloudProvider {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userInfo;
  String _providerName;
  String _providerIcon;
  Color _providerColor;
  ProviderCapabilities _capabilities;
  bool _lastAuthenticateCalled = false;

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

  /// Track if authenticate was called
  bool get lastAuthenticateCalled => _lastAuthenticateCalled;

  void resetAuthenticateFlag() {
    _lastAuthenticateCalled = false;
  }

  @override
  Future<bool> authenticate() async {
    _lastAuthenticateCalled = true;
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

  // File operation stubs - not used in current tests
  @override
  Future<List<CloudItem>> listItems(String? folderId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<CloudFolder> createFolder(String name, String? parentId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Stream<UploadProgress> uploadFile(FileUpload fileUpload) {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<void> deleteItem(String itemId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<void> moveItem(String itemId, String newParentId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<void> renameItem(String itemId, String newName) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<List<CloudItem>> searchItems(SearchQuery query) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<CloudItem?> getItemById(String itemId) async {
    throw UnimplementedError('Test implementation');
  }

  @override
  Future<List<CloudFolder>> getFolderPath(String? folderId) async {
    throw UnimplementedError('Test implementation');
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
      redirectUri: redirectUri ?? 'http://localhost:${TestServerConfig.port}/callback',
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
    // Clean up test environment and dispose resources to prevent memory leaks
    TestResourceManager.disposeAll();
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
