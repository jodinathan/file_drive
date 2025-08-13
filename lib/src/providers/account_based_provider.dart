import '../models/cloud_account.dart';
import 'base_cloud_provider.dart';

// Re-export types that account-based providers need
export 'base_cloud_provider.dart' show UserProfile, CloudProviderException, UploadProgress, UploadStatus;

/// Base class for providers that require account-based authentication
abstract class AccountBasedProvider extends BaseCloudProvider {
  CloudAccount? _currentAccount;
  
  @override
  bool get requiresAccountManagement => true;
  
  /// Gets the current account being used by this provider
  CloudAccount? get currentAccount => _currentAccount;
  
  /// Initializes the provider with an account
  /// This method should be called before using other methods
  void initialize(CloudAccount account) {
    _currentAccount = account;
  }
  
  /// Gets the user profile information
  Future<UserProfile> getUserProfile();
  
  /// Refreshes the authentication token
  /// 
  /// [account] - The account to refresh
  /// Returns updated account with new tokens
  Future<CloudAccount> refreshAuth(CloudAccount account);
  
  /// Ensures the provider is authenticated
  void ensureAuthenticated() {
    if (_currentAccount?.accessToken == null) {
      throw CloudProviderException('Provider not authenticated');
    }
  }
}