import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'oauth_config.dart';
import '../utils/app_logger.dart';

/// Manages OAuth2 authentication flow
class OAuthManager {
  static const String _chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final Random _random = Random.secure();

  /// Generates a random state parameter for OAuth flow
  String _generateState() {
    return String.fromCharCodes(
      Iterable.generate(
        32,
        (_) => _chars.codeUnitAt(_random.nextInt(_chars.length)),
      ),
    );
  }

  /// Starts the OAuth authentication flow
  ///
  /// [config] - OAuth configuration for the provider
  /// Returns the result of the authentication
  Future<OAuthResult> authenticate(OAuthConfig config) async {
    print('🔥🔥🔥 OAUTH MANAGER AUTHENTICATE STARTED 🔥🔥🔥');
    try {
      // Generate unique state parameter
      final state = _generateState();

      // Get the auth URL from the server
      final authUrl = config.generateAuthUrl(state);
      
      // Debug log the auth URL
      AppLogger.info('Generated auth URL: $authUrl', component: 'OAuth');
      AppLogger.info('Callback scheme: ${config.redirectScheme}', component: 'OAuth');

      // Start the OAuth flow using flutter_web_auth_2
      // Extract the scheme part for callbackUrlScheme (remove :// and everything after)
      String callbackScheme = config.redirectScheme;
      if (callbackScheme.contains('://')) {
        callbackScheme = callbackScheme.split('://').first;
      }
      
      assert(authUrl.trim().isNotEmpty, 'Auth URL is empty');
      assert(callbackScheme.trim().isNotEmpty, 'Callback scheme is empty');
      
      AppLogger.info('🚀 Starting FlutterWebAuth2.authenticate...', component: 'OAuth');
      AppLogger.info('📍 Auth URL: $authUrl', component: 'OAuth');
      AppLogger.info('📍 Callback scheme: $callbackScheme', component: 'OAuth');

      AppLogger.info('🔄 Waiting for redirect from browser...', component: 'OAuth');
      
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: callbackScheme,
        options: const FlutterWebAuth2Options(
          timeout: 120000, // 2 minutes timeout
        ),
      );

      AppLogger.info('✅ FlutterWebAuth2.authenticate completed', component: 'OAuth');
      AppLogger.info('📤 Result URL: $result', component: 'OAuth');

      // Parse the result URL
      final resultUri = Uri.parse(result);
      final queryParams = resultUri.queryParameters;
      
      AppLogger.info('🔍 Parsed URI - Scheme: ${resultUri.scheme}, Host: ${resultUri.host}, Path: ${resultUri.path}', component: 'OAuth');
      AppLogger.info('🔍 Query parameters: $queryParams', component: 'OAuth');

      // Check for errors in the callback
      if (queryParams.containsKey('error')) {
        final error = queryParams['error'] ?? 'Unknown error';
        final errorDescription = queryParams['error_description'] ?? error;
        AppLogger.error('❌ OAuth error in callback - Error: $error, Description: $errorDescription', component: 'OAuth');
        return OAuthResult.error(errorDescription);
      }

      // Check for token in hid parameter (based on working example)
      if (queryParams.containsKey('hid')) {
        AppLogger.info('🔑 Found "hid" parameter in callback', component: 'OAuth');
        final accessToken = queryParams['hid'];
        final refreshToken =
            queryParams['refresh_token']; // 🔑 Captura refresh token

        AppLogger.info('🔑 Access token present: ${accessToken?.isNotEmpty == true}', component: 'OAuth');
        AppLogger.info('🔑 Refresh token present: ${refreshToken?.isNotEmpty == true}', component: 'OAuth');

        if (accessToken != null && accessToken.isNotEmpty) {
          AppLogger.info('✅ OAuth success with hid parameter', component: 'OAuth');
          return OAuthResult.success(
            accessToken: accessToken,
            refreshToken: refreshToken, // 🔑 Inclui refresh token
            additionalData: queryParams,
          );
        }
      } else {
        AppLogger.info('❌ No "hid" parameter found in callback', component: 'OAuth');
      }

      // Fallback: try to get tokens from server using state
      AppLogger.info('🔄 Falling back to server token retrieval with state: $state', component: 'OAuth');
      final tokenResult = await _retrieveTokens(config, state);
      return tokenResult;
    } on PlatformException catch (e) {
      // Check if user cancelled the authentication
      if (e.code == 'CANCELLED' || e.code == 'UserCancel') {
        return OAuthResult.cancelled();
      }
      // Other platform exceptions
      return OAuthResult.error(
        'Authentication failed (Platform): ${e.message ?? e.toString()}',
      );
    } catch (e) {
      // Other errors
      return OAuthResult.error(
        'Authentication failed (General): ${e.toString()}',
      );
    }
  }

  /// Retrieves tokens from the OAuth server using the state parameter
  Future<OAuthResult> _retrieveTokens(OAuthConfig config, String state) async {
    try {
      // Get the token URL
      final tokenUrl = config.generateTokenUrl(state);
      assert(tokenUrl.trim().isNotEmpty, 'Token URL is empty');
      
      AppLogger.info('🌐 Making token request to: $tokenUrl', component: 'OAuth');
      AppLogger.info('📍 Using state: $state', component: 'OAuth');

      // Make request to get tokens
      final response = await http.get(
        Uri.parse(tokenUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      
      AppLogger.info('📥 Token response status: ${response.statusCode}', component: 'OAuth');
      AppLogger.info('📥 Token response headers: ${response.headers}', component: 'OAuth');
      AppLogger.info('📥 Token response body: ${response.body}', component: 'OAuth');

      if (response.statusCode != 200) {
        return OAuthResult.error(
          'Failed to retrieve tokens: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      // Parse the response
      final Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return OAuthResult.error('Invalid response format from token endpoint');
      }

      // Check for error in response
      if (data.containsKey('error')) {
        final error = data['error'] as String? ?? 'Unknown error';
        final description = data['error_description'] as String? ?? error;
        AppLogger.error('❌ Server returned error - Error: $error, Description: $description', component: 'OAuth');
        return OAuthResult.error(description);
      }

      // Extract tokens
      final accessToken = data['access_token'] as String?;
      AppLogger.info('🔑 Access token extracted: ${accessToken?.isNotEmpty == true}', component: 'OAuth');
      
      if (accessToken == null || accessToken.isEmpty) {
        AppLogger.error('❌ No access token in server response', component: 'OAuth');
        return OAuthResult.error('No access token received');
      }

      final refreshToken = data['refresh_token'] as String?;
      AppLogger.info('🔑 Refresh token extracted: ${refreshToken?.isNotEmpty == true}', component: 'OAuth');

      // Parse expiration
      DateTime? expiresAt;
      final expiresIn = data['expires_in'];
      if (expiresIn != null) {
        final seconds = expiresIn is int
            ? expiresIn
            : int.tryParse(expiresIn.toString());
        if (seconds != null) {
          expiresAt = DateTime.now().add(Duration(seconds: seconds));
        }
      }

      // Remove token fields from additional data
      final additionalData = Map<String, dynamic>.from(data);
      additionalData.remove('access_token');
      additionalData.remove('refresh_token');
      additionalData.remove('expires_in');
      additionalData.remove('token_type');

      return OAuthResult.success(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        additionalData: additionalData,
      );
    } catch (e) {
      return OAuthResult.error('Failed to retrieve tokens: ${e.toString()}');
    }
  }

  /// Refreshes an access token using a refresh token
  ///
  /// [refreshUrl] - URL endpoint for token refresh
  /// [refreshToken] - The refresh token
  /// [clientId] - Client ID (if required by the endpoint)
  Future<OAuthResult> refreshToken({
    required String refreshUrl,
    required String refreshToken,
    String? clientId,
  }) async {
    try {
      final body = <String, String>{
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      };

      if (clientId != null) {
        body['client_id'] = clientId;
      }

      final response = await http.post(
        Uri.parse(refreshUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        AppLogger.warning(
          'Refresh failed with non-200 status code',
          component: 'OAuth',
        );
        return OAuthResult.error(
          'Token refresh failed: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        AppLogger.error(
          'Failed to parse response as JSON',
          component: 'OAuth',
          error: e,
        );
        return OAuthResult.error(
          'Invalid response format from refresh endpoint',
        );
      }

      if (data.containsKey('error')) {
        final error = data['error'] as String? ?? 'Unknown error';
        AppLogger.error('Response contains error: $error', component: 'OAuth');
        return OAuthResult.error(error);
      }

      final accessToken = data['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        AppLogger.warning('No access token in response', component: 'OAuth');
        return OAuthResult.error('No access token received from refresh');
      }

      final newRefreshToken = data['refresh_token'] as String? ?? refreshToken;

      DateTime? expiresAt;
      final expiresIn = data['expires_in'];
      if (expiresIn != null) {
        final seconds = expiresIn is int
            ? expiresIn
            : int.tryParse(expiresIn.toString());
        if (seconds != null) {
          expiresAt = DateTime.now().add(Duration(seconds: seconds));
        }
      }

      AppLogger.success(
        'Successfully parsed refresh response',
        component: 'OAuth',
      );

      return OAuthResult.success(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        expiresAt: expiresAt,
      );
    } catch (e) {
      AppLogger.error(
        'Exception during refresh token',
        component: 'OAuth',
        error: e,
      );
      return OAuthResult.error('Token refresh failed: ${e.toString()}');
    }
  }
}
