import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/navigation_history.dart';
import '../models/file_entry.dart';
import '../utils/app_logger.dart';
import '../l10n/generated/app_localizations.dart';

/// Manager for handling navigation history with back/forward support
class NavigationManager extends ChangeNotifier {
  final NavigationHistory _history = NavigationHistory();
  BuildContext? _context;
  
  /// Callback when navigation occurs
  final void Function(NavigationEntry?)? onNavigationChanged;
  
  NavigationManager({this.onNavigationChanged});
  
  /// Sets the build context for translations
  void setContext(BuildContext context) {
    _context = context;
  }
  
  /// Gets localized root folder name
  String get _rootFolderName {
    try {
      if (_context != null) {
        final localizations = Localizations.of<AppLocalizations>(_context!, AppLocalizations);
        return localizations?.rootFolder ?? 'Home';
      }
    } catch (e) {
      // If localization fails, fall back to default
      print('🔍 DEBUG: Localization failed, using default: $e');
    }
    return 'Home';
  }

  /// Gets the current navigation entry
  NavigationEntry? get current => _history.current;

  /// Whether there's a previous entry to go back to
  bool get canGoBack => _history.canGoBack;

  /// Whether there's a next entry to go forward to
  bool get canGoForward => _history.canGoForward;

  /// Gets the full navigation history
  NavigationHistory get history => _history;

  /// Gets the root entry
  NavigationEntry? get root => _history.root;

  /// Whether currently at root
  bool get isAtRoot => current?.isRoot ?? true;

  /// Gets the current folder ID
  String? get currentFolderId => current?.folderId;

  /// Gets the current folder name
  String get currentFolderName => current?.folderName ?? _rootFolderName;

  /// Navigates to a new folder
  void navigateToFolder({
    required String? folderId,
    required String folderName,
    required String providerType,
    required String accountId,
    Map<String, dynamic>? metadata,
  }) {
    AppLogger.info('Navigating to folder: $folderName ($folderId)', 
                   component: 'NavigationManager');

    NavigationEntry entry;
    
    if (folderId == null) {
      // Navigating to root
      entry = NavigationEntry.root(
        providerType: providerType,
        accountId: accountId,
        metadata: metadata ?? {},
      );
    } else {
      // Navigating to a subfolder
      final currentEntry = _history.current;
      if (currentEntry != null && 
          currentEntry.providerType == providerType &&
          currentEntry.accountId == accountId) {
        // Create child entry from current
        entry = currentEntry.createChild(
          folderId: folderId,
          folderName: folderName,
          metadata: metadata,
        );
      } else {
        // Create new entry (different provider/account)
        entry = NavigationEntry(
          folderId: folderId,
          folderName: folderName,
          pathComponents: [folderName],
          providerType: providerType,
          accountId: accountId,
          metadata: metadata ?? {},
        );
      }
    }

    _history.push(entry);
    notifyListeners();
    onNavigationChanged?.call(entry);
  }

  /// Goes back to the previous folder
  NavigationEntry? goBack() {
    AppLogger.info('Going back in navigation', component: 'NavigationManager');
    
    final entry = _history.goBack();
    if (entry != null) {
      notifyListeners();
      onNavigationChanged?.call(entry);
    }
    return entry;
  }

  /// Goes forward to the next folder
  NavigationEntry? goForward() {
    AppLogger.info('Going forward in navigation', component: 'NavigationManager');
    
    final entry = _history.goForward();
    if (entry != null) {
      notifyListeners();
      onNavigationChanged?.call(entry);
    }
    return entry;
  }

  /// Navigates to the root folder
  void goHome({
    required String providerType,
    required String accountId,
    Map<String, dynamic>? metadata,
  }) {
    AppLogger.info('Going to home/root - clearing history first', component: 'NavigationManager');
    print('🔍 DEBUG: NavigationManager.goHome() called');
    print('🔍 DEBUG: History before clear: ${_history.entries.length} entries');
    
    // Clear history first to reset breadcrumb
    clearHistory();
    print('🔍 DEBUG: History after clear: ${_history.entries.length} entries');
    
    navigateToFolder(
      folderId: null,
      folderName: _rootFolderName,
      providerType: providerType,
      accountId: accountId,
      metadata: metadata,
    );
    print('🔍 DEBUG: NavigationManager.goHome() completed');
  }

  /// Navigates to a specific entry in the history (for breadcrumb navigation)
  NavigationEntry? navigateToIndex(int index) {
    AppLogger.info('Navigating to history index: $index', component: 'NavigationManager');
    
    final entry = _history.goToIndex(index);
    if (entry != null) {
      notifyListeners();
      onNavigationChanged?.call(entry);
    }
    return entry;
  }

  /// Replaces the current entry without affecting navigation state
  void updateCurrent({
    String? folderName,
    Map<String, dynamic>? metadata,
  }) {
    final current = _history.current;
    if (current == null) return;

    AppLogger.debug('Updating current navigation entry', component: 'NavigationManager');

    final updatedEntry = current.copyWith(
      folderName: folderName ?? current.folderName,
      metadata: metadata ?? current.metadata,
    );

    _history.replaceCurrent(updatedEntry);
    notifyListeners();
  }

