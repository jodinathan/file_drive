/// Account list widget for OAuth providers
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/oauth_cloud_provider.dart';

/// Widget that displays a list of user accounts for OAuth providers
class AccountList extends StatefulWidget {
  final OAuthCloudProvider provider;
  final FileDriveTheme theme;
  final double width;

  const AccountList({
    Key? key,
    required this.provider,
    required this.theme,
    this.width = 200,
  }) : super(key: key);

  @override
  State<AccountList> createState() => _AccountListState();
}

class _AccountListState extends State<AccountList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: widget.theme.colorScheme.onSurface.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.provider.providerColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: widget.theme.colorScheme.onSurface.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_circle,
                  color: widget.provider.providerColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contas',
                    style: widget.theme.typography.title.copyWith(
                      color: widget.provider.providerColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Account list
          Expanded(
            child: FutureBuilder<Map<String, Map<String, dynamic>>>(
              future: widget.provider.getAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Erro ao carregar contas',
                        style: widget.theme.typography.body.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  );
                }

                final users = snapshot.data ?? {};
                
                if (users.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            size: 48,
                            color: widget.theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma conta\nconectada',
                            textAlign: TextAlign.center,
                            style: widget.theme.typography.body.copyWith(
                              color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  children: [
                    ...users.entries.map((entry) {
                      final userId = entry.key;
                      final userInfo = entry.value;
                      final isActive = userId == widget.provider.activeUserId;
                      // Check needsReauth from both provider state and user data
                      final needsReauth = (isActive && widget.provider.needsReauth) || 
                                         (userInfo['needsReauth'] == true) ||
                                         (userInfo['hasPermissionIssues'] == true);

                      return _buildAccountCard(userId, userInfo, isActive, needsReauth);
                    }).toList(),
                    
                    // Add account button
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: OutlinedButton.icon(
                        onPressed: () => widget.provider.authenticate(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Adicionar Conta'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: widget.provider.providerColor,
                          side: BorderSide(color: widget.provider.providerColor.withOpacity(0.5)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(String userId, Map<String, dynamic> userInfo, bool isActive, bool needsReauth) {
    final name = userInfo['name'] ?? userInfo['email'] ?? 'Usuário';
    final email = userInfo['email'] ?? '';
    final picture = userInfo['picture'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive 
            ? widget.provider.providerColor.withOpacity(0.1)
            : widget.theme.colorScheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive 
              ? widget.provider.providerColor.withOpacity(0.3)
              : widget.theme.colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: isActive ? null : () => _switchToUser(userId),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: widget.provider.providerColor,
                        backgroundImage: picture != null ? NetworkImage(picture) : null,
                        child: picture == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (needsReauth)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.warning,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (isActive && !needsReauth)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: widget.theme.typography.body.copyWith(
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            color: needsReauth 
                                ? Colors.orange
                                : (isActive 
                                    ? widget.provider.providerColor
                                    : widget.theme.colorScheme.onSurface),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: widget.theme.typography.caption.copyWith(
                              color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  
                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (needsReauth)
                        IconButton(
                          onPressed: () => widget.provider.authenticate(),
                          icon: const Icon(Icons.refresh, size: 16),
                          color: Colors.orange,
                          tooltip: 'Reautenticar',
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        )
                      else if (isActive)
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: widget.provider.providerColor,
                        ),
                      
                      // Remove account button
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'remove') {
                            _showRemoveAccountDialog(userId, name);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Remover conta', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        icon: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'Opções da conta',
                      ),
                    ],
                  ),
                ],
              ),
              
              if (needsReauth)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Permissões insuficientes - clique para reautenticar',
                    style: widget.theme.typography.caption.copyWith(
                      color: Colors.orange,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _switchToUser(String userId) async {
    final success = await widget.provider.switchToUser(userId);
    if (success && mounted) {
      setState(() {});
    }
  }

  void _showRemoveAccountDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remover Conta'),
          content: Text(
            'Tem certeza que deseja remover a conta "$userName"?\n\n'
            'Esta ação não pode ser desfeita e você precisará fazer login novamente para usar esta conta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeAccount(userId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
  }

  void _removeAccount(String userId) async {
    try {
      await widget.provider.deleteUser(userId);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta removida com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover conta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}