/// Represents the status of a cloud account connection.
enum AccountStatus {
  /// The account is fully connected and operational.
  connected,

  /// The account is connected, but requires re-authentication to refresh permissions.
  needsReauth,

  /// The account has encountered an error.
  error,

  /// The account is currently being loaded or processed.
  loading,
}

/// A data model for a user's cloud account.
///
/// This class holds all relevant information about a single cloud account,
/// including user details, authentication status, and provider information.
class CloudAccount {
  /// The unique identifier for this account.
  final String id;

  /// The display name of the user (e.g., "John Doe").
  final String name;

  /// The user's email address.
  final String email;

  /// The URL for the user's profile picture. Can be null.
  final String? pictureUrl;

  /// The current status of the account.
  final AccountStatus status;

  /// Whether this account is the currently active one.
  final bool isActive;
  
  /// The provider this account belongs to (e.g., 'google_drive').
  final String providerId;

  const CloudAccount({
    required this.id,
    required this.name,
    required this.email,
    this.pictureUrl,
    required this.status,
    required this.isActive,
    required this.providerId,
  });
}
