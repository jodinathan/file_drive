import '../models/cloud_account.dart';

/// Abstract base class for storing and retrieving cloud accounts
abstract class AccountStorage {
  /// Retrieves all stored cloud accounts
  Future<List<CloudAccount>> getAccounts();

  /// Retrieves a specific account by ID
  Future<CloudAccount?> getAccount(String accountId);

  /// Saves or updates a cloud account
  Future<void> saveAccount(CloudAccount account);

  /// Removes a cloud account
  Future<void> removeAccount(String accountId);

  /// Clears all stored accounts
  Future<void> clearAll();

  /// Gets the last selected provider type name (optional preference)
  Future<String?> getLastSelectedProvider() async => null;

  /// Saves the last selected provider type name (optional preference)
  Future<void> setLastSelectedProvider(String providerType) async {}
}