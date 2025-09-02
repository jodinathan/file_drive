import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cloud_account.dart';
import '../models/account_status.dart';
import 'account_storage.dart';

/// SharedPreferences implementation of AccountStorage
class SharedPreferencesAccountStorage implements AccountStorage {
  static const String _accountsKey = 'file_cloud_accounts';
  
  SharedPreferences? _prefs;
  
  /// Initializes the shared preferences instance
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  /// Gets the stored accounts JSON data
  Future<Map<String, dynamic>> _getStoredData() async {
    await _ensureInitialized();
    final jsonString = _prefs!.getString(_accountsKey);
    if (jsonString == null) return {};
    
    try {
      return Map<String, dynamic>.from(json.decode(jsonString));
    } catch (e) {
      // If data is corrupted, start fresh
      return {};
    }
  }
  
  /// Saves the accounts data to storage
  Future<void> _saveData(Map<String, dynamic> data) async {
    await _ensureInitialized();
    await _prefs!.setString(_accountsKey, json.encode(data));
  }
  
  @override
  Future<List<CloudAccount>> getAccounts() async {
    final data = await _getStoredData();
    final accounts = <CloudAccount>[];
    
    for (final entry in data.entries) {
      try {
        final account = CloudAccount.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
        accounts.add(account);
      } catch (e) {
        // Skip corrupted account data
        continue;
      }
    }
    
    // Sort by creation date (newest first)
    accounts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return accounts;
  }
  
  Future<List<CloudAccount>> getAccountsByProvider(String providerType) async {
    final allAccounts = await getAccounts();
    return allAccounts
        .where((account) => account.providerType == providerType)
        .toList();
  }
  
  @override
  Future<CloudAccount?> getAccount(String accountId) async {
    final data = await _getStoredData();
    final accountData = data[accountId];
    
    if (accountData == null) return null;
    
    try {
      return CloudAccount.fromJson(
        Map<String, dynamic>.from(accountData),
      );
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveAccount(CloudAccount account) async {
    final data = await _getStoredData();
    data[account.id] = account.toJson();
    await _saveData(data);
  }
  
  @override
  Future<void> removeAccount(String accountId) async {
    final data = await _getStoredData();
    data.remove(accountId);
    await _saveData(data);
  }
  
  Future<void> removeAccountsByProvider(String providerType) async {
    final data = await _getStoredData();
    final keysToRemove = <String>[];
    
    for (final entry in data.entries) {
      try {
        final accountData = Map<String, dynamic>.from(entry.value);
        if (accountData['providerType'] == providerType) {
          keysToRemove.add(entry.key);
        }
      } catch (e) {
        // Skip corrupted data
        continue;
      }
    }
    
    for (final key in keysToRemove) {
      data.remove(key);
    }
    
    await _saveData(data);
  }
  
  @override
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _prefs!.remove(_accountsKey);
  }
  
  Future<void> updateAccountStatus(String accountId, AccountStatus status) async {
    final account = await getAccount(accountId);
    if (account != null) {
      final updatedAccount = account.updateStatus(status);
      await saveAccount(updatedAccount);
    }
  }
  
  Future<void> updateAccountTokens({
    required String accountId,
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    final account = await getAccount(accountId);
    if (account != null) {
      final updatedAccount = account.updateTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );
      await saveAccount(updatedAccount);
    }
  }
}