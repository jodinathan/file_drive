import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../enums/oauth_scope.dart';
import '../models/cloud_account.dart';
import '../models/local_provider_configuration.dart';
import '../utils/app_logger.dart';
import 'base_cloud_provider.dart';

/// Abstract base class for local server-based cloud storage providers
/// 
/// This class extends BaseCloudProvider to provide a foundation for providers
/// that communicate with local or custom servers without OAuth authentication.
/// It serves as a middle layer between BaseCloudProvider and concrete local
/// provider implementations, similar to how OAuthCloudProvider works for OAuth providers.
/// 
/// ## Key Features
/// 
/// - **No OAuth Authentication**: Designed for providers that use simple API keys,
///   tokens, or no authentication at all
/// - **HTTP Client Management**: Built-in HTTP client with proper resource management
/// - **Configuration-based Setup**: Uses LocalProviderConfiguration for server settings
/// - **Timeout Handling**: Configurable timeouts for all HTTP operations
/// - **Error Handling**: Standardized error handling for local server communication
/// 
/// ## Usage Pattern
/// 
/// Concrete implementations should extend this class and implement the abstract
/// methods from BaseCloudProvider:
/// 
/// ```dart
/// class MyLocalProvider extends LocalCloudProvider {
///   MyLocalProvider({
///     required LocalProviderConfiguration configuration,
///     CloudAccount? account,
///   }) : super(
///         configuration: configuration,
///         account: account,
///       );
/// 
///   @override
///   ProviderCapabilities getCapabilities() {
///     // Implementation specific capabilities
///   }
/// 
///   @override
///   Future<FileListPage> listFolder({...}) async {
///     // Use makeRequest() helper for HTTP calls
///   }
/// }
/// ```
/// 
/// ## Resource Management
/// 
/// This class follows the same resource management guidelines as BaseCloudProvider:
/// - HTTP client is created lazily and disposed properly
/// - All network operations respect configured timeouts
/// - Resources are cleaned up in dispose() method
/// 
/// ## Error Handling
/// 
/// Provides standardized error handling for common local server scenarios:
/// - Network connectivity issues
/// - Server timeouts and unavailability  
/// - Invalid server responses
/// - Authentication failures (when using API keys/tokens)
abstract class LocalCloudProvider extends BaseCloudProvider {
  /// Local provider configuration with server settings
  final LocalProviderConfiguration localConfiguration;

  /// HTTP client for making requests to the local server
  http.Client? _httpClient;

  /// Whether this provider has been disposed
  bool _disposed = false;

  /// Creates a local cloud provider with the given configuration
  /// 
  /// [localConfiguration] - Local provider configuration with server URL and settings
  /// [account] - Optional account for providers that require authentication
  LocalCloudProvider({
    required this.localConfiguration,
    super.account,
  }) : super(configuration: localConfiguration);

  /// Gets the local provider configuration
  @override
  LocalProviderConfiguration get configuration => localConfiguration;

  /// Server base URI for API requests
  Uri get baseUri => localConfiguration.baseUri;

  /// Request timeout duration
  Duration get timeout => localConfiguration.timeout;

  /// Additional configuration parameters
  Map<String, dynamic> get additionalConfig => localConfiguration.additionalConfig;

  /// Custom headers to include with all requests
  Map<String, String>? get headers => localConfiguration.headers;

  @override
  Set<OAuthScope> get requiredScopes => {}; // Local providers don't use OAuth scopes

  @override
  bool get requiresAccountManagement => false; // Can be overridden by concrete implementations

  /// Gets the HTTP client, creating it if necessary
  http.Client get httpClient {
    ensureNotDisposed();
    return _httpClient ??= http.Client();
  }

