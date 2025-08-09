import 'package:flutter/material.dart';
import '../models/cloud_account.dart';

/// A widget that displays a single cloud account as a card.
///
/// This card shows the user's avatar, name, email, and current status.
/// It also provides a menu with actions like re-authenticating or removing the account.
class AccountCard extends StatelessWidget {
  /// The account to display.
  final CloudAccount account;

  /// The theme to use for styling the card.
  final ThemeData theme;

  /// Callback function to be called when the user wants to remove the account.
  final VoidCallback? onRemove;

  /// Callback function to be called when the user wants to re-authenticate.
  final VoidCallback? onReauthenticate;

  /// Callback function when the card is tapped.
  final VoidCallback? onTap;

  const AccountCard({
    Key? key,
    required this.account,
    required this.theme,
    this.onRemove,
    this.onReauthenticate,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(account.status);
    final hasError = account.status == AccountStatus.error || account.status == AccountStatus.needsReauth;

    return Card(
      elevation: account.isActive ? 4.0 : 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: account.isActive ? theme.primaryColor : Colors.grey.shade300,
          width: account.isActive ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundImage: account.pictureUrl != null ? NetworkImage(account.pictureUrl!) : null,
                child: account.pictureUrl == null
                    ? Text(account.name.isNotEmpty ? account.name[0].toUpperCase() : '?')
                    : null,
              ),
              const SizedBox(width: 12),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: theme.textTheme.titleMedium),
                    Text(account.email, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(_getStatusText(account.status), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions Menu
              if (onRemove != null || onReauthenticate != null)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'remove') {
                      onRemove?.call();
                    } else if (value == 'reauth') {
                      onReauthenticate?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    if (hasError)
                      const PopupMenuItem<String>(
                        value: 'reauth',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 16),
                            SizedBox(width: 8),
                            Text('Re-authenticate'),
                          ],
                        ),
                      ),
                    const PopupMenuItem<String>(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove Account', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(AccountStatus status) {
    switch (status) {
      case AccountStatus.connected:
        return Colors.green;
      case AccountStatus.needsReauth:
        return Colors.orange;
      case AccountStatus.error:
        return Colors.red;
      case AccountStatus.loading:
        return Colors.grey;
    }
  }

  String _getStatusText(AccountStatus status) {
    switch (status) {
      case AccountStatus.connected:
        return 'Connected';
      case AccountStatus.needsReauth:
        return 'Needs Re-authentication';
      case AccountStatus.error:
        return 'Error';
      case AccountStatus.loading:
        return 'Loading...';
    }
  }
}