  /// Clears the navigation history
  void clearHistory() {
    AppLogger.info('Clearing navigation history', component: 'NavigationManager');
    print('🔍 DEBUG: NavigationManager.clearHistory() called');
    print('🔍 DEBUG: History entries before clear: ${_history.entries.length}');
    
    _history.clear();
    print('🔍 DEBUG: History entries after clear: ${_history.entries.length}');
    print('🔍 DEBUG: Current entry after clear: ${_history.current}');
    
    notifyListeners();
    onNavigationChanged?.call(null);
  }

  /// Resets navigation to a new provider/account
  void resetForProvider({
    required String providerType,
    required String accountId,
    Map<String, dynamic>? metadata,
  }) {
    AppLogger.info('Resetting navigation for provider: $providerType', 
                   component: 'NavigationManager');
    
    clearHistory();
    goHome(
      providerType: providerType,
      accountId: accountId,
      metadata: metadata,
    );
  }

  /// Gets breadcrumb items for UI display
  List<BreadcrumbItem> getBreadcrumbItems({int maxItems = 5}) {
    final entries = _history.entries;
    if (entries.isEmpty) return [];

    final items = <BreadcrumbItem>[];
    final currentIndex = entries.length - 1;

    // If we have too many items, show truncation
    if (entries.length > maxItems) {
      // Always show root
      items.add(BreadcrumbItem(
        label: entries.first.folderName,
        historyIndex: 0,
        isClickable: true,
      ));

      // Add ellipsis if needed
      if (currentIndex > maxItems - 2) {
        items.add(BreadcrumbItem(
          label: '...',
          historyIndex: -1,
          isClickable: false,
        ));

        // Show last few items
        final startIndex = currentIndex - (maxItems - 3);
        for (int i = startIndex; i <= currentIndex; i++) {
          if (i > 0 && i < entries.length) {
            items.add(BreadcrumbItem(
              label: entries[i].folderName,
              historyIndex: i,
              isClickable: i != currentIndex,
            ));
          }
        }
      } else {
        // Show items from beginning up to current
        for (int i = 1; i <= currentIndex && i < maxItems; i++) {
          items.add(BreadcrumbItem(
            label: entries[i].folderName,
            historyIndex: i,
            isClickable: i != currentIndex,
          ));
        }
      }
    } else {
      // Show all items
      for (int i = 0; i < entries.length; i++) {
        items.add(BreadcrumbItem(
          label: entries[i].folderName,
          historyIndex: i,
          isClickable: i != currentIndex,
        ));
      }
    }

    return items;
  }

  /// Gets navigation statistics for debugging
  NavigationStats getStats() {
    return NavigationStats(
      totalEntries: _history.length,
      currentIndex: _history.length > 0 ? _history.length - 1 : -1,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
      currentFolderId: currentFolderId,
      currentDepth: current?.depth ?? 0,
    );
  }

  /// Validates if navigation is possible to a specific folder
  bool canNavigateToFolder(FileEntry folder) {
    if (!folder.isFolder) return false;
    
    // Check if folder allows navigation (custom metadata check)
    final canEnter = folder.metadata['canEnter'];
    if (canEnter is bool && !canEnter) return false;
    
    return true;
  }

  /// Gets the path to current folder as a list of folder names
  List<String> getCurrentPath() {
    return current?.pathComponents ?? [];
  }

  /// Gets the full display path as a string
  String getCurrentDisplayPath() {
    return current?.displayPath ?? _rootFolderName;
  }

  @override
  String toString() {
    return 'NavigationManager(current: ${current?.folderName}, '
           'canBack: $canGoBack, canForward: $canGoForward, '
           'entries: ${_history.length})';
  }
}

/// Represents an item in breadcrumb navigation
class BreadcrumbItem {
  final String label;
  final int historyIndex;
  final bool isClickable;

  const BreadcrumbItem({
    required this.label,
    required this.historyIndex,
    required this.isClickable,
  });

  @override
  String toString() {
    return 'BreadcrumbItem(label: $label, index: $historyIndex, clickable: $isClickable)';
  }
}

/// Navigation statistics for debugging and monitoring
class NavigationStats {
  final int totalEntries;
  final int currentIndex;
  final bool canGoBack;
  final bool canGoForward;
  final String? currentFolderId;
  final int currentDepth;

  const NavigationStats({
    required this.totalEntries,
    required this.currentIndex,
    required this.canGoBack,
    required this.canGoForward,
    required this.currentFolderId,
    required this.currentDepth,
  });

  @override
  String toString() {
    return 'NavigationStats(entries: $totalEntries, index: $currentIndex, '
           'depth: $currentDepth, back: $canGoBack, forward: $canGoForward)';
  }
}