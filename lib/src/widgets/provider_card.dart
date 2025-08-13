import 'package:flutter/material.dart';
import '../models/cloud_account.dart';
import '../theme/app_constants.dart';
import 'provider_logo.dart';

/// Widget para exibir informações de um provedor de nuvem
class ProviderCard extends StatelessWidget {
  /// Tipo do provedor (google_drive, dropbox, etc.)
  final String providerType;
  
  /// Se este provedor está selecionado
  final bool isSelected;
  
  /// Lista de contas para este provedor
  final List<CloudAccount> accounts;
  
  /// Callback quando o provedor é selecionado
  final VoidCallback onTap;
  
  /// Widget customizável para o logo (para CustomProvider)
  final Widget? customLogoWidget;

  const ProviderCard({
    super.key,
    required this.providerType,
    required this.isSelected,
    required this.accounts,
    required this.onTap,
    this.customLogoWidget,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = ProviderHelper.getDisplayName(providerType);
    
    return Container(
      decoration: BoxDecoration(
        color: isSelected 
            ? Theme.of(context).colorScheme.primaryContainer 
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo e nome com melhor espaçamento
                Row(
                  children: [
                    ProviderLogo(
                      providerType: providerType,
                      size: AppConstants.iconL - 4, // 28px
                      customWidget: customLogoWidget,
                    ),
                    const SizedBox(width: AppConstants.spacingS + 4), // 12px
                    Expanded(
                      child: Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected 
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppConstants.spacingS),
                
                // Contador de contas com melhor visual
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingS, 
                    vertical: AppConstants.paddingXS,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppConstants.radiusS + 2), // 6px
                  ),
                  child: Text(
                    '${accounts.length} conta${accounts.length != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}