/// Main FileDrive widget implementation
library;

import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart' hide ColorScheme;
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';
import 'provider_sidebar.dart';
import 'provider_content.dart';

/// Main FileDrive widget
class FileDriveWidget extends StatefulWidget {
  final FileDriveConfig config;
  final Function(CloudProvider)? onProviderSelected;
  final Function(List<String>)? onFilesSelected;
  
  const FileDriveWidget({
    Key? key,
    required this.config,
    this.onProviderSelected,
    this.onFilesSelected,
  }) : super(key: key);
  
  @override
  State<FileDriveWidget> createState() => _FileDriveWidgetState();
}

class _FileDriveWidgetState extends State<FileDriveWidget> {
  CloudProvider? _selectedProvider;
  
  @override
  void initState() {
    super.initState();
    // Select first provider by default if available
    if (widget.config.providers.isNotEmpty) {
      _selectedProvider = widget.config.providers.first;
    }
  }
  
  @override
  void dispose() {
    // Dispose all providers
    for (final provider in widget.config.providers) {
      provider.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = widget.config.theme ?? FileDriveTheme.light();
    
    return Theme(
      data: _buildThemeData(theme),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.background,
          borderRadius: BorderRadius.circular(theme.layout.borderRadius),
          border: Border.all(
            color: theme.colorScheme.onBackground.withOpacity(0.1),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.layout.borderRadius),
          child: _buildLayout(theme),
        ),
      ),
    );
  }
  
  Widget _buildLayout(FileDriveTheme theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;
        
        if (isCompact) {
          return _buildCompactLayout(theme);
        } else {
          return _buildWideLayout(theme);
        }
      },
    );
  }
  
  Widget _buildWideLayout(FileDriveTheme theme) {
    return Row(
      children: [
        // Sidebar - 30% width, min 250px, max 400px
        Container(
          width: 300,
          constraints: const BoxConstraints(
            minWidth: 250,
            maxWidth: 400,
          ),
          child: ProviderSidebar(
            providers: widget.config.providers,
            selectedProvider: _selectedProvider,
            onProviderSelected: _handleProviderSelection,
            theme: theme,
          ),
        ),
        // Divider
        Container(
          width: 1,
          color: theme.colorScheme.onBackground.withOpacity(0.1),
        ),
        // Content - remaining width
        Expanded(
          child: ProviderContent(
            provider: _selectedProvider,
            theme: theme,
            onFilesSelected: widget.onFilesSelected,
          ),
        ),
      ],
    );
  }
  
  Widget _buildCompactLayout(FileDriveTheme theme) {
    // For compact layout, use tabs or drawer
    return DefaultTabController(
      length: widget.config.providers.length,
      child: Column(
        children: [
          // Tab bar for providers
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.onBackground.withOpacity(0.1),
                ),
              ),
            ),
            child: TabBar(
              isScrollable: true,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onBackground.withOpacity(0.6),
              indicatorColor: theme.colorScheme.primary,
              tabs: widget.config.providers.map((provider) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: provider.providerColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(provider.providerName),
                    ],
                  ),
                );
              }).toList(),
              onTap: (index) {
                _handleProviderSelection(widget.config.providers[index]);
              },
            ),
          ),
          // Content
          Expanded(
            child: ProviderContent(
              provider: _selectedProvider,
              theme: theme,
              onFilesSelected: widget.onFilesSelected,
            ),
          ),
        ],
      ),
    );
  }
  
  void _handleProviderSelection(CloudProvider provider) {
    setState(() {
      _selectedProvider = provider;
    });
    widget.onProviderSelected?.call(provider);
  }
  
  ThemeData _buildThemeData(FileDriveTheme theme) {
    return ThemeData(
      colorScheme: material.ColorScheme.fromSeed(
        seedColor: theme.colorScheme.primary,
        brightness: _getBrightness(theme.colorScheme.background),
      ),
      textTheme: TextTheme(
        headlineMedium: theme.typography.headline,
        titleMedium: theme.typography.title,
        bodyMedium: theme.typography.body,
        bodySmall: theme.typography.caption,
        labelLarge: theme.typography.button,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.layout.borderRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(color: theme.colorScheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.layout.borderRadius),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: theme.colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.layout.borderRadius),
        ),
      ),
    );
  }
  
  Brightness _getBrightness(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Brightness.light : Brightness.dark;
  }
}

/// Helper widget for responsive layout
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;
  
  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return mobile;
        } else if (constraints.maxWidth < 1200) {
          return tablet;
        } else {
          return desktop;
        }
      },
    );
  }
}

/// Breakpoints for responsive design
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1200;
  static const double desktop = 1200;
  
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobile;
  }
  
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }
  
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }
}
