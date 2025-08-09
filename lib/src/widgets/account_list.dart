/// Account management widget for OAuth providers
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/oauth_cloud_provider.dart';

/// Widget that displays and manages OAuth accounts
class AccountList extends StatefulWidget {
  final OAuthCloudProvider provider;
  final FileDriveTheme theme;
  final double? width;
  
  const AccountList({
    Key? key,
    required this.provider,
    required this.theme,
    this.width,
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
            color: widget.theme.colorScheme.onBackground.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          // Header com título e contador
          _buildHeader(),
          
          // Lista de contas
          Expanded(
            child: _buildAccountsList(),
          ),
          
          // Botão adicionar conta
          _buildAddAccountButton(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: widget.theme.colorScheme.onBackground.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Ícone do provedor
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.provider.providerColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          
          // Título e contador
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contas',
                  style: widget.theme.typography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                FutureBuilder<Map<String, Map<String, dynamic>>>(
                  future: widget.provider.getAllUsers(),
                  builder: (context, snapshot) {
                    final userCount = snapshot.data?.length ?? 0;
                    return Text(
                      '$userCount conta${userCount != 1 ? 's' : ''} conectada${userCount != 1 ? 's' : ''}',
                      style: widget.theme.typography.caption.copyWith(
                        color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAccountsList() {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: widget.provider.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }
        
        final users = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final entry = users.entries.elementAt(index);
            final userId = entry.key;
            final userInfo = entry.value;
            final isActive = userId == widget.provider.activeUserId;
            
            return _buildAccountCard(userId, userInfo, isActive);
          },
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
            Icons.person_outline,
            size: 48,
            color: widget.theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma conta conectada',
            style: widget.theme.typography.body.copyWith(
              color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione uma conta para começar',
            style: widget.theme.typography.caption.copyWith(
              color: widget.theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAccountCard(String userId, Map<String, dynamic> userInfo, bool isActive) {
    final name = userInfo['name'] ?? userInfo['email'] ?? 'Usuário';
    final email = userInfo['email'] ?? '';
    final picture = userInfo['picture'];
    final needsReauth = (userInfo['needsReauth'] == true) || (userInfo['hasPermissionIssues'] == true);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? null : () => _switchToUser(userId),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive 
                  ? widget.provider.providerColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive 
                  ? Border.all(color: widget.provider.providerColor)
                  : null,
            ),
            child: Row(
              children: [
                // Avatar sem margem
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: picture != null
                          ? Image.network(
                              picture,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildFallbackAvatar(name);
                              },
                            )
                          : _buildFallbackAvatar(name),
                    ),
                    // Indicador de status
                    if (needsReauth)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.warning,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (isActive && !needsReauth)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                
                // Info da conta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: widget.theme.typography.body.copyWith(
                          fontSize: 16,
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
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: widget.theme.typography.body.copyWith(
                            fontSize: 13,
                            color: widget.theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (needsReauth)
                        Text(
                          'Requer reautenticação',
                          style: widget.theme.typography.caption.copyWith(
                            color: Colors.orange,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Menu de ações
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onSelected: (value) => _handleAccountAction(value, userId),
                  itemBuilder: (context) => [
                    if (!isActive)
                      const PopupMenuItem(
                        value: 'switch',
                        child: Row(
                          children: [
                            Icon(Icons.switch_account, size: 16),
                            SizedBox(width: 8),
                            Text('Alternar para esta conta'),
                          ],
                        ),
                      ),
                    if (needsReauth)
                      const PopupMenuItem(
                        value: 'reauth',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 16),
                            SizedBox(width: 8),
                            Text('Refazer autenticação'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remover conta', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFallbackAvatar(String name) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: widget.provider.providerColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
  
  Widget _buildAddAccountButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleAddAccount,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Adicionar Conta'),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.provider.providerColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
  
  void _switchToUser(String userId) async {
    await widget.provider.switchToUser(userId);
    setState(() {});
  }
  
  void _handleAccountAction(String action, String userId) async {
    switch (action) {
      case 'switch':
        _switchToUser(userId);
        break;
      case 'reauth':
        // Para OAuth providers, apenas chama authenticate novamente
        widget.provider.authenticate();
        setState(() {});
        break;
      case 'remove':
        await _showRemoveAccountDialog(userId);
        break;
    }
  }
  
  Future<void> _showRemoveAccountDialog(String userId) async {
    final userInfo = await widget.provider.getUserInfo();
    final userName = userInfo?['name'] ?? userInfo?['email'] ?? 'esta conta';
    
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Conta'),
        content: Text('Tem certeza que deseja remover $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Como não temos método removeUser, apenas mostra uma mensagem
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Funcionalidade de remoção não implementada ainda'),
          ),
        );
      }
    }
  }
  
  void _handleAddAccount() {
    widget.provider.authenticate();
  }
}