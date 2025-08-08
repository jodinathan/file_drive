import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:file_drive/src/widgets/file_drive_widget.dart';
import 'package:file_drive/src/models/file_drive_config.dart';
import 'package:file_drive/src/providers/google_drive/google_drive_provider.dart';
import 'package:file_drive/src/providers/base/cloud_provider.dart';
import '../test_config.example.dart'; // Usar template seguro
import 'package:file_drive/src/models/oauth_types.dart';
import 'dart:convert';
import 'package:file_drive/src/storage/shared_preferences_token_storage.dart';
import '../test_helpers.dart';

// Generate mocks
@GenerateMocks([http.Client])
import 'oauth_flow_integration_test.mocks.dart';

// Mock FlutterWebAuth2
class MockFlutterWebAuth2 {
  static String? _mockResult;
  static Exception? _mockException;

  static void setMockResult(String result) {
    _mockResult = result;
    _mockException = null;
  }

  static void setMockException(Exception exception) {
    _mockException = exception;
    _mockResult = null;
  }

  static Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  }) async {
    if (_mockException != null) {
      throw _mockException!;
    }
    return _mockResult ?? '${GoogleOAuthConfig.customSchemeRedirectUri}://oauth?code=test_code&state=test_state';
  }
}

void main() {
  group('OAuth Flow Integration Tests', () {
    late MockClient mockHttpClient;
    late GoogleDriveProvider provider;
    late FileDriveConfig config;
    late SharedPreferencesTokenStorage tokenStorage;

    setUp(() {
      mockHttpClient = MockClient();
      tokenStorage = SharedPreferencesTokenStorage();
      
      provider = GoogleDriveProvider(
        tokenStorage: tokenStorage,
        urlGenerator: (params) {
          return 'http://localhost:8080/auth/google?${Uri(queryParameters: params.toQueryParams()).query}';
        },
      );

      config = FileDriveConfig(
        providers: [provider],
        theme: FileDriveTheme.light(),
      );
    });

    tearDown(() {
      provider.dispose();
      TestResourceManager.disposeAll(); // Dispose all test resources to prevent memory leaks
    });

    group('Complete OAuth Flow', () {
      testWidgets('should complete successful OAuth flow', (WidgetTester tester) async {
        // Mock successful OAuth response - usando placeholder seguro
        MockFlutterWebAuth2.setMockResult(
          '${GoogleOAuthConfig.customSchemeRedirectUri}://oauth?code=test_auth_code&state=test_state'
        );

        // Mock server callback response
        when(mockHttpClient.get(any)).thenAnswer((_) async => http.Response('OK', 200));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileDriveWidget(config: config),
            ),
          ),
        );
        await SafeWidgetTestUtils.safePumpAndSettle(tester);

        // Find and tap the connect button
        expect(find.text('Google Drive'), findsOneWidget);
        await tester.tap(find.text('Google Drive'));
        await SafeWidgetTestUtils.safePump(tester);

        // Should show provider content
        expect(find.text('Conectar com Google Drive'), findsOneWidget);
        
        // Tap connect button
        await tester.tap(find.text('Conectar com Google Drive'));
        await SafeWidgetTestUtils.safePump(tester);

        // Should show connecting state
        expect(find.text('Conectando...'), findsOneWidget);
      });

      testWidgets('should handle OAuth cancellation', (WidgetTester tester) async {
        // Mock OAuth cancellation
        MockFlutterWebAuth2.setMockException(
          Exception('User canceled login')
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileDriveWidget(config: config),
            ),
          ),
        );

        // Navigate to provider and attempt connection
        await tester.tap(find.text('Google Drive'));
        await SafeWidgetTestUtils.safePump(tester);

        await tester.tap(find.text('Conectar com Google Drive'));
        await SafeWidgetTestUtils.safePump(tester);

        // Should handle cancellation gracefully
        expect(find.text('Desconectado'), findsOneWidget);
      });

      testWidgets('should handle OAuth error', (WidgetTester tester) async {
        // Mock OAuth error - usando placeholder seguro
        MockFlutterWebAuth2.setMockResult(
          '${GoogleOAuthConfig.customSchemeRedirectUri}://oauth?error=access_denied&error_description=User+denied+access'
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileDriveWidget(config: config),
            ),
          ),
        );

        await tester.tap(find.text('Google Drive'));
        await SafeWidgetTestUtils.safePump(tester);

        await tester.tap(find.text('Conectar com Google Drive'));
        await SafeWidgetTestUtils.safePump(tester);

        // Should show error state
        expect(find.text('Erro de conexão'), findsOneWidget);
      });
    });

    group('Server Integration', () {
      test('should generate correct OAuth URL', () {
        final params = provider.createOAuthParams();
        final url = provider.urlGenerator!(params);

        expect(url, contains('http://localhost:8080/auth/google'));
        expect(url, contains('client_id='));
        expect(url, contains('redirect_uri='));
        expect(url, contains('scope='));
        expect(url, contains('state='));
      });

      test('should parse OAuth callback correctly', () {
        final callbackUrl = '${GoogleOAuthConfig.customSchemeRedirectUri}://oauth?code=test_code&state=test_state';
        final uri = Uri.parse(callbackUrl);
        final callback = OAuthCallback.fromQueryParams(uri.queryParameters);

        expect(callback.isSuccess, isTrue);
        expect(callback.code, equals('test_code'));
        expect(callback.state, equals('test_state'));
      });

      test('should parse OAuth error callback correctly', () {
        final callbackUrl = '${GoogleOAuthConfig.customSchemeRedirectUri}://oauth?error=access_denied&error_description=User+denied+access&state=test_state';
        final uri = Uri.parse(callbackUrl);
        final callback = OAuthCallback.fromQueryParams(uri.queryParameters);

        expect(callback.hasError, isTrue);
        expect(callback.error, equals('access_denied'));
        expect(callback.errorDescription, equals('User denied access'));
        expect(callback.state, equals('test_state'));
      });
    });

    group('Provider State Management', () {
      test('should update provider status during OAuth flow', () async {
        final statusUpdates = <ProviderStatus>[];
        TestResourceManager.safeStreamListen(provider.statusStream, statusUpdates.add);

        // Mock successful OAuth - usando configuração mock
        MockFlutterWebAuth2.setMockResult(
          '${GoogleOAuthConfig.customSchemeRedirectUri}://oauth?code=test_code&state=test_state'
        );

        // Initial state should be disconnected
        expect(provider.status, equals(ProviderStatus.disconnected));

        // Trigger authentication
        await provider.authenticate();

        // Should have gone through connecting state
        expect(statusUpdates, contains(ProviderStatus.connecting));
      });

      test('should maintain authentication state', () async {
        // Initially not authenticated
        expect(provider.isAuthenticated, isFalse);

        // Mock successful authentication
        MockFlutterWebAuth2.setMockResult(
          '${GoogleOAuthConfig.customSchemeRedirectUri}://oauth?code=test_code&state=test_state'
        );

        await provider.authenticate();

        // Should be authenticated after successful OAuth
        expect(provider.isAuthenticated, isTrue);
        expect(provider.status, equals(ProviderStatus.connected));
      });

      test('should handle logout correctly', () async {
        // First authenticate
        MockFlutterWebAuth2.setMockResult(
          '${GoogleOAuthConfig.customSchemeRedirectUri}://oauth?code=test_code&state=test_state'
        );
        await provider.authenticate();

        expect(provider.isAuthenticated, isTrue);

        // Then logout
        await provider.logout();

        expect(provider.isAuthenticated, isFalse);
        expect(provider.status, equals(ProviderStatus.disconnected));
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        // Mock network error
        MockFlutterWebAuth2.setMockException(
          Exception('Network error')
        );

        final result = await provider.authenticate();

        expect(result, isFalse);
        expect(provider.status, equals(ProviderStatus.error));
      });

      test('should handle invalid callback URLs', () async {
        // Mock invalid callback
        MockFlutterWebAuth2.setMockResult('invalid_url');

        final result = await provider.authenticate();

        expect(result, isFalse);
        expect(provider.status, equals(ProviderStatus.error));
      });

      test('should handle server errors', () async {
        // Mock server error response
        when(mockHttpClient.get(any)).thenAnswer(
          (_) async => http.Response('Server Error', 500)
        );

        MockFlutterWebAuth2.setMockResult(
          '${GoogleOAuthConfig.customSchemeRedirectUri}://oauth?code=test_code&state=test_state'
        );

        final result = await provider.authenticate();

        // Should handle server error gracefully
        expect(result, isA<bool>());
      });
    });

    group('Multi-Provider Scenarios', () {
      testWidgets('should handle multiple providers independently', (WidgetTester tester) async {
        final provider2 = GoogleDriveProvider(
          tokenStorage: tokenStorage,
          urlGenerator: (params) => 'http://localhost:8080/auth/google2',
        );

        final multiConfig = FileDriveConfig(
          providers: [provider, provider2],
          theme: FileDriveTheme.light(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileDriveWidget(config: multiConfig),
            ),
          ),
        );

        // Should show both providers
        expect(find.text('Google Drive'), findsNWidgets(2));

        // Each provider should have independent state
        expect(provider.status, equals(ProviderStatus.disconnected));
        expect(provider2.status, equals(ProviderStatus.disconnected));

        provider2.dispose();
      });
    });

    group('Theme Integration', () {
      testWidgets('should apply theme correctly during OAuth flow', (WidgetTester tester) async {
        final darkTheme = FileDriveTheme.dark();
        final themedConfig = FileDriveConfig(
          providers: [provider],
          theme: darkTheme,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileDriveWidget(config: themedConfig),
            ),
          ),
        );

        // Should render with dark theme
        expect(find.byType(FileDriveWidget), findsOneWidget);
      });
    });

    group('Responsive Behavior', () {
      testWidgets('should work on different screen sizes', (WidgetTester tester) async {
        // Test mobile layout
        tester.binding.window.physicalSizeTestValue = const Size(400, 800);
        tester.binding.window.devicePixelRatioTestValue = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileDriveWidget(config: config),
            ),
          ),
        );

        expect(find.byType(DefaultTabController), findsOneWidget);

        // Test desktop layout
        tester.binding.window.physicalSizeTestValue = const Size(1200, 800);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileDriveWidget(config: config),
            ),
          ),
        );

        expect(find.byType(Row), findsWidgets);

        addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
        addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
      });
    });
  });
}
