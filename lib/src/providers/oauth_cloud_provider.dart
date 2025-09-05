import 'dart:async';

import '../enums/oauth_scope.dart';
import '../models/cloud_account.dart';
import '../models/oauth_provider_configuration.dart';
import 'base_cloud_provider.dart';

abstract class OAuthCloudProvider extends BaseCloudProvider {
  final OAuthProviderConfiguration oauthConfiguration;
  
  CloudAccount? _authenticatedAccount;
  StreamController<AuthenticationState>? _authStateController;
  Timer? _tokenRefreshTimer;

  OAuthCloudProvider({
    required this.oauthConfiguration,
    CloudAccount? account,
  }) : super(
         configuration: oauthConfiguration,
         account: account,
       ) {
    _authenticatedAccount = account;
    _authStateController = StreamController<AuthenticationState>.broadcast();
  }

  @override
  OAuthProviderConfiguration get configuration => oauthConfiguration;

  @override
  Set<OAuthScope> get requiredScopes => oauthConfiguration.scopes
      .map((scope) => OAuthScope.values.firstWhere(
            (enumValue) => enumValue.name == scope,
            orElse: () => OAuthScope.readFiles,
          ))
      .toSet();

  @override
  bool get requiresAccountManagement => oauthConfiguration.requiresAccountManagement;

  Stream<AuthenticationState> get authenticationStateStream => 
      _authStateController?.stream ?? const Stream.empty();

  AuthenticationState get currentAuthenticationState {
    if (_authenticatedAccount == null) return AuthenticationState.notAuthenticated;
    if (_authenticatedAccount!.isExpired) return AuthenticationState.tokenExpired;
    if (_authenticatedAccount!.needsReauth) return AuthenticationState.needsRefresh;
    return AuthenticationState.authenticated;
  }

  Uri generateAuthorizationUrl(String state) {
    validateOAuthConfiguration();
    return oauthConfiguration.authUrlGenerator(state);
  }

  Uri generateTokenUrl(String state) {
    validateOAuthConfiguration();
    return oauthConfiguration.tokenUrlGenerator(state);
  }
  
  Future<CloudAccount> exchangeAuthorizationCode({
    required String authorizationCode,
    required String state,
  }) async {
    ensureNotDisposed();
    validateOAuthConfiguration();
    
    try {
      final tokenUrl = oauthConfiguration.tokenUrlGenerator(state);
      final response = await _performTokenExchange(tokenUrl, authorizationCode, state);
      
      final account = _parseTokenResponse(response);
      _authenticatedAccount = account;
      _authStateController?.add(AuthenticationState.authenticated);
      _scheduleTokenRefresh(account);
      
      return account;
    } catch (error) {
      _authStateController?.add(AuthenticationState.authenticationFailed);
      handleOAuthError(error);
      rethrow;
    }
  }
  
