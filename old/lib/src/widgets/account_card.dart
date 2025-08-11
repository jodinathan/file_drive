import 'package:flutter/material.dart';
import '../models/cloud_account.dart';
import '../models/file_drive_config.dart';

class AccountCard extends StatelessWidget {
  final CloudAccount account;
  final FileDriveTheme theme;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onReauth;

  const AccountCard({
    Key? key,
    required this.account,
    required this.theme,
    required this.onTap,
    required this.onRemove,
    required this.onReauth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: account.isActive ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: account.isActive
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundImage: account.photoUrl != null
                    ? NetworkImage(account.photoUrl!)
                    : null,
                child: account.photoUrl == null
                    ? Text(
                        account.name.isNotEmpty ? account.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 24),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      account.email,
                      style: theme.typography.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Status and Menu
              Stack(
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'remove') onRemove();
                      if (value == 'reauth') onReauth();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'remove', child: Text('Remover conta')),
                      if (account.status == AccountStatus.needsReauth)
                        const PopupMenuItem(value: 'reauth', child: Text('Reautenticar')),
                    ],
                  ),
                  if (account.status == AccountStatus.needsReauth)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(
                        Icons.warning,
                        color: Colors.orange,
                        size: 16,
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

  IconData _getStatusIcon(AccountStatus status) {
  switch (status) {
    case AccountStatus.active: return Icons.check_circle;
    case AccountStatus.needsReauth: return Icons.warning;
    case AccountStatus.error: return Icons.error;
    case AccountStatus.loading: return Icons.hourglass_empty;
case AccountStatus.inactive: return Icons.radio_button_off;
  }
}
Color _getStatusColor(AccountStatus status) {
  switch (status) {
    case AccountStatus.active: return Colors.green;
    case AccountStatus.inactive: return Colors.grey;
    case AccountStatus.needsReauth: return Colors.orange;
    case AccountStatus.error: return Colors.red;
    case AccountStatus.loading: return Colors.blue;
  }
}
}