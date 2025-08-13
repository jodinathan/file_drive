import 'package:flutter/material.dart';
import '../models/navigation_history.dart';
import '../theme/app_constants.dart';
import '../l10n/generated/app_localizations.dart';

/// Widget for navigation bar with home, back, forward buttons and breadcrumb
class NavigationBarWidget extends StatelessWidget {
  /// Current navigation history
  final NavigationHistory navigationHistory;
  
  /// Callback when user wants to go home (root)
  final VoidCallback? onGoHome;
  
  /// Callback when user wants to go back
  final VoidCallback? onGoBack;
  
  /// Callback when user wants to go forward
  final VoidCallback? onGoForward;
  
  /// Callback when user clicks on a breadcrumb item
  final void Function(int index)? onBreadcrumbTap;
  
  /// Callback when user wants to create a new folder
  final VoidCallback? onCreateFolder;
  
  /// Callback when user wants to upload files
  final VoidCallback? onUpload;
  
  /// Whether to show the upload button
  final bool showUploadButton;
  
  /// Whether to show the create folder button
  final bool showCreateFolderButton;
  
  /// Maximum breadcrumb items to show before truncating
  final int maxBreadcrumbItems;

  const NavigationBarWidget({
    super.key,
    required this.navigationHistory,
    this.onGoHome,
    this.onGoBack,
    this.onGoForward,
    this.onBreadcrumbTap,
    this.onCreateFolder,
    this.onUpload,
    this.showUploadButton = true,
    this.showCreateFolderButton = true,
    this.maxBreadcrumbItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Top row with navigation buttons and actions
          Row(
            children: [
              _buildNavigationButtons(context),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(child: _buildBreadcrumb(context)),
              const SizedBox(width: AppConstants.spacingM),
              _buildActionButtons(context),
            ],
          ),
          
          // Breadcrumb row (mobile-friendly)
          if (_shouldShowSeparateBreadcrumb(context)) ...[
            const SizedBox(height: AppConstants.spacingS),
            _buildMobileBreadcrumb(context),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Home button
        IconButton(
          onPressed: onGoHome,
          icon: const Icon(Icons.home),
          tooltip: 'Ir para a raiz',
          style: IconButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        
        // Back button
        IconButton(
          onPressed: navigationHistory.canGoBack ? onGoBack : null,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          style: IconButton.styleFrom(
            foregroundColor: navigationHistory.canGoBack 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
          ),
        ),
        
        // Forward button
        IconButton(
          onPressed: navigationHistory.canGoForward ? onGoForward : null,
          icon: const Icon(Icons.arrow_forward),
          tooltip: 'Avançar',
          style: IconButton.styleFrom(
            foregroundColor: navigationHistory.canGoForward 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    if (_shouldShowSeparateBreadcrumb(context)) {
      // Show simplified breadcrumb on small screens
      final current = navigationHistory.current;
      if (current == null) return const SizedBox.shrink();
      
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingS,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        child: Text(
          current.folderName,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    
    return _buildFullBreadcrumb(context);
  }

  Widget _buildFullBreadcrumb(BuildContext context) {
    final history = navigationHistory.entries;
    if (history.isEmpty) return const SizedBox.shrink();

    final currentIndex = navigationHistory.length > 0 
        ? navigationHistory.length - 1 
        : -1;
    final visibleItems = _getVisibleBreadcrumbItems(history, currentIndex);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildBreadcrumbItems(context, visibleItems),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBreadcrumb(BuildContext context) {
    final history = navigationHistory.entries;
    if (history.isEmpty) return const SizedBox.shrink();

    final currentIndex = navigationHistory.length > 0 
        ? navigationHistory.length - 1 
        : -1;
    final visibleItems = _getVisibleBreadcrumbItems(history, currentIndex);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _buildBreadcrumbItems(context, visibleItems),
        ),
      ),
    );
  }

  List<Widget> _buildBreadcrumbItems(
    BuildContext context, 
    List<BreadcrumbItem> items,
  ) {
    final widgets = <Widget>[];
    
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;
      
      // Add breadcrumb item
      widgets.add(
        GestureDetector(
          onTap: item.isClickable && onBreadcrumbTap != null
              ? () => onBreadcrumbTap!(item.historyIndex)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: item.isClickable ? BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
              color: Colors.transparent,
            ) : null,
            child: Text(
              item.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isLast 
                    ? Theme.of(context).colorScheme.onSurface
                    : item.isClickable
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
                decoration: item.isClickable && !isLast 
                    ? TextDecoration.underline
                    : null,
              ),
            ),
          ),
        ),
      );
      
      // Add separator (except for last item)
      if (!isLast) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
    }
    
    return widgets;
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Create folder button
        if (showCreateFolderButton)
          IconButton(
            onPressed: onCreateFolder,
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'Nova pasta',
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        
        // Upload button
        if (showUploadButton)
          FilledButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload, size: 18),
            label: Text(_getUploadText(context)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingM,
                vertical: AppConstants.paddingS,
              ),
            ),
          ),
      ],
    );
  }

  List<BreadcrumbItem> _getVisibleBreadcrumbItems(
    List<NavigationEntry> history,
    int currentIndex,
  ) {
    if (history.isEmpty) return [];
    
    final items = <BreadcrumbItem>[];
    
    // If we have too many items, show truncation
    if (history.length > maxBreadcrumbItems) {
      // Always show root
      items.add(BreadcrumbItem(
        label: history.first.folderName,
        historyIndex: 0,
        isClickable: true,
      ));
      
      // Add ellipsis if needed
      if (currentIndex > maxBreadcrumbItems - 2) {
        items.add(BreadcrumbItem(
          label: '...',
          historyIndex: -1,
          isClickable: false,
        ));
        
        // Show last few items
        final startIndex = currentIndex - (maxBreadcrumbItems - 3);
        for (int i = startIndex; i <= currentIndex; i++) {
          if (i > 0 && i < history.length) {
            items.add(BreadcrumbItem(
              label: history[i].folderName,
              historyIndex: i,
              isClickable: i != currentIndex,
            ));
          }
        }
      } else {
        // Show items from beginning up to current
        for (int i = 1; i <= currentIndex && i < maxBreadcrumbItems; i++) {
          items.add(BreadcrumbItem(
            label: history[i].folderName,
            historyIndex: i,
            isClickable: i != currentIndex,
          ));
        }
      }
    } else {
      // Show all items
      for (int i = 0; i < history.length; i++) {
        items.add(BreadcrumbItem(
          label: history[i].folderName,
          historyIndex: i,
          isClickable: i != currentIndex,
        ));
      }
    }
    
    return items;
  }

  bool _shouldShowSeparateBreadcrumb(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  String _getUploadText(BuildContext context) {
    try {
      return AppLocalizations.of(context)?.upload ?? 'Upload';
    } catch (e) {
      return 'Upload';
    }
  }
}

/// Represents an item in the breadcrumb navigation
class BreadcrumbItem {
  final String label;
  final int historyIndex;
  final bool isClickable;

  const BreadcrumbItem({
    required this.label,
    required this.historyIndex,
    required this.isClickable,
  });
}