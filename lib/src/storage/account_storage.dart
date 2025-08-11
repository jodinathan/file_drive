import '../models/cloud_account.dart';
import '../models/account_status.dart';

/// Abstract base class for storing and retrieving cloud accounts
abstract class AccountStorage {
  /// Retrieves all stored cloud accounts
  Future<List<CloudAccount>> getAccounts();
  
  /// Retrieves accounts for a specific provider type
  Future<List<CloudAccount>> getAccountsByProvider(String providerType);
  
  /// Retrieves a specific account by ID
  Future<CloudAccount?> getAccount(String accountId);
  
  /// Saves or updates a cloud account
  Future<void> saveAccount(CloudAccount account);
  
  /// Removes a cloud account
  Future<void> removeAccount(String accountId);
  
  /// Removes all accounts for a specific provider
  Future<void> removeAccountsByProvider(String providerType);
  
  /// Clears all stored accounts
  Future<void> clearAll();
  
  /// Updates the status of a specific account
  Future<void> updateAccountStatus(String accountId, AccountStatus status);
  
  /// Updates tokens for a specific account
  Future<void> updateAccountTokens({
    required String accountId,
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  });
}