  /// Makes an HTTP request to the local server
  /// 
  /// This is a helper method that concrete implementations can use to make
  /// HTTP requests with proper error handling, timeouts, and authentication.
  /// 
  /// [method] - HTTP method (GET, POST, PUT, DELETE, etc.)
  /// [path] - API endpoint path (e.g., '/api/files')
  /// [body] - Request body for POST/PUT requests
  /// [additionalHeaders] - Additional headers for this specific request
  /// 
  /// Returns the HTTP response from the server.
  /// 
  /// Throws [CloudProviderException] if the request fails or times out.
  Future<http.Response> makeRequest(
    String method,
    String path, {
    String? body,
    Map<String, String>? additionalHeaders,
  }) async {
    ensureNotDisposed();
    
    final uri = localConfiguration.buildUri(path);
    final requestHeaders = localConfiguration.getRequestHeaders(
      additionalHeaders: additionalHeaders,
    );

    try {
      final request = http.Request(method.toUpperCase(), uri);
      request.headers.addAll(requestHeaders);
      
      if (body != null) {
        request.body = body;
      }

      final streamedResponse = await httpClient
          .send(request)
          .timeout(timeout);
          
      return await http.Response.fromStream(streamedResponse);
    } on TimeoutException {
      throw CloudProviderException(
        'Request timed out after ${timeout.inSeconds} seconds',
        code: 'TIMEOUT',
      );
    } on http.ClientException catch (e) {
      throw CloudProviderException(
        'Network error: ${e.message}',
        code: 'NETWORK_ERROR',
        originalException: e,
      );
    } catch (e) {
      throw CloudProviderException(
        'Request failed: $e',
        code: 'REQUEST_FAILED',
        originalException: e,
      );
    }
  }

  /// Makes an HTTP GET request to the local server
  /// 
  /// Convenience method for GET requests with standardized error handling.
  Future<http.Response> makeGetRequest(
    String path, {
    Map<String, String>? additionalHeaders,
  }) {
    return makeRequest('GET', path, additionalHeaders: additionalHeaders);
  }

  /// Makes an HTTP POST request to the local server
  /// 
  /// Convenience method for POST requests with JSON body support.
  Future<http.Response> makePostRequest(
    String path, {
    Object? body,
    Map<String, String>? additionalHeaders,
  }) {
    final bodyString = body != null ? json.encode(body) : null;
    return makeRequest('POST', path, 
        body: bodyString, additionalHeaders: additionalHeaders);
  }

  /// Makes an HTTP PUT request to the local server
  /// 
  /// Convenience method for PUT requests with JSON body support.
  Future<http.Response> makePutRequest(
    String path, {
    Object? body,
    Map<String, String>? additionalHeaders,
  }) {
    final bodyString = body != null ? json.encode(body) : null;
    return makeRequest('PUT', path, 
        body: bodyString, additionalHeaders: additionalHeaders);
  }

  /// Makes an HTTP DELETE request to the local server
  /// 
  /// Convenience method for DELETE requests.
  Future<http.Response> makeDeleteRequest(
    String path, {
    Map<String, String>? additionalHeaders,
  }) {
    return makeRequest('DELETE', path, additionalHeaders: additionalHeaders);
  }

