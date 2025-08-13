/// Navigation history model for managing navigation stack with back/forward support
class NavigationHistory {
  final List<NavigationEntry> _history = [];
  int _currentIndex = -1;

  /// Gets the current navigation entry
  NavigationEntry? get current => 
      _currentIndex >= 0 && _currentIndex < _history.length 
          ? _history[_currentIndex] 
          : null;

  /// Whether there's a previous entry to go back to
  bool get canGoBack => _currentIndex > 0;

  /// Whether there's a next entry to go forward to  
  bool get canGoForward => _currentIndex < _history.length - 1;

  /// Number of entries in history
  int get length => _history.length;

  /// Gets the full history stack (read-only)
  List<NavigationEntry> get entries => List.unmodifiable(_history);

  /// Pushes a new entry to the history
  /// Clears any forward history when navigating to a new location
  void push(NavigationEntry entry) {
    // Remove any forward history
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    
    // Add new entry
    _history.add(entry);
    _currentIndex = _history.length - 1;
    
    // Limit history size to prevent memory issues
    _limitHistorySize();
  }

  /// Goes back to the previous entry
  /// Returns the previous entry or null if can't go back
  NavigationEntry? goBack() {
    if (!canGoBack) return null;
    
    _currentIndex--;
    return current;
  }

  /// Goes forward to the next entry
  /// Returns the next entry or null if can't go forward
  NavigationEntry? goForward() {
    if (!canGoForward) return null;
    
    _currentIndex++;
    return current;
  }

  /// Replaces the current entry without affecting navigation state
  void replaceCurrent(NavigationEntry entry) {
    if (_currentIndex >= 0 && _currentIndex < _history.length) {
      _history[_currentIndex] = entry;
    } else {
      push(entry);
    }
  }

  /// Clears all history
  void clear() {
    _history.clear();
    _currentIndex = -1;
  }

  /// Gets an entry at a specific index (for breadcrumb navigation)
  NavigationEntry? getAt(int index) {
    if (index >= 0 && index < _history.length) {
      return _history[index];
    }
    return null;
  }

  /// Navigates directly to a specific index in history
  NavigationEntry? goToIndex(int index) {
    if (index >= 0 && index < _history.length) {
      _currentIndex = index;
      return current;
    }
    return null;
  }

  /// Gets the root entry (first in history)
  NavigationEntry? get root => _history.isNotEmpty ? _history.first : null;

  /// Limits history size to prevent memory issues
  void _limitHistorySize() {
    const maxHistorySize = 100;
    if (_history.length > maxHistorySize) {
      final removeCount = _history.length - maxHistorySize;
      _history.removeRange(0, removeCount);
      _currentIndex = (_currentIndex - removeCount).clamp(0, _history.length - 1);
    }
  }

  @override
  String toString() {
    return 'NavigationHistory(current: $_currentIndex/${_history.length}, '
           'canGoBack: $canGoBack, canGoForward: $canGoForward)';
  }
}

/// Represents a single entry in navigation history
class NavigationEntry {
  /// Unique identifier for the folder (null for root)
  final String? folderId;
  
  /// Display name of the folder
  final String folderName;
  
  /// Full path components for breadcrumb display
  final List<String> pathComponents;
  
  /// Provider type this entry belongs to
  final String providerType;
  
  /// Account ID this entry belongs to
  final String accountId;
  
  /// Timestamp when this entry was created
  final DateTime timestamp;
  
  /// Additional metadata (file count, folder info, etc.)
  final Map<String, dynamic> metadata;

  NavigationEntry({
    this.folderId,
    required this.folderName,
    required this.pathComponents,
    required this.providerType,
    required this.accountId,
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a root entry
  factory NavigationEntry.root({
    required String providerType,
    required String accountId,
    Map<String, dynamic> metadata = const {},
  }) {
    return NavigationEntry(
      folderId: null,
      folderName: 'Home',
      pathComponents: [],
      providerType: providerType,
      accountId: accountId,
      metadata: metadata,
    );
  }

  /// Creates a child entry from a parent
  NavigationEntry createChild({
    required String folderId,
    required String folderName,
    Map<String, dynamic>? metadata,
  }) {
    return NavigationEntry(
      folderId: folderId,
      folderName: folderName,
      pathComponents: [...pathComponents, folderName],
      providerType: providerType,
      accountId: accountId,
      metadata: metadata ?? const {},
    );
  }

  /// Gets the display path as a string
  String get displayPath {
    if (pathComponents.isEmpty) return folderName;
    return pathComponents.join(' / ');
  }

  /// Whether this is the root entry
  bool get isRoot => folderId == null;

  /// Gets the depth in the folder hierarchy
  int get depth => pathComponents.length;

  /// Creates a copy with some fields replaced
  NavigationEntry copyWith({
    String? folderId,
    String? folderName,
    List<String>? pathComponents,
    String? providerType,
    String? accountId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return NavigationEntry(
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      pathComponents: pathComponents ?? this.pathComponents,
      providerType: providerType ?? this.providerType,
      accountId: accountId ?? this.accountId,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationEntry &&
        other.folderId == folderId &&
        other.providerType == providerType &&
        other.accountId == accountId;
  }

  @override
  int get hashCode {
    return Object.hash(folderId, providerType, accountId);
  }

  @override
  String toString() {
    return 'NavigationEntry(id: $folderId, name: $folderName, path: $displayPath)';
  }
}