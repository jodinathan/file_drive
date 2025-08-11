/// Token storage interface for cloud providers
library;

import '../models/oauth_types.dart';

/// Abstract interface for token storage operations
abstract class TokenStorage {
  /// Store a token for a specific provider and user
  Future<void> storeToken(String providerId, String userId, AuthResult token);
  
  /// Retrieve a token for a specific provider and user
  Future<AuthResult?> getToken(String providerId, String userId);
  
  /// Get all tokens for a specific provider
  Future<Map<String, AuthResult>> getAllTokens(String providerId);
  
  /// Remove a token for a specific provider and user
  Future<void> removeToken(String providerId, String userId);
  
  /// Remove all tokens for a specific provider
  Future<void> removeAllTokens(String providerId);
  
  /// Check if a token exists for a specific provider and user
  Future<bool> hasToken(String providerId, String userId);
  
  /// Get the currently active user for a provider
  Future<String?> getActiveUser(String providerId);
  
  /// Set the currently active user for a provider
  Future<void> setActiveUser(String providerId, String userId);
  
  /// Clear the active user for a provider
  Future<void> clearActiveUser(String providerId);
}