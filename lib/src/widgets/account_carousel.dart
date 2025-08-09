/// Account carousel widget for horizontal account selection
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/oauth_cloud_provider.dart';

/// Horizontal carousel of user accounts with add account button
class AccountCarousel extends StatefulWidget {
  final OAuthCloudProvider provider;
  final FileDriveTheme theme;
  final double height;

  const AccountCarousel({
    Key? key,
    required this.provider,
    required this.theme,
    this.height = 100,
  }) : super(key: key);

  @override
  State<AccountCarousel> createState() => _AccountCarouselState();
}

class _AccountCarouselState extends State<AccountCarousel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: widget.theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: FutureBuilder<Map<String, Map<String, dynamic>>>(
        future: widget.provider.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final users = snapshot.data ?? {};

          return Row(
            children: [
              // Accounts carousel
              Expanded(
                child: _buildAccountsCarousel(users),
              ),
              // Add account button
              _buildAddAccountButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(widget.theme.colorScheme.primary),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Erro ao carregar contas',
            style: widget.theme.typography.body.copyWith(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsCarousel(Map<String, Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final entry = users.entries.elementAt(index);
        final userId = entry.key;
        final userInfo = entry.value;
        final isActive = userId == widget.provider.activeUserId;
        final needsReauth = (isActive && widget.provider.needsReauth) || 
                           (userInfo['needsReauth'] == true) ||
                           (userInfo['hasPermissionIssues'] == true);

        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _buildAccountCard(userId, userInfo, isActive, needsReauth),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 32,
            color: widget.theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Nenhuma conta conectada',
            style: widget.theme.typography.body.copyWith(
              color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
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

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 240,
        height: 80,
        decoration: BoxDecoration(
          color: isActive 
              ? widget.provider.providerColor.withOpacity(0.1)
              : widget.theme.colorScheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive 
                ? widget.provider.providerColor.withOpacity(0.3)
                : widget.theme.colorScheme.onSurface.withOpacity(0.1),
            width: isActive ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: isActive ? null : () => _switchToUser(userId),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              // Avatar - ocupa toda a altura do lado esquerdo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  color: widget.provider.providerColor,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: picture != null 
                      ? Image.network(
                          picture,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(name),
                        )
                      : _buildFallbackAvatar(name),
                ),
              ),
              
              // Conteúdo do lado direito
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Nome
                      Text(
                        name,
                        style: widget.theme.typography.body.copyWith(
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          color: needsReauth 
                              ? Colors.orange
                              : (isActive 
                                  ? widget.provider.providerColor
                                  : widget.theme.colorScheme.onSurface),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // Email
                      if (email.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            email,
                            style: widget.theme.typography.body.copyWith(
                              fontSize: 12,
                              color: widget.theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      
                      // Status de reauth
                      if (needsReauth)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Requer reautenticação',
                            style: widget.theme.typography.caption.copyWith(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Ações no lado direito
              Container(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (needsReauth)
                      IconButton(
                        onPressed: () => widget.provider.authenticate(),
                        icon: const Icon(Icons.refresh, size: 18),
                        color: Colors.orange,
                        tooltip: 'Reautenticar',
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      )
                    else if (isActive)
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green,
                      ),
                    
                    // Menu de opções compacto
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: PopupMenuButton<String>(
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
                          size: 14,
                          color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        tooltip: 'Opções da conta',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String name) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: widget.provider.providerColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildAddAccountButton() {
    return Container(
      width: 120,
      margin: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () => widget.provider.authenticate(),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Adicionar'),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.provider.providerColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
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