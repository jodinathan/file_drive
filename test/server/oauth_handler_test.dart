import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_test/shelf_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Import the server files
import '../../example_server/lib/oauth_handler.dart';
import '../../example_server/lib/state_storage.dart';
import '../../example_server/lib/token_storage.dart';

// Generate mocks
@GenerateMocks([http.Client])
import 'oauth_handler_test.mocks.dart';

void main() {
  group('OAuthHandler', () {
    late OAuthHandler handler;
    late MockClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockClient();
      handler = OAuthHandler();
      
      // Clear storage before each test
      StateStorage.clear();
      TokenStorage.clear();
    });

    group('Google Auth Endpoint', () {
      test('should redirect to Google OAuth URL', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost:8080/auth/google'),
          headers: {'host': 'localhost:8080'},
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(302)); // Redirect
        expect(response.headers['location'], isNotNull);
        expect(response.headers['location']!, contains('accounts.google.com'));
        expect(response.headers['location']!, contains('oauth2/v2/auth'));
      });

      test('should include correct OAuth parameters in redirect', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost:8080/auth/google?client_id=test_client&redirect_uri=test_redirect'),
          headers: {'host': 'localhost:8080'},
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(302));
        final location = response.headers['location']!;
        final uri = Uri.parse(location);
        
        expect(uri.queryParameters['client_id'], equals('test_client'));
        expect(uri.queryParameters['redirect_uri'], equals('test_redirect'));
        expect(uri.queryParameters['response_type'], equals('code'));
        expect(uri.queryParameters['scope'], isNotNull);
        expect(uri.queryParameters['state'], isNotNull);
      });

      test('should store state for later validation', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost:8080/auth/google?client_id=test_client&redirect_uri=test_redirect'),
          headers: {'host': 'localhost:8080'},
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(302));
        final location = response.headers['location']!;
        final uri = Uri.parse(location);
        final state = uri.queryParameters['state']!;
        
        // State should be stored
        final storedState = StateStorage.getState(state);
        expect(storedState, isNotNull);
        expect(storedState!.clientId, equals('test_client'));
        expect(storedState.redirectUri, equals('test_redirect'));
      });

      test('should handle missing parameters gracefully', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost:8080/auth/google'),
          headers: {'host': 'localhost:8080'},
        );

        final response = await handler.router.call(request);

        // Should still redirect but with default parameters
        expect(response.statusCode, equals(302));
      });
    });

    group('OAuth Callback Endpoint', () {
      test('should handle successful callback with valid state', () async {
        // First, create a state
        final state = 'test_state_123';
        final oauthState = OAuthState(
          clientId: 'test_client',
          redirectUri: 'com.test.app://oauth',
          scopes: ['scope1', 'scope2'],
          timestamp: DateTime.now(),
        );
        StateStorage.storeState(state, oauthState);

        final request = Request(
          'GET',
          Uri.parse('http://localhost:8080/auth/callback?code=test_code&state=$state'),
          headers: {'host': 'localhost:8080'},
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(302)); // Redirect back to app
        expect(response.headers['location'], contains('com.test.app://oauth'));
        expect(response.headers['location'], contains('code=test_code'));
        expect(response.headers['location'], contains('state=$state'));
      });

      test('should handle callback with invalid state', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost:8080/auth/callback?code=test_code&state=invalid_state'),
          headers: {'host': 'localhost:8080'},
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(302)); // Redirect with error
        expect(response.headers['location'], contains('error=invalid_state'));
      });

      test('should handle callback with OAuth error', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost:8080/auth/callback?error=access_denied&error_description=User+denied+access'),
          headers: {'host': 'localhost:8080'},
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(302)); // Redirect with error
        expect(response.headers['location'], contains('error=access_denied'));
      });

      test('should handle missing code parameter', () async {
        final state = 'test_state_123';
        final oauthState = OAuthState(
          clientId: 'test_client',
          redirectUri: 'com.test.app://oauth',
          scopes: ['scope1'],
          timestamp: DateTime.now(),
        );
        StateStorage.storeState(state, oauthState);

        final request = Request(
          'GET',
          Uri.parse('http://localhost:8080/auth/callback?state=$state'),
          headers: {'host': 'localhost:8080'},
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(302)); // Redirect with error
        expect(response.headers['location'], contains('error=invalid_request'));
      });

      test('should clean up state after successful callback', () async {
        final state = 'test_state_123';
        final oauthState = OAuthState(
          clientId: 'test_client',
          redirectUri: 'com.test.app://oauth',
          scopes: ['scope1'],
          timestamp: DateTime.now(),
        );
        StateStorage.storeState(state, oauthState);

        final request = Request(
          'GET',
          Uri.parse('http://localhost:8080/auth/callback?code=test_code&state=$state'),
          headers: {'host': 'localhost:8080'},
        );

        await handler.router.call(request);

        // State should be removed after use
        final storedState = StateStorage.getState(state);
        expect(storedState, isNull);
      });
    });

    group('Token Validation Endpoint', () {
      test('should validate stored token', () async {
        // Store a token first
        final userId = 'test_user';
        final tokenData = {
          'access_token': 'test_access_token',
          'refresh_token': 'test_refresh_token',
          'expires_in': 3600,
        };
        TokenStorage.storeToken(userId, tokenData);

        final request = Request(
          'POST',
          Uri.parse('http://localhost:8080/auth/validate'),
          headers: {
            'content-type': 'application/json',
            'host': 'localhost:8080',
          },
          body: jsonEncode({'user_id': userId}),
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(200));
        final responseBody = await response.readAsString();
        final data = jsonDecode(responseBody);
        expect(data['valid'], isTrue);
        expect(data['user_id'], equals(userId));
      });

      test('should reject invalid token', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost:8080/auth/validate'),
          headers: {
            'content-type': 'application/json',
            'host': 'localhost:8080',
          },
          body: jsonEncode({'user_id': 'nonexistent_user'}),
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(200));
        final responseBody = await response.readAsString();
        final data = jsonDecode(responseBody);
        expect(data['valid'], isFalse);
      });

      test('should handle malformed request', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost:8080/auth/validate'),
          headers: {
            'content-type': 'application/json',
            'host': 'localhost:8080',
          },
          body: 'invalid json',
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(400));
      });
    });

    group('Token Refresh Endpoint', () {
      test('should handle refresh token request', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost:8080/auth/refresh'),
          headers: {
            'content-type': 'application/json',
            'host': 'localhost:8080',
          },
          body: jsonEncode({'refresh_token': 'test_refresh_token'}),
        );

        final response = await handler.router.call(request);

        // Should return 200 even if refresh fails (for testing)
        expect(response.statusCode, equals(200));
      });
    });

    group('Token Revocation Endpoint', () {
      test('should handle token revocation', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost:8080/auth/revoke'),
          headers: {
            'content-type': 'application/json',
            'host': 'localhost:8080',
          },
          body: jsonEncode({'token': 'test_token'}),
        );

        final response = await handler.router.call(request);

        expect(response.statusCode, equals(200));
      });
    });
  });

  group('StateStorage', () {
    setUp(() {
      StateStorage.clear();
    });

    test('should store and retrieve state', () {
      final state = 'test_state';
      final oauthState = OAuthState(
        clientId: 'test_client',
        redirectUri: 'test_redirect',
        scopes: ['scope1'],
        timestamp: DateTime.now(),
      );

      StateStorage.storeState(state, oauthState);
      final retrieved = StateStorage.getState(state);

      expect(retrieved, isNotNull);
      expect(retrieved!.clientId, equals('test_client'));
      expect(retrieved.redirectUri, equals('test_redirect'));
    });

    test('should remove state', () {
      final state = 'test_state';
      final oauthState = OAuthState(
        clientId: 'test_client',
        redirectUri: 'test_redirect',
        scopes: ['scope1'],
        timestamp: DateTime.now(),
      );

      StateStorage.storeState(state, oauthState);
      StateStorage.removeState(state);
      final retrieved = StateStorage.getState(state);

      expect(retrieved, isNull);
    });

    test('should clean up expired states', () {
      final state = 'test_state';
      final expiredTime = DateTime.now().subtract(Duration(hours: 2));
      final oauthState = OAuthState(
        clientId: 'test_client',
        redirectUri: 'test_redirect',
        scopes: ['scope1'],
        timestamp: expiredTime,
      );

      StateStorage.storeState(state, oauthState);
      StateStorage.cleanupExpiredStates();
      final retrieved = StateStorage.getState(state);

      expect(retrieved, isNull);
    });
  });

  group('TokenStorage', () {
    setUp(() {
      TokenStorage.clear();
    });

    test('should store and retrieve token', () {
      final userId = 'test_user';
      final tokenData = {
        'access_token': 'test_access_token',
        'refresh_token': 'test_refresh_token',
      };

      TokenStorage.storeToken(userId, tokenData);
      final retrieved = TokenStorage.getToken(userId);

      expect(retrieved, isNotNull);
      expect(retrieved!['access_token'], equals('test_access_token'));
    });

    test('should remove token', () {
      final userId = 'test_user';
      final tokenData = {'access_token': 'test_access_token'};

      TokenStorage.storeToken(userId, tokenData);
      TokenStorage.removeToken(userId);
      final retrieved = TokenStorage.getToken(userId);

      expect(retrieved, isNull);
    });
  });
}
