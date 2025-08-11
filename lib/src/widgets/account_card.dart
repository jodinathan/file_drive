import 'package:flutter/material.dart';
import '../models/cloud_account.dart';
import '../models/account_status.dart';
import '../theme/app_constants.dart';

/// Widget para exibir informações de uma conta conectada
class AccountCard extends StatelessWidget {
  /// Conta a ser exibida
  final CloudAccount account;
  
  /// Se esta conta está selecionada
  final bool isSelected;
  
  /// Callback quando a conta é selecionada
  final VoidCallback onTap;
  
  /// Callback para ações do menu (reauth, remove)
  final Function(String action) onMenuAction;

  const AccountCard({
    super.key,
    required this.account,
    required this.isSelected,
    required this.onTap,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    const cardHeight = 80.0; // Altura fixa do card
    const photoSize = cardHeight; // Foto com altura igual ao container
    
    return Container(
      width: 280,
      height: cardHeight,
      decoration: BoxDecoration(
        color: isSelected 
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(photoSize / 2), // Radius circular igual à foto
          bottomLeft: Radius.circular(photoSize / 2), // Radius circular igual à foto
          topRight: Radius.circular(AppConstants.radiusL),
          bottomRight: Radius.circular(AppConstants.radiusL),
        ),
        border: Border.all(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(photoSize / 2),
            bottomLeft: Radius.circular(photoSize / 2),
            topRight: Radius.circular(AppConstants.radiusL),
            bottomRight: Radius.circular(AppConstants.radiusL),
          ),
          child: Row(
            children: [
              // Foto com altura igual ao container
              Container(
                width: photoSize,
                height: photoSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: photoSize / 2,
                  backgroundImage: account.photoUrl != null
                      ? NetworkImage(account.photoUrl!)
                      : null,
                  child: account.photoUrl == null
                      ? Text(
                          account.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
              ),
              
              // Coluna com nome e email com padding top
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppConstants.paddingS,
                    right: AppConstants.paddingXS,
                    top: AppConstants.paddingM, // Padding top conforme solicitado
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Nome
                      Text(
                        account.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      
                      // Email
                      Text(
                        account.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: AppConstants.spacingXS),
                      
                      // Status
                      if (account.status != AccountStatus.ok )
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: account.status == AccountStatus.ok 
                                  ? Colors.green 
                                  : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingXS),
                          Text(
                            account.status == AccountStatus.ok 
                                ? 'Conectado' 
                                : 'Erro',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: account.status == AccountStatus.ok 
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Menu de ações
              PopupMenuButton<String>(
                iconSize: AppConstants.iconXS,
                padding: const EdgeInsets.only(right: AppConstants.paddingS),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'reauth',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 16),
                        SizedBox(width: 8),
                        Text('Reautorizar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Remover'),
                      ],
                    ),
                  ),
                ],
                onSelected: onMenuAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}