/// Account carousel widget for horizontal account selection
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/oauth_cloud_provider.dart';
import 'account_card.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../models/cloud_account.dart';

/// Horizontal carousel of user accounts with add account button
class AccountCarousel extends StatefulWidget {
  final OAuthCloudProvider provider;
  final FileDriveTheme theme;
  final double height;

  const AccountCarousel({
    Key? key,
    required this.provider,
    required this.theme,
    this.height = 80,
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
      child: FutureBuilder<List<CloudAccount>>(
        future: widget.provider.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          List<CloudAccount> accounts = snapshot.data ?? [];

          return Row(
            children: [
              // Accounts carousel
              Expanded(
                child: _buildAccountsCarousel(accounts),
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

  Widget _buildAccountsCarousel(List<CloudAccount> accounts) {
  if (accounts.isEmpty) {
    return _buildEmptyState();
  }

  return CarouselSlider.builder(
    itemCount: accounts.length,
    itemBuilder: (context, index, realIndex) {
      final account = accounts[index];
      final isActive = account.isActive;
      final needsReauth = account.status == AccountStatus.needsReauth;

      return SizedBox(
        width: 300,
        child: AccountCard(
          account: account,
          theme: widget.theme,
          onTap: () => _switchToUser(account.id),
          onRemove: () => _showRemoveAccountDialog(account.id, account.name),
          onReauth: () => widget.provider.authenticate(),
        ),
      );
    },
    options: CarouselOptions(
      height: widget.height,
      viewportFraction: 0.3, // Adjust to show ~3 cards
      enableInfiniteScroll: false,
      padEnds: true,
      enlargeCenterPage: true,
      enlargeFactor: 0.2,
    ),
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

  Widget _buildAccountCard(CloudAccount account, bool isActive, bool needsReauth) {
  return AccountCard(
    account: account,
    theme: widget.theme,
    onTap: () => _switchToUser(account.id),
    onRemove: () => _showRemoveAccountDialog(account.id, account.name),
    onReauth: () => widget.provider.authenticate(),
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