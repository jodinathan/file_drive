import 'package:flutter_test/flutter_test.dart';
import 'package:file_drive/src/models/oauth_types.dart';

void main() {
  group('OAuthParams', () {
    test('should create OAuthParams with required fields', () {
      final params = OAuthParams(
        clientId: 'test_client_id',
        redirectUri: 'http://localhost:8080/callback',
        scopes: ['scope1', 'scope2'],
      );

      expect(params.clientId, equals('test_client_id'));
      expect(params.redirectUri, equals('http://localhost:8080/callback'));
      expect(params.scopes, equals(['scope1', 'scope2']));
      expect(params.state, isNull);
      expect(params.codeChallenge, isNull);
      expect(params.codeChallengeMethod, isNull);
    });

    test('should create OAuthParams with optional fields', () {
      final params = OAuthParams(
        clientId: 'test_client_id',
        redirectUri: 'http://localhost:8080/callback',
        scopes: ['scope1'],
        state: 'test_state',
        codeChallenge: 'test_challenge',
        codeChallengeMethod: 'S256',
      );

      expect(params.state, equals('test_state'));
      expect(params.codeChallenge, equals('test_challenge'));
      expect(params.codeChallengeMethod, equals('S256'));
    });

    test('should convert to query parameters correctly', () {
      final params = OAuthParams(
        clientId: 'test_client_id',
        redirectUri: 'http://localhost:8080/callback',
        scopes: ['scope1', 'scope2'],
        state: 'test_state',
      );

      final queryParams = params.toQueryParams();

      expect(queryParams['client_id'], equals('test_client_id'));
      expect(queryParams['redirect_uri'], equals('http://localhost:8080/callback'));
      expect(queryParams['scope'], equals('scope1 scope2'));
      expect(queryParams['response_type'], equals('code'));
      expect(queryParams['state'], equals('test_state'));
    });

    test('should handle empty scopes', () {
      final params = OAuthParams(
        clientId: 'test_client_id',
        redirectUri: 'http://localhost:8080/callback',
        scopes: [],
      );

      final queryParams = params.toQueryParams();
      expect(queryParams['scope'], equals(''));
    });

    test('should have correct toString representation', () {
      final params = OAuthParams(
        clientId: 'test_client_id',
        redirectUri: 'http://localhost:8080/callback',
        scopes: ['scope1', 'scope2'],
      );

      expect(params.toString(), contains('test_client_id'));
      expect(params.toString(), contains('scope1'));
      expect(params.toString(), contains('scope2'));
    });
  });

  group('OAuthCallback', () {
    test('should create successful callback', () {
      final callback = OAuthCallback(
        code: 'auth_code_123',
        state: 'test_state',
      );

      expect(callback.code, equals('auth_code_123'));
      expect(callback.state, equals('test_state'));
      expect(callback.error, isNull);
      expect(callback.errorDescription, isNull);
      expect(callback.isSuccess, isTrue);
      expect(callback.hasError, isFalse);
    });

    test('should create error callback', () {
      final callback = OAuthCallback(
        error: 'access_denied',
        errorDescription: 'User denied access',
        state: 'test_state',
      );

      expect(callback.code, isNull);
      expect(callback.error, equals('access_denied'));
      expect(callback.errorDescription, equals('User denied access'));
      expect(callback.isSuccess, isFalse);
      expect(callback.hasError, isTrue);
    });

    test('should get correct error message', () {
      final callback1 = OAuthCallback(error: 'access_denied');
      expect(callback1.errorMessage, equals('access_denied'));

      final callback2 = OAuthCallback(
        error: 'access_denied',
        errorDescription: 'User denied access',
      );
      expect(callback2.errorMessage, equals('access_denied: User denied access'));

      final callback3 = OAuthCallback(code: 'success');
      expect(callback3.errorMessage, equals(''));
    });

    test('should create from query parameters', () {
      final queryParams = {
        'code': 'auth_code_123',
        'state': 'test_state',
      };

      final callback = OAuthCallback.fromQueryParams(queryParams);

      expect(callback.code, equals('auth_code_123'));
      expect(callback.state, equals('test_state'));
      expect(callback.isSuccess, isTrue);
    });

    test('should create error from query parameters', () {
      final queryParams = {
        'error': 'access_denied',
        'error_description': 'User denied access',
        'state': 'test_state',
      };

      final callback = OAuthCallback.fromQueryParams(queryParams);

      expect(callback.error, equals('access_denied'));
      expect(callback.errorDescription, equals('User denied access'));
      expect(callback.hasError, isTrue);
    });

    test('should have correct toString representation', () {
      final successCallback = OAuthCallback(code: 'auth_code_123');
      expect(successCallback.toString(), contains('success: true'));

      final errorCallback = OAuthCallback(error: 'access_denied');
      expect(errorCallback.toString(), contains('success: false'));
      expect(errorCallback.toString(), contains('access_denied'));
    });
  });

  group('AuthResult', () {
    test('should create successful auth result', () {
      final expiresAt = DateTime.now().add(Duration(hours: 1));
      final result = AuthResult.success(
        accessToken: 'access_token_123',
        refreshToken: 'refresh_token_123',
        expiresAt: expiresAt,
        metadata: {'scope': 'read write'},
      );

      expect(result.success, isTrue);
      expect(result.accessToken, equals('access_token_123'));
      expect(result.refreshToken, equals('refresh_token_123'));
      expect(result.expiresAt, equals(expiresAt));
      expect(result.error, isNull);
      expect(result.metadata['scope'], equals('read write'));
    });

    test('should create failed auth result', () {
      final result = AuthResult.failure('Authentication failed');

      expect(result.success, isFalse);
      expect(result.accessToken, isNull);
      expect(result.refreshToken, isNull);
      expect(result.expiresAt, isNull);
      expect(result.error, equals('Authentication failed'));
    });

    test('should check if token is expired', () {
      final expiredResult = AuthResult.success(
        accessToken: 'token',
        expiresAt: DateTime.now().subtract(Duration(hours: 1)),
      );
      expect(expiredResult.isExpired, isTrue);

      final validResult = AuthResult.success(
        accessToken: 'token',
        expiresAt: DateTime.now().add(Duration(hours: 1)),
      );
      expect(validResult.isExpired, isFalse);

      final noExpiryResult = AuthResult.success(accessToken: 'token');
      expect(noExpiryResult.isExpired, isFalse);
    });

    test('should calculate time until expiry', () {
      final futureTime = DateTime.now().add(Duration(minutes: 30));
      final result = AuthResult.success(
        accessToken: 'token',
        expiresAt: futureTime,
      );

      final timeUntilExpiry = result.timeUntilExpiry;
      expect(timeUntilExpiry, isNotNull);
      expect(timeUntilExpiry!.inMinutes, closeTo(30, 1));

      final expiredResult = AuthResult.success(
        accessToken: 'token',
        expiresAt: DateTime.now().subtract(Duration(hours: 1)),
      );
      expect(expiredResult.timeUntilExpiry, equals(Duration.zero));

      final noExpiryResult = AuthResult.success(accessToken: 'token');
      expect(noExpiryResult.timeUntilExpiry, isNull);
    });

    test('should have correct toString representation', () {
      final successResult = AuthResult.success(accessToken: 'token');
      expect(successResult.toString(), contains('success: true'));
      expect(successResult.toString(), contains('hasToken: true'));

      final failureResult = AuthResult.failure('error');
      expect(failureResult.toString(), contains('success: false'));
      expect(failureResult.toString(), contains('hasToken: false'));
    });
  });
}