  Future<void> initiateOAuthFlow() async {
    ensureNotDisposed();
    validateOAuthConfiguration();
    
    _authStateController?.add(AuthenticationState.authenticating);
    
    try {
      final state = _generateOAuthState();
      final authUrl = await generateAuthorizationUrl(state);
      
      await _launchAuthorizationUrl(authUrl);
    } catch (error) {
      _authStateController?.add(AuthenticationState.authenticationFailed);
      handleOAuthError(error);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _performTokenExchange(
    Uri tokenUrl, 
    String authorizationCode, 
    String state,
  );
  
  CloudAccount _parseTokenResponse(Map<String, dynamic> response);
  
  String _generateOAuthState();
  
  Future<void> _launchAuthorizationUrl(Uri authUrl);
  
  
  bool checkAuthentication() {
    if (_authenticatedAccount == null) return false;
    if (_authenticatedAccount!.isExpired) return false;
    if (_authenticatedAccount!.accessToken.isEmpty) return false;
    return true;
  }
  
  void validateAuthentication() {
    ensureNotDisposed();
    
    if (!requiresAccountManagement) return;
    
    if (_authenticatedAccount == null) {
      throw CloudProviderException(
        'OAuth provider requires authentication but no account is set. '
        'Please complete the OAuth flow first.',
        code: 'NO_ACCOUNT',
      );
    }
    
    if (_authenticatedAccount!.accessToken.isEmpty) {
      throw CloudProviderException(
        'OAuth provider requires valid access token',
        code: 'INVALID_TOKEN',
      );
    }
    
    if (_authenticatedAccount!.isExpired) {
      throw CloudProviderException(
        'Access token has expired. Token refresh required.',
        code: 'TOKEN_EXPIRED',
      );
    }
    
    _validateTokenScopes();
    _validateProviderSpecificAuth();
  }
  
  bool isTokenExpired() {
    if (_authenticatedAccount?.expiresAt == null) return false;
    return DateTime.now().isAfter(_authenticatedAccount!.expiresAt!);
  }
  
  bool shouldRefreshToken() {
    if (_authenticatedAccount == null) return false;
    if (isTokenExpired()) return true;
    
    final expiresAt = _authenticatedAccount!.expiresAt;
    if (expiresAt == null) return false;
    
    final fiveMinutesFromNow = DateTime.now().add(const Duration(minutes: 5));
    return fiveMinutesFromNow.isAfter(expiresAt);
  }
  
  void ensureValidAuthentication() {
    validateAuthentication();
    
    if (shouldRefreshToken() && _authenticatedAccount!.refreshToken != null) {
      throw CloudProviderException(
        'Token refresh required before proceeding with operation',
        code: 'REFRESH_REQUIRED',
      );
    }
  }
  
  void _validateTokenScopes() {
    final requiredScopeNames = requiredScopes.map((scope) => scope.name).toSet();
    final availableScopes = oauthConfiguration.scopes.toSet();
    
    if (!availableScopes.containsAll(requiredScopeNames)) {
      final missingScopes = requiredScopeNames.difference(availableScopes);
      throw CloudProviderException(
        'Missing required OAuth scopes: ${missingScopes.join(', ')}',
        code: 'INSUFFICIENT_SCOPES',
      );
    }
  }
  
  void _validateProviderSpecificAuth() {
    // Override in concrete implementations for provider-specific validation
  }
  
  Future<CloudAccount> refreshTokens(CloudAccount account) async {
    ensureNotDisposed();
    validateOAuthConfiguration();
    
    if (account.refreshToken == null || account.refreshToken!.isEmpty) {
      throw CloudProviderException(
        'Cannot refresh tokens: No refresh token available',
        code: 'NO_REFRESH_TOKEN',
      );
    }
    
    try {
      _authStateController?.add(AuthenticationState.authenticating);
      
      final refreshedAccount = await _performTokenRefresh(account);
      
      _authenticatedAccount = refreshedAccount;
      _authStateController?.add(AuthenticationState.authenticated);
      _scheduleTokenRefresh(refreshedAccount);
      
      return refreshedAccount;
    } catch (error) {
      _authStateController?.add(AuthenticationState.authenticationFailed);
      handleOAuthError(error);
      rethrow;
    }
  }

  void _scheduleTokenRefresh(CloudAccount account) {
    _tokenRefreshTimer?.cancel();
    
    if (account.expiresAt == null) return;
    
    final refreshTime = account.expiresAt!.subtract(const Duration(minutes: 5));
    final now = DateTime.now();
    
    if (refreshTime.isBefore(now)) return;
    
    final delay = refreshTime.difference(now);
    
    _tokenRefreshTimer = Timer(delay, () async {
      if (isDisposed || _authenticatedAccount == null) return;
      
      try {
        await _performAutomaticTokenRefresh();
      } catch (error) {
        _authStateController?.add(AuthenticationState.needsRefresh);
        handleOAuthError(error);
      }
    });
  }
  
  Future<void> _performAutomaticTokenRefresh() async {
    if (_authenticatedAccount?.refreshToken == null) {
      _authStateController?.add(AuthenticationState.needsRefresh);
      return;
    }
    
    try {
      final refreshedAccount = await refreshTokens(_authenticatedAccount!);
      _authenticatedAccount = refreshedAccount;
    } catch (error) {
      _authStateController?.add(AuthenticationState.needsRefresh);
      rethrow;
    }
  }
  
  @override
  void setCurrentAccount(CloudAccount? account) {
    super.setCurrentAccount(account);
    _authenticatedAccount = account;
    
    if (account != null) {
      if (account.expiresAt != null) {
        _scheduleTokenRefresh(account);
      }
      _authStateController?.add(AuthenticationState.authenticated);
    } else {
      _tokenRefreshTimer?.cancel();
      _authStateController?.add(AuthenticationState.notAuthenticated);
    }
  }
  
  void updateStoredAccount(CloudAccount account) {
    _authenticatedAccount = account;
    if (account.expiresAt != null) {
      _scheduleTokenRefresh(account);
    }
    _authStateController?.add(AuthenticationState.authenticated);
  }
  
  void clearStoredTokens() {
    _tokenRefreshTimer?.cancel();
    _authenticatedAccount = null;
    _authStateController?.add(AuthenticationState.notAuthenticated);
  }
  
  Future<CloudAccount> _performTokenRefresh(CloudAccount account);
  
  Duration? getTokenTimeToExpiry() {
    if (_authenticatedAccount?.expiresAt == null) return null;
    final expiry = _authenticatedAccount!.expiresAt!;
    final now = DateTime.now();
    if (expiry.isBefore(now)) return Duration.zero;
    return expiry.difference(now);
  }
  
  bool hasValidRefreshToken() {
    return _authenticatedAccount?.refreshToken != null && 
           _authenticatedAccount!.refreshToken!.isNotEmpty;
  }
  
  Future<T> makeAuthenticatedRequest<T>(
    Future<T> Function() request, {
    bool autoRetry = true,
  }) async {
    ensureNotDisposed();
    ensureValidAuthentication();
    
    try {
      if (shouldRefreshToken() && hasValidRefreshToken() && autoRetry) {
        await refreshTokens(_authenticatedAccount!);
      }
      
      return await request();
    } catch (error) {
      if (!autoRetry) rethrow;
      
      if (_isAuthenticationError(error) && hasValidRefreshToken()) {
        try {
          await refreshTokens(_authenticatedAccount!);
          return await request();
        } catch (refreshError) {
          handleOAuthError(refreshError);
          rethrow;
        }
      }
      
      handleOAuthError(error);
      rethrow;
    }
  }
  
  Future<Map<String, String>> getAuthenticatedHeaders() async {
    ensureValidAuthentication();
    
    if (shouldRefreshToken() && hasValidRefreshToken()) {
      await refreshTokens(_authenticatedAccount!);
    }
    
    return {
      'Authorization': 'Bearer ${_authenticatedAccount!.accessToken}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...await _getProviderSpecificHeaders(),
    };
  }
  
  Future<T> makeAuthenticatedGetRequest<T>(
    Uri url, {
    Map<String, String>? additionalHeaders,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return makeAuthenticatedRequest<T>(() async {
      final headers = {
        ...await getAuthenticatedHeaders(),
        ...?additionalHeaders,
      };
      
      final response = await _performHttpRequest('GET', url, headers: headers);
      
      if (parser != null) {
        return parser(response);
      }
      return response as T;
    });
  }
  
  Future<T> makeAuthenticatedPostRequest<T>(
    Uri url, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return makeAuthenticatedRequest<T>(() async {
      final headers = {
        ...await getAuthenticatedHeaders(),
        ...?additionalHeaders,
      };
      
      final response = await _performHttpRequest(
        'POST', 
        url, 
        headers: headers,
        body: body,
      );
      
      if (parser != null) {
        return parser(response);
      }
      return response as T;
    });
  }
  
  Future<T> makeAuthenticatedPutRequest<T>(
    Uri url, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return makeAuthenticatedRequest<T>(() async {
      final headers = {
        ...await getAuthenticatedHeaders(),
        ...?additionalHeaders,
      };
      
      final response = await _performHttpRequest(
        'PUT', 
        url, 
        headers: headers,
        body: body,
      );
      
      if (parser != null) {
        return parser(response);
      }
      return response as T;
    });
  }
  
  Future<T> makeAuthenticatedDeleteRequest<T>(
    Uri url, {
    Map<String, String>? additionalHeaders,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return makeAuthenticatedRequest<T>(() async {
      final headers = {
        ...await getAuthenticatedHeaders(),
        ...?additionalHeaders,
      };
      
      final response = await _performHttpRequest('DELETE', url, headers: headers);
      
      if (parser != null) {
        return parser(response);
      }
      return response as T;
    });
  }
  
  Future<Stream<List<int>>> makeAuthenticatedStreamRequest(
    Uri url, {
    Map<String, String>? additionalHeaders,
  }) async {
    ensureValidAuthentication();
    
    if (shouldRefreshToken() && hasValidRefreshToken()) {
      await refreshTokens(_authenticatedAccount!);
    }
    
    final headers = {
      ...await getAuthenticatedHeaders(),
      ...?additionalHeaders,
    };
    
    return _performStreamRequest(url, headers);
  }
  
  bool _isAuthenticationError(dynamic error);
  
  Future<Map<String, String>> _getProviderSpecificHeaders();
  
  Future<Map<String, dynamic>> _performHttpRequest(
    String method, 
    Uri url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  });
  
  Future<Stream<List<int>>> _performStreamRequest(
    Uri url,
    Map<String, String> headers,
  );
  
  void handleOAuthError(dynamic error) {
    if (error is CloudProviderException) {
      throw error;
    }
    
    String message = 'OAuth operation failed';
    String? code;
    int? statusCode;
    
    if (error is Map<String, dynamic>) {
      message = error['error_description'] ?? 
                error['message'] ?? 
                error['error'] ?? 
                message;
      code = error['error'];
      statusCode = error['status_code'];
    } else if (error.toString().contains('401')) {
      message = 'Authentication failed - invalid or expired credentials';
      code = 'AUTHENTICATION_FAILED';
      statusCode = 401;
    } else if (error.toString().contains('403')) {
      message = 'Access denied - insufficient permissions';
      code = 'ACCESS_DENIED';
      statusCode = 403;
    } else if (error.toString().contains('400')) {
      message = 'Invalid OAuth request parameters';
      code = 'INVALID_REQUEST';
      statusCode = 400;
    } else if (error.toString().toLowerCase().contains('network') ||
               error.toString().toLowerCase().contains('connection')) {
      message = 'Network error during OAuth operation';
      code = 'NETWORK_ERROR';
    } else if (error.toString().toLowerCase().contains('timeout')) {
      message = 'OAuth operation timed out';
      code = 'TIMEOUT';
    }
    
    throw CloudProviderException(
      message,
      code: code,
      statusCode: statusCode,
      originalException: error,
    );
  }
  
  void validateOAuthConfiguration() {
    if (oauthConfiguration.redirectScheme.isEmpty) {
      throw CloudProviderException(
        'OAuth configuration invalid: redirect scheme is required',
        code: 'INVALID_CONFIG',
      );
    }
    
    if (oauthConfiguration.scopes.isEmpty) {
      throw CloudProviderException(
        'OAuth configuration invalid: at least one scope is required',
        code: 'INVALID_CONFIG',
      );
    }
    
    try {
      const testState = 'config_validation_test';
      final authUrl = oauthConfiguration.authUrlGenerator(testState);
      final tokenUrl = oauthConfiguration.tokenUrlGenerator(testState);
      
      if (!authUrl.hasScheme || authUrl.host.isEmpty) {
        throw CloudProviderException(
          'OAuth configuration invalid: authUrlGenerator returns invalid URL',
          code: 'INVALID_CONFIG',
        );
      }
      
      if (!tokenUrl.hasScheme || tokenUrl.host.isEmpty) {
        throw CloudProviderException(
          'OAuth configuration invalid: tokenUrlGenerator returns invalid URL',
          code: 'INVALID_CONFIG',
        );
      }
    } catch (error) {
      if (error is CloudProviderException) rethrow;
      
      throw CloudProviderException(
        'OAuth configuration invalid: URL generator functions failed',
        code: 'INVALID_CONFIG',
        originalException: error,
      );
    }
    
    _validateProviderSpecificConfig();
  }
  
  void _validateProviderSpecificConfig() {
    // Override in concrete implementations for provider-specific validation
  }
  
  CloudProviderException createOAuthException({
    required String message,
    String? code,
    int? statusCode,
    dynamic originalException,
  }) {
    return CloudProviderException(
      message,
      code: code,
      statusCode: statusCode,
      originalException: originalException,
    );
  }
  
  bool isRetryableOAuthError(dynamic error) {
    if (error is CloudProviderException) {
      return error.code == 'NETWORK_ERROR' || 
             error.code == 'TIMEOUT' ||
             error.statusCode == 429 || // Rate limit
             (error.statusCode != null && error.statusCode! >= 500);
    }
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') || 
           errorString.contains('timeout') ||
           errorString.contains('connection');
  }
  
  void logOAuthError(dynamic error, String operation) {
    // Override in concrete implementations for proper logging
    print('OAuth error in $operation: $error');
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _authStateController?.close();
    super.dispose();
  }
}

enum AuthenticationState {
  notAuthenticated,
  authenticating,
  authenticated,
  tokenExpired,
  needsRefresh,
  authenticationFailed,
}