import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/custom_provider.dart';
import '../providers/base_cloud_provider.dart';

/// Widget for displaying provider logos with fallback to icons
class ProviderLogo extends StatelessWidget {
  /// Provider type identifier
  final String providerType;
  
  /// Size of the logo/icon
  final double size;
  
  /// Color for fallback icon
  final Color? color;
  
  /// Optional custom widget to display (for CustomProvider)
  final Widget? customWidget;

  const ProviderLogo({
    super.key,
    required this.providerType,
    this.size = 24.0,
    this.color,
    this.customWidget,
  });

  @override
  Widget build(BuildContext context) {
    // If custom widget is provided, use it with proper sizing
    if (customWidget != null) {
      return SizedBox(
        width: size,
        height: size,
        child: customWidget,
      );
    }
    
    // Load SVG from package assets
    return _buildProviderLogo();
  }

  Widget _buildProviderLogo() {
    // For local_server, always use icon instead of SVG
    if (providerType == 'local_server') {
      return _buildProviderIcon();
    }
    
    // Try to load provider logo from package assets
    final assetPath = 'packages/file_cloud/assets/logos/$providerType.svg';
    
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      placeholderBuilder: (context) => _buildProviderIcon(),
    );
  }

  Widget _buildProviderIcon() {
    return Icon(
      _getProviderIcon(providerType),
      size: size,
      color: color ?? _getProviderColor(providerType),
    );
  }

  /// Get fallback icon for provider
  IconData _getProviderIcon(String providerType) {
    switch (providerType) {
      case 'google_drive':
        return Icons.drive_eta;
      case 'dropbox':
        return Icons.cloud;
      case 'onedrive':
        return Icons.cloud_outlined;
      case 'custom':
        return Icons.storage;
      case 'local_server':
        return Icons.dns;
      default:
        return Icons.storage;
    }
  }

  /// Get brand color for provider
  Color _getProviderColor(String providerType) {
    switch (providerType) {
      case 'google_drive':
        return const Color(0xFF4285F4); // Google Blue
      case 'dropbox':
        return const Color(0xFF0061FF); // Dropbox Blue
      case 'onedrive':
        return const Color(0xFF0078D4); // Microsoft Blue
      case 'custom':
        return const Color(0xFF6B7280); // Gray
      case 'local_server':
        return const Color(0xFF10B981); // Emerald Green
      default:
        return Colors.grey;
    }
  }
}

/// Helper for getting provider display name
class ProviderHelper {
  /// Reference to the FileCloudWidget's providers map
  static Map<String, dynamic>? _providersMap;
  
  /// Set the providers map from FileCloudWidget
  static void setProvidersMap(Map<String, dynamic> providers) {
    _providersMap = providers;
  }
  
  /// Get custom logo widget for a provider
  static Widget? getCustomLogoWidget(String providerType) {
    if (_providersMap == null) return null;
    
    final provider = _providersMap![providerType];
    if (provider is CustomProvider) {
      return provider.config.logoWidget;
    }
    return null;
  }
  
  /// Check if provider should show account management features
  static bool getShowAccountManagement(String providerType) {
    if (_providersMap == null) return true; // Default to true for standard providers
    
    final provider = _providersMap![providerType];
    if (provider is CustomProvider) {
      return provider.config.showAccountManagement;
    }
    
    // Check if provider requires account management
    if (provider is BaseCloudProvider) {
      return provider.requiresAccountManagement;
    }
    
    return true; // Default to true for all other providers
  }

  static String getDisplayName(String providerType) {
    switch (providerType) {
      case 'google_drive':
        return 'Google Drive';
      case 'dropbox':
        return 'Dropbox';
      case 'onedrive':
        return 'OneDrive';
      case 'custom':
        return 'Enterprise Storage';
      case 'local_server':
        return 'Local Server';
      default:
        return providerType;
    }
  }

  /// Check if provider is currently supported/configured
  static bool isProviderEnabled(String providerType) {
    switch (providerType) {
      case 'google_drive':
      case 'local_server':
        return true; // Google Drive and Local Server providers are implemented
      case 'custom':
      case 'dropbox':
      case 'onedrive':
        return false; // Not yet implemented
      default:
        return false;
    }
  }

  /// Get list of enabled providers only
  static List<String> getEnabledProviders() {
    return ['google_drive', 'local_server']; // Return actually implemented providers
  }
}