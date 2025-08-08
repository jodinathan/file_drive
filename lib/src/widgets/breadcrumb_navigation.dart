/// Breadcrumb navigation widget for folder hierarchy
library;

import 'package:flutter/material.dart';
import '../models/cloud_folder.dart';
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';
import '../providers/base/oauth_cloud_provider.dart';
import '../storage/account_deletion_mixin.dart';
import '../utils/dialog_helper.dart';

/// Widget for displaying and navigating folder hierarchy
class BreadcrumbNavigation extends StatefulWidget {
  final List<CloudFolder> currentPath;
  final Function(String?) onNavigate;
  final FileDriveTheme theme;
  final CloudProvider? provider;
  
  const BreadcrumbNavigation({
    Key? key,
    required this.currentPath,
    required this.onNavigate,
    required this.theme,
    this.provider,
  }) : super(key: key);
  
  @override
  State<BreadcrumbNavigation> createState() => _BreadcrumbNavigationState();
}

class _BreadcrumbNavigationState extends State<BreadcrumbNavigation> {
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: widget.theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Home button
          InkWell(
            onTap: () => widget.onNavigate(null),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.home,
                    size: 16,
                    color: widget.theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Home',
                    style: widget.theme.typography.body.copyWith(
                      color: widget.theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Path segments
          ...widget.currentPath.asMap().entries.map((entry) {
            final index = entry.key;
            final folder = entry.value;
            final isLast = index == widget.currentPath.length - 1;
            
            return Row(
              children: [
                // Separator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: widget.theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                
                // Folder name
                if (isLast)
                  Text(
                    folder.name,
                    style: widget.theme.typography.body.copyWith(
                      color: widget.theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  InkWell(
                    onTap: () => widget.onNavigate(folder.id),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        folder.name,
                        style: widget.theme.typography.body.copyWith(
                          color: widget.theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }).toList(),
          
          // Spacer to push overflow menu to the right
          const Spacer(),
          
          // User info and account switcher
          _buildUserSection(),
          
          // Overflow menu for small screens
          if (widget.currentPath.length > 3)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz,
                color: widget.theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              itemBuilder: (context) => widget.currentPath.map((folder) {
                return PopupMenuItem<String>(
                  value: folder.id,
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder,
                        size: 16,
                        color: widget.theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(folder.name),
                    ],
                  ),
                );
              }).toList(),
              onSelected: widget.onNavigate,
            ),
        ],
      ),
    );
  }
  
  /// Build user section with current user info and account switcher
  Widget _buildUserSection() {
    if (widget.provider == null || widget.provider is! OAuthCloudProvider) {
      return const SizedBox.shrink();
    }
    
    final oauthProvider = widget.provider as OAuthCloudProvider;
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: oauthProvider.getCurrentUserInfo(),
      builder: (context, snapshot) {
        // Check if current user has permission issues
        final hasPermissionIssues = _hasCurrentUserPermissionIssues(oauthProvider);
        
        // Always show the user section if we have an OAuth provider
        // Even if we don't have user data yet, we can show a loading state or default UI
        final userInfo = snapshot.data ?? {};
        final userName = userInfo['name'] ?? userInfo['email'] ?? 'Usuário';
        final userAvatar = userInfo['picture'];
        
        // Show loading state if no data and no permission issues
        if (!snapshot.hasData && !hasPermissionIssues && snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: widget.theme.colorScheme.primary.withOpacity(0.3),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.theme.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Account switcher button - always visible
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.account_circle,
                  color: widget.theme.colorScheme.primary,
                  size: 20,
                ),
                tooltip: 'Trocar conta',
                itemBuilder: (context) => _buildAccountMenuItems(oauthProvider),
                onSelected: (value) => _handleAccountAction(oauthProvider, value),
              ),
            ],
          );
        }
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User avatar and name with permission indicator
            InkWell(
              onTap: hasPermissionIssues ? () => _handleReauth(oauthProvider) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasPermissionIssues 
                      ? Colors.orange.withOpacity(0.1)
                      : widget.theme.colorScheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasPermissionIssues 
                        ? Colors.orange.withOpacity(0.3)
                        : widget.theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar with warning indicator
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: hasPermissionIssues 
                              ? Colors.orange 
                              : widget.theme.colorScheme.primary,
                          backgroundImage: userAvatar != null 
                              ? NetworkImage(userAvatar) 
                              : null,
                          child: userAvatar == null 
                              ? Text(
                                  userName.substring(0, 1).toUpperCase(),
                                  style: widget.theme.typography.body.copyWith(
                                    color: widget.theme.colorScheme.onPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        if (hasPermissionIssues)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: widget.theme.colorScheme.surface,
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.warning,
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Name with permission status
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userName,
                            style: widget.theme.typography.body.copyWith(
                              color: hasPermissionIssues 
                                  ? Colors.orange.shade700
                                  : widget.theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasPermissionIssues)
                            Text(
                              'Clique para reautenticar',
                              style: widget.theme.typography.body.copyWith(
                                fontSize: 10,
                                color: Colors.orange.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (hasPermissionIssues)
                      const SizedBox(width: 4),
                    if (hasPermissionIssues)
                      Icon(
                        Icons.refresh,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Account switcher button
            PopupMenuButton<String>(
              icon: Icon(
                Icons.account_circle,
                color: widget.theme.colorScheme.primary,
                size: 20,
              ),
              tooltip: 'Trocar conta',
              itemBuilder: (context) => _buildAccountMenuItems(oauthProvider),
              onSelected: (value) => _handleAccountAction(oauthProvider, value),
            ),
          ],
        );
      },
    );
  }
  
  /// Build account menu items
  List<PopupMenuEntry<String>> _buildAccountMenuItems(OAuthCloudProvider provider) {
    return [
      PopupMenuItem<String>(
        value: 'add_account',
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 16,
              color: widget.theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Adicionar outra conta'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'manage_accounts',
        child: FutureBuilder<Map<String, Map<String, dynamic>>>(
          future: provider.getAllUsers(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Row(
                children: [
                  Icon(Icons.manage_accounts, size: 16),
                  SizedBox(width: 8),
                  Text('Gerenciar contas'),
                ],
              );
            }
            
            final users = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.manage_accounts,
                      size: 16,
                      color: widget.theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Contas disponíveis:',
                      style: widget.theme.typography.body.copyWith(
                        fontSize: 12,
                        color: widget.theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...users.entries.map((entry) {
                  final userId = entry.key;
                  final userInfo = entry.value;
                  final isActive = userId == provider.activeUserId;
                  final needsReauth = isActive && _hasCurrentUserPermissionIssues(provider);
                  
                  return InkWell(
                    onTap: isActive ? null : () {
                      Navigator.of(context).pop();
                      _switchToUser(provider, userId);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: isActive 
                                ? widget.theme.colorScheme.primary 
                                : widget.theme.colorScheme.onSurface.withOpacity(0.3),
                            backgroundImage: userInfo['picture'] != null 
                                ? NetworkImage(userInfo['picture']) 
                                : null,
                            child: userInfo['picture'] == null 
                                ? Text(
                                    (userInfo['name'] ?? userInfo['email'] ?? 'U')
                                        .substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: isActive 
                                          ? widget.theme.colorScheme.onPrimary
                                          : widget.theme.colorScheme.surface,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              userInfo['name'] ?? userInfo['email'] ?? 'Usuário',
                              style: widget.theme.typography.body.copyWith(
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                color: needsReauth 
                                    ? Colors.orange
                                    : (isActive 
                                        ? widget.theme.colorScheme.primary
                                        : widget.theme.colorScheme.onSurface),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (needsReauth)
                            Icon(
                              Icons.warning,
                              size: 12,
                              color: Colors.orange,
                            )
                          else if (isActive)
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: widget.theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            );
          },
        ),
      ),
      
      // Account deletion options (only if storage supports it)
      if (_supportsAccountDeletion(provider)) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete_current_account',
          child: Row(
            children: [
              Icon(
                Icons.person_remove,
                size: 16,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'Remover conta atual',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete_all_accounts',
          child: Row(
            children: [
              Icon(
                Icons.delete_forever,
                size: 16,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Remover todas as contas',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ),
        ),
      ],
    ];
  }
  
  /// Switch to different user
  void _switchToUser(OAuthCloudProvider provider, String userId) async {
    final success = await provider.switchToUser(userId);
    if (success) {
      // The parent widget should handle the rebuild
      // This is just a placeholder for now
      print('Switched to user: $userId');
    }
  }
  
  /// Handle account menu actions
  void _handleAccountAction(OAuthCloudProvider provider, String action) async {
    if (action == 'add_account') {
      // Trigger authentication for a new account
      provider.authenticate();
    } else if (action.startsWith('switch_to_')) {
      // Extract user ID and switch
      final userId = action.substring('switch_to_'.length);
      _switchToUser(provider, userId);
    } else if (action == 'delete_current_account') {
      await _deleteCurrentAccount(provider);
    } else if (action == 'delete_all_accounts') {
      await _deleteAllAccounts(provider);
    }
  }
  
  /// Check if current user has permission issues
  bool _hasCurrentUserPermissionIssues(OAuthCloudProvider provider) {
    final activeUserId = provider.activeUserId;
    if (activeUserId == null) return false;
    
    // Check stored token for permission issues
    // This would typically check the stored AuthResult flags
    return provider.needsReauth;
  }
  
  /// Handle re-authentication for user with permission issues
  void _handleReauth(OAuthCloudProvider provider) async {
    // Trigger OAuth flow to get new permissions
    provider.authenticate();
  }
  
  /// Check if the storage supports account deletion
  bool _supportsAccountDeletion(OAuthCloudProvider provider) {
    return provider.tokenStorage is AccountDeletionMixin;
  }
  
  /// Delete current active account
  Future<void> _deleteCurrentAccount(OAuthCloudProvider provider) async {
    final currentUserId = provider.activeUserId;
    if (currentUserId == null) return;
    
    final storage = provider.tokenStorage;
    if (storage is! AccountDeletionMixin) return;
    
    // Show confirmation dialog
    final shouldDelete = await _showDeleteConfirmationDialog(
      'Remover Conta Atual',
      'Tem certeza que deseja remover a conta atual? Esta ação não pode ser desfeita.',
    );
    
    if (shouldDelete) {
      final success = await (storage as AccountDeletionMixin).deleteUserAccount(provider.providerId, currentUserId);
      if (success) {
        print('Account deleted successfully: $currentUserId');
        // Use the provider's deleteUser method to properly update state
        await provider.deleteUser(currentUserId);
        // Force a rebuild of the widget
        if (mounted) {
          setState(() {});
        }
      }
    }
  }
  
  /// Delete all accounts for this provider
  Future<void> _deleteAllAccounts(OAuthCloudProvider provider) async {
    final storage = provider.tokenStorage;
    if (storage is! AccountDeletionMixin) return;
    
    // Show confirmation dialog
    final shouldDelete = await _showDeleteConfirmationDialog(
      'Remover Todas as Contas',
      'Tem certeza que deseja remover TODAS as contas? Esta ação não pode ser desfeita e você perderá o acesso a todos os arquivos.',
    );
    
    if (shouldDelete) {
      // Get all user IDs before deletion
      final userIds = await (storage as AccountDeletionMixin).getUserIdsForProvider(provider.providerId);
      
      final deletedCount = await (storage as AccountDeletionMixin).deleteAllAccountsForProvider(provider.providerId);
      print('Deleted $deletedCount accounts for ${provider.providerId}');
      
      // Update provider state for the active user if it was deleted
      if (userIds.contains(provider.activeUserId)) {
        provider.updateStatus(ProviderStatus.disconnected);
        // Clear provider's internal state
        await provider.logout();
      }
      
      // Force a rebuild of the widget
      if (mounted) {
        setState(() {});
      }
    }
  }
  
  /// Show confirmation dialog for account deletion
  Future<bool> _showDeleteConfirmationDialog(String title, String message) async {
    if (!mounted) return false;
    
    return await DialogHelper.showDeleteAccountConfirmation(
      context: context,
      title: title,
      message: message,
    );
  }
}

/// Compact breadcrumb for mobile layouts
class CompactBreadcrumbNavigation extends StatelessWidget {
  final List<CloudFolder> currentPath;
  final Function(String?) onNavigate;
  final FileDriveTheme theme;
  
  const CompactBreadcrumbNavigation({
    Key? key,
    required this.currentPath,
    required this.onNavigate,
    required this.theme,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final currentFolder = currentPath.isNotEmpty ? currentPath.last : null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          if (currentPath.isNotEmpty)
            IconButton(
              onPressed: () {
                if (currentPath.length > 1) {
                  onNavigate(currentPath[currentPath.length - 2].id);
                } else {
                  onNavigate(null);
                }
              },
              icon: Icon(
                Icons.arrow_back,
                color: theme.colorScheme.primary,
              ),
            ),
          
          // Current folder name or Home
          Expanded(
            child: Text(
              currentFolder?.name ?? 'Home',
              style: theme.typography.title.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Folder menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.folder_open,
              color: theme.colorScheme.primary,
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: null,
                child: Row(
                  children: [
                    Icon(
                      Icons.home,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Home'),
                  ],
                ),
              ),
              ...currentPath.map((folder) {
                return PopupMenuItem<String>(
                  value: folder.id,
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(folder.name),
                    ],
                  ),
                );
              }).toList(),
            ],
            onSelected: onNavigate,
          ),
        ],
      ),
    );
  }
}