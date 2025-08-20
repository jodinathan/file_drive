import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_constants.dart';
import '../l10n/generated/app_localizations.dart';

/// Widget that provides search functionality with debounce
class SearchBarWidget extends StatefulWidget {
  /// Callback when search query changes after debounce
  final Function(String query)? onSearch;
  
  /// Callback when search is cleared
  final VoidCallback? onClear;
  
  /// Whether search is currently loading
  final bool isLoading;
  
  /// Debounce duration for search queries
  final Duration debounce;
  
  /// Initial search query
  final String? initialQuery;
  
  /// Placeholder text for the search field
  final String? placeholder;
  
  /// Whether the search field is enabled
  final bool enabled;

  const SearchBarWidget({
    super.key,
    this.onSearch,
    this.onClear,
    this.isLoading = false,
    this.debounce = const Duration(milliseconds: 400),
    this.initialQuery,
    this.placeholder,
    this.enabled = true,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounceTimer;
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();
    _lastSearchQuery = widget.initialQuery ?? '';
    
    // Listen to text changes for debounce
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text.trim();
    
    // Cancel existing timer
    _debounceTimer?.cancel();
    
    // If query is different from last search, start debounce timer
    if (query != _lastSearchQuery) {
      _debounceTimer = Timer(widget.debounce, () {
        _performSearch(query);
      });
    }
  }

  void _performSearch(String query) {
    if (query != _lastSearchQuery) {
      _lastSearchQuery = query;
      widget.onSearch?.call(query);
    }
  }

  void _clearSearch() {
    _controller.clear();
    _focusNode.unfocus();
    _lastSearchQuery = '';
    _debounceTimer?.cancel();
    widget.onClear?.call();
    widget.onSearch?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      constraints: const BoxConstraints(
        minWidth: 200,
        maxWidth: 400,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(
          color: _focusNode.hasFocus
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Search icon
          Padding(
            padding: const EdgeInsets.only(left: AppConstants.paddingM),
            child: Icon(
              Icons.search,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          
          // Search field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              decoration: InputDecoration(
                hintText: widget.placeholder ?? _getDefaultPlaceholder(context),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingM,
                  vertical: AppConstants.paddingS,
                ),
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              textInputAction: TextInputAction.search,
              onSubmitted: (query) {
                _debounceTimer?.cancel();
                _performSearch(query.trim());
              },
            ),
          ),
          
          // Loading indicator or clear button
          Padding(
            padding: const EdgeInsets.only(right: AppConstants.paddingS),
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : _controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        tooltip: _getClearTooltip(context),
                      )
                    : const SizedBox(width: 24),
          ),
        ],
      ),
    );
  }

  String _getDefaultPlaceholder(BuildContext context) {
    try {
      return AppLocalizations.of(context).searchFiles;
    } catch (e) {
      return 'Search files...';
    }
  }

  String _getClearTooltip(BuildContext context) {
    try {
      return AppLocalizations.of(context).clearSearch;
    } catch (e) {
      return 'Clear search';
    }
  }
}