  /// Makes a streaming HTTP request to download data
  /// 
  /// Returns a stream of bytes for file downloads or large data transfers.
  /// The stream should be consumed to avoid memory leaks.
  /// 
  /// [path] - API endpoint path for the download
  /// [additionalHeaders] - Additional headers for the request
  /// 
  /// Returns a stream of byte chunks.
  /// 
  /// Throws [CloudProviderException] if the request fails.
  Future<Stream<List<int>>> makeStreamRequest(
    String path, {
    Map<String, String>? additionalHeaders,
  }) async {
    ensureNotDisposed();
    
    final uri = localConfiguration.buildUri(path);
    final requestHeaders = localConfiguration.getRequestHeaders(
      additionalHeaders: additionalHeaders,
    );

    try {
      final request = http.Request('GET', uri);
      request.headers.addAll(requestHeaders);

      final streamedResponse = await httpClient
          .send(request)
          .timeout(timeout);

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        return streamedResponse.stream;
      } else {
        // Consume the stream to get error details
        final responseBody = await streamedResponse.stream.bytesToString();
        throw CloudProviderException(
          'Stream request failed: ${streamedResponse.statusCode} - $responseBody',
          statusCode: streamedResponse.statusCode,
        );
      }
    } on TimeoutException {
      throw CloudProviderException(
        'Stream request timed out after ${timeout.inSeconds} seconds',
        code: 'TIMEOUT',
      );
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      throw CloudProviderException(
        'Stream request failed: $e',
        code: 'REQUEST_FAILED',
        originalException: e,
      );
    }
  }

  /// Validates that an HTTP response was successful
  /// 
  /// Checks the status code and throws appropriate exceptions for error responses.
  /// This is a helper method that concrete implementations can use for consistent
  /// error handling.
  /// 
  /// [response] - The HTTP response to validate
  /// [operationName] - Name of the operation for error messages
  /// 
  /// Throws [CloudProviderException] if the response indicates an error.
  void validateResponse(http.Response response, String operationName) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return; // Success
    }

    String errorMessage = '$operationName failed: ${response.statusCode}';
    
    // Try to extract error details from response body
    try {
      final errorData = json.decode(response.body);
      if (errorData is Map<String, dynamic>) {
        final serverMessage = errorData['error'] ?? 
                            errorData['message'] ?? 
                            errorData['detail'];
        if (serverMessage != null) {
          errorMessage = '$operationName failed: $serverMessage';
        }
      }
    } catch (_) {
      // Failed to parse error response, use default message
      if (response.body.isNotEmpty) {
        errorMessage = '$operationName failed: ${response.statusCode} - ${response.body}';
      }
    }

    throw CloudProviderException(
      errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Parses a JSON response body
  /// 
  /// Helper method to safely parse JSON responses with error handling.
  /// 
  /// [response] - The HTTP response containing JSON data
  /// [operationName] - Name of the operation for error messages
  /// 
  /// Returns the parsed JSON data as a Map.
  /// 
  /// Throws [CloudProviderException] if parsing fails.
  Map<String, dynamic> parseJsonResponse(http.Response response, String operationName) {
    try {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      } else {
        throw CloudProviderException(
          '$operationName returned invalid JSON format',
          code: 'INVALID_RESPONSE',
        );
      }
    } catch (e) {
      if (e is CloudProviderException) rethrow;
      throw CloudProviderException(
        '$operationName response parsing failed: $e',
        code: 'PARSE_ERROR',
        originalException: e,
      );
    }
  }

  @override
  void ensureNotDisposed() {
    if (_disposed) {
      throw CloudProviderException(
        'LocalCloudProvider has been disposed and cannot be used',
        code: 'DISPOSED',
      );
    }
  }

  @override
  void dispose() {
    if (_disposed) return;

    try {
      // Close HTTP client if it was created
      _httpClient?.close();
      _httpClient = null;
    } catch (e) {
      // Log error but don't throw from dispose
      AppLogger.error('Error closing HTTP client during LocalCloudProvider disposal', component: 'LocalCloudProvider', error: e);
    } finally {
      _disposed = true;
      super.dispose();
    }
  }

  /// Default implementation for getUserProfile
  /// 
  /// Local providers typically don't have user profiles, so this returns
  /// a default profile. Concrete implementations can override this method
  /// if their server supports user profile information.
  @override
  Future<UserProfile> getUserProfile() async {
    return UserProfile(
      id: 'local_user',
      name: 'Local Server User',
      email: 'local@server.dev',
      photoUrl: null,
      metadata: {
        'provider': displayName,
        'baseUri': baseUri.toString(),
      },
    );
  }

  /// Default implementation for refreshAuth
  /// 
  /// Local providers typically don't need token refresh, so this returns
  /// the same account. Concrete implementations can override this method
  /// if their authentication system requires token refresh.
  @override
  Future<CloudAccount> refreshAuth(CloudAccount account) async {
    return account;
  }
}