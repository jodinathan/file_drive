/// Mixin for token storage implementations that support account deletion
library;

/// Mixin that provides account deletion capabilities for TokenStorage implementations
mixin AccountDeletionMixin {
  /// Delete a specific user account from storage
  /// Returns true if the account was successfully deleted
  Future<bool> deleteUserAccount(String providerId, String userId);
  
  /// Delete all accounts for a specific provider
  /// Returns the number of accounts deleted
  Future<int> deleteAllAccountsForProvider(String providerId);
  
  /// Get list of all user IDs for a provider (useful for UI)
  Future<List<String>> getUserIdsForProvider(String providerId);
  
  /// Check if a specific user account exists
  Future<bool> userAccountExists(String providerId, String userId);
}