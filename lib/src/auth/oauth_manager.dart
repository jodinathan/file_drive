import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'oauth_config.dart';

/// Manages OAuth2 authentication flow
class OAuthManager {
  static const String _chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final Random _random = Random.secure();
  
  /// Generates a random state parameter for OAuth flow
  String _generateState() {
    return String.fromCharCodes(
      Iterable.generate(32, (_) => _chars.codeUnitAt(_random.nextInt(_chars.length))),
    );
  }
  
  /// Starts the OAuth authentication flow
  /// 
  /// [config] - OAuth configuration for the provider
  /// Returns the result of the authentication
  Future<OAuthResult> authenticate(OAuthConfig config) async {
    try {
      // Generate unique state parameter
      final state = _generateState();
      
      // Get the auth URL from the server
      final authUrl = config.generateAuthUrl(state);
      
      // Start the OAuth flow using flutter_web_auth_2
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: config.redirectScheme,
      );
      
      // Parse the result URL
      final resultUri = Uri.parse(result);
      final queryParams = resultUri.queryParameters;
      
      // Check for errors in the callback
      if (queryParams.containsKey('error')) {
        final error = queryParams['error'] ?? 'Unknown error';
        final errorDescription = queryParams['error_description'] ?? error;
        return OAuthResult.error(errorDescription);
      }
      
      // Check for token in hid parameter (based on working example)
      if (queryParams.containsKey('hid')) {
        final accessToken = queryParams['hid'];
        if (accessToken != null && accessToken.isNotEmpty) {
          return OAuthResult.success(
            accessToken: accessToken,
            additionalData: queryParams,
          );
        }
      }
      
      // Fallback: try to get tokens from server using state
      final tokenResult = await _retrieveTokens(config, state);
      return tokenResult;
      
    } on PlatformException catch (e) {
      // Check if user cancelled the authentication
      if (e.code == 'CANCELLED' || e.code == 'UserCancel') {
        return OAuthResult.cancelled();
      }
      // Other platform exceptions
      return OAuthResult.error('Authentication failed: ${e.message ?? e.toString()}');
    } catch (e) {
      // Other errors
      return OAuthResult.error('Authentication failed: ${e.toString()}');
    }
  }
  
  /// Retrieves tokens from the OAuth server using the state parameter
  Future<OAuthResult> _retrieveTokens(OAuthConfig config, String state) async {
    try {
      // Get the token URL
      final tokenUrl = config.generateTokenUrl(state);
      
      // Make request to get tokens
      final response = await http.get(
        Uri.parse(tokenUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      
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
        return OAuthResult.error(description);
      }
      
      // Extract tokens
      final accessToken = data['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        return OAuthResult.error('No access token received');
      }
      
      final refreshToken = data['refresh_token'] as String?;
      
      // Parse expiration
      DateTime? expiresAt;
      final expiresIn = data['expires_in'];
      if (expiresIn != null) {
        final seconds = expiresIn is int ? expiresIn : int.tryParse(expiresIn.toString());
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
        return OAuthResult.error(
          'Token refresh failed: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
      
      final Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return OAuthResult.error('Invalid response format from refresh endpoint');
      }
      
      if (data.containsKey('error')) {
        final error = data['error'] as String? ?? 'Unknown error';
        return OAuthResult.error(error);
      }
      
      final accessToken = data['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        return OAuthResult.error('No access token received from refresh');
      }
      
      final newRefreshToken = data['refresh_token'] as String? ?? refreshToken;
      
      DateTime? expiresAt;
      final expiresIn = data['expires_in'];
      if (expiresIn != null) {
        final seconds = expiresIn is int ? expiresIn : int.tryParse(expiresIn.toString());
        if (seconds != null) {
          expiresAt = DateTime.now().add(Duration(seconds: seconds));
        }
      }
      
      return OAuthResult.success(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        expiresAt: expiresAt,
      );
      
    } catch (e) {
      return OAuthResult.error('Token refresh failed: ${e.toString()}');
    }
  }
}