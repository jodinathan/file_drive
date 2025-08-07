/// Configuration classes for FileDrive widget
library;

import 'package:flutter/material.dart';
import '../providers/base/cloud_provider.dart';

/// Main configuration for FileDrive widget
class FileDriveConfig {
  final List<CloudProvider> providers;
  final FileDriveTheme? theme;
  
  const FileDriveConfig({
    required this.providers,
    this.theme,
  });
  
  /// Create config with single provider
  factory FileDriveConfig.single(CloudProvider provider) {
    return FileDriveConfig(providers: [provider]);
  }
  
  /// Get provider by name
  CloudProvider? getProvider(String name) {
    try {
      return providers.firstWhere((p) => p.providerName == name);
    } catch (e) {
      return null;
    }
  }
  
  @override
  String toString() => 'FileDriveConfig(providers: ${providers.length})';
}

/// Theme configuration for FileDrive widget
class FileDriveTheme {
  final FileDriveColorScheme colorScheme;
  final TypographyTheme typography;
  final LayoutTheme layout;
  
  const FileDriveTheme({
    required this.colorScheme,
    required this.typography,
    this.layout = const LayoutTheme(),
  });
  
  /// Create default light theme
  factory FileDriveTheme.light() {
    return FileDriveTheme(
      colorScheme: const FileDriveColorScheme.light(),
      typography: TypographyTheme.defaultLight(),
      layout: const LayoutTheme(),
    );
  }

  /// Create default dark theme
  factory FileDriveTheme.dark() {
    return FileDriveTheme(
      colorScheme: const FileDriveColorScheme.dark(),
      typography: TypographyTheme.defaultDark(),
      layout: const LayoutTheme(),
    );
  }
}

/// Color scheme for the widget
class FileDriveColorScheme {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color error;
  final Color onPrimary;
  final Color onSecondary;
  final Color onBackground;
  final Color onSurface;
  final Color onError;
  
  const FileDriveColorScheme({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.error,
    required this.onPrimary,
    required this.onSecondary,
    required this.onBackground,
    required this.onSurface,
    required this.onError,
  });

  /// Light color scheme
  const FileDriveColorScheme.light()
      : primary = const Color(0xFF1976D2),
        secondary = const Color(0xFF03DAC6),
        background = const Color(0xFFFAFAFA),
        surface = const Color(0xFFFFFFFF),
        error = const Color(0xFFB00020),
        onPrimary = const Color(0xFFFFFFFF),
        onSecondary = const Color(0xFF000000),
        onBackground = const Color(0xFF000000),
        onSurface = const Color(0xFF000000),
        onError = const Color(0xFFFFFFFF);

  /// Dark color scheme
  const FileDriveColorScheme.dark()
      : primary = const Color(0xFF90CAF9),
        secondary = const Color(0xFF03DAC6),
        background = const Color(0xFF121212),
        surface = const Color(0xFF1E1E1E),
        error = const Color(0xFFCF6679),
        onPrimary = const Color(0xFF000000),
        onSecondary = const Color(0xFF000000),
        onBackground = const Color(0xFFFFFFFF),
        onSurface = const Color(0xFFFFFFFF),
        onError = const Color(0xFF000000);
}

/// Typography theme for text styles
class TypographyTheme {
  final TextStyle headline;
  final TextStyle title;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle button;
  
  const TypographyTheme({
    required this.headline,
    required this.title,
    required this.body,
    required this.caption,
    required this.button,
  });
  
  /// Default light typography
  factory TypographyTheme.defaultLight() {
    return const TypographyTheme(
      headline: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF000000),
      ),
      title: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF000000),
      ),
      body: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Color(0xFF000000),
      ),
      caption: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Color(0xFF666666),
      ),
      button: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1976D2),
      ),
    );
  }
  
  /// Default dark typography
  factory TypographyTheme.defaultDark() {
    return const TypographyTheme(
      headline: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFFFFF),
      ),
      title: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFFFFFFFF),
      ),
      body: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Color(0xFFFFFFFF),
      ),
      caption: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Color(0xFFBBBBBB),
      ),
      button: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF90CAF9),
      ),
    );
  }
}

/// Layout theme for spacing and dimensions
class LayoutTheme {
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double spacing;
  
  const LayoutTheme({
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = const EdgeInsets.all(8.0),
    this.spacing = 16.0,
  });
  
  /// Compact layout theme
  factory LayoutTheme.compact() {
    return const LayoutTheme(
      borderRadius: 4.0,
      padding: EdgeInsets.all(8.0),
      margin: EdgeInsets.all(4.0),
      spacing: 8.0,
    );
  }
  
  /// Spacious layout theme
  factory LayoutTheme.spacious() {
    return const LayoutTheme(
      borderRadius: 12.0,
      padding: EdgeInsets.all(24.0),
      margin: EdgeInsets.all(16.0),
      spacing: 24.0,
    );
  }
}
