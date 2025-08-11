import 'package:flutter/material.dart';
import 'app_constants.dart';

/// Theme configuration for the File Cloud widget
class AppTheme {
  /// Gets the Material 3 theme for the File Cloud widget
  static ThemeData getTheme({
    Brightness brightness = Brightness.light,
    ColorScheme? colorScheme,
  }) {
    final baseColorScheme = colorScheme ?? _getDefaultColorScheme(brightness);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: baseColorScheme,
      
      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: baseColorScheme.surface,
        foregroundColor: baseColorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          color: baseColorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
        ),
        margin: const EdgeInsets.all(AppConstants.marginS),
      ),
      
      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingM,
          vertical: AppConstants.paddingS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
        ),
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingL,
            vertical: AppConstants.paddingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          minimumSize: const Size(0, AppConstants.minTouchTarget),
        ),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingL,
            vertical: AppConstants.paddingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          minimumSize: const Size(0, AppConstants.minTouchTarget),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingL,
            vertical: AppConstants.paddingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          minimumSize: const Size(0, AppConstants.minTouchTarget),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingM,
            vertical: AppConstants.paddingS,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          minimumSize: const Size(0, AppConstants.minTouchTarget),
        ),
      ),
      
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppConstants.minTouchTarget, AppConstants.minTouchTarget),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseColorScheme.surfaceVariant.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(
            color: baseColorScheme.outline.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(
            color: baseColorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(
            color: baseColorScheme.error,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingM,
          vertical: AppConstants.paddingM,
        ),
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingM,
          vertical: AppConstants.paddingS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        ),
      ),
      
      // Dialog Theme
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
        ),
        titleTextStyle: TextStyle(
          color: baseColorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: baseColorScheme.primary,
        circularTrackColor: baseColorScheme.surfaceVariant,
        linearTrackColor: baseColorScheme.surfaceVariant,
      ),
      
      // Divider Theme
      dividerTheme: DividerThemeData(
        color: baseColorScheme.outline.withOpacity(0.2),
        thickness: 1,
        space: 1,
      ),
      
      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: baseColorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        textStyle: TextStyle(
          color: baseColorScheme.onInverseSurface,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingM,
          vertical: AppConstants.paddingS,
        ),
      ),
      
      // Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: baseColorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: baseColorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// Gets the default color scheme for the specified brightness
  static ColorScheme _getDefaultColorScheme(Brightness brightness) {
    return brightness == Brightness.light 
        ? _lightColorScheme 
        : _darkColorScheme;
  }
  
  /// Light theme color scheme
  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1976D2),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFBBDEFB),
    onPrimaryContainer: Color(0xFF0D47A1),
    secondary: Color(0xFF757575),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE0E0E0),
    onSecondaryContainer: Color(0xFF424242),
    tertiary: Color(0xFF4CAF50),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFC8E6C9),
    onTertiaryContainer: Color(0xFF1B5E20),
    error: Color(0xFFD32F2F),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFCDD2),
    onErrorContainer: Color(0xFFB71C1C),
    background: Color(0xFFFAFAFA),
    onBackground: Color(0xFF212121),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF212121),
    surfaceVariant: Color(0xFFF5F5F5),
    onSurfaceVariant: Color(0xFF616161),
    outline: Color(0xFFBDBDBD),
    outlineVariant: Color(0xFFE0E0E0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF303030),
    onInverseSurface: Color(0xFFFAFAFA),
    inversePrimary: Color(0xFF90CAF9),
    surfaceTint: Color(0xFF1976D2),
  );
  
  /// Dark theme color scheme
  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF90CAF9),
    onPrimary: Color(0xFF0D47A1),
    primaryContainer: Color(0xFF1565C0),
    onPrimaryContainer: Color(0xFFE3F2FD),
    secondary: Color(0xFFBDBDBD),
    onSecondary: Color(0xFF424242),
    secondaryContainer: Color(0xFF616161),
    onSecondaryContainer: Color(0xFFE0E0E0),
    tertiary: Color(0xFF81C784),
    onTertiary: Color(0xFF1B5E20),
    tertiaryContainer: Color(0xFF388E3C),
    onTertiaryContainer: Color(0xFFE8F5E8),
    error: Color(0xFFEF5350),
    onError: Color(0xFFB71C1C),
    errorContainer: Color(0xFFC62828),
    onErrorContainer: Color(0xFFFFEBEE),
    background: Color(0xFF121212),
    onBackground: Color(0xFFE0E0E0),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFE0E0E0),
    surfaceVariant: Color(0xFF2C2C2C),
    onSurfaceVariant: Color(0xFFBDBDBD),
    outline: Color(0xFF757575),
    outlineVariant: Color(0xFF424242),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE0E0E0),
    onInverseSurface: Color(0xFF1E1E1E),
    inversePrimary: Color(0xFF1976D2),
    surfaceTint: Color(0xFF90CAF9),
  );
  
  /// Gets error color for different account statuses
  static Color getStatusColor(ColorScheme colorScheme, String status) {
    switch (status.toLowerCase()) {
      case 'ok':
        return colorScheme.tertiary;
      case 'missing_scopes':
        return colorScheme.primary;
      case 'revoked':
        return colorScheme.error;
      case 'error':
        return colorScheme.error;
      default:
        return colorScheme.outline;
    }
  }
  
  /// Gets semantic colors for file types
  static Color getFileTypeColor(ColorScheme colorScheme, String? mimeType) {
    if (mimeType == null) return colorScheme.outline;
    
    if (AppConstants.imageMimeTypes.contains(mimeType)) {
      return colorScheme.tertiary;
    } else if (AppConstants.documentMimeTypes.contains(mimeType)) {
      return colorScheme.primary;
    } else if (AppConstants.videoMimeTypes.contains(mimeType)) {
      return colorScheme.secondary;
    } else if (AppConstants.audioMimeTypes.contains(mimeType)) {
      return const Color(0xFFFF9800); // Orange for audio
    }
    
    return colorScheme.outline;
  }
}