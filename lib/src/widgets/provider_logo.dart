import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../enums/cloud_provider_type.dart';
import '../providers/custom_provider.dart';
import '../providers/base_cloud_provider.dart';

/// Widget for displaying provider logos with fallback to icons
class ProviderLogo extends StatelessWidget {
  /// Provider type identifier
  final CloudProviderType providerType;
  
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
    if (providerType == CloudProviderType.localServer) {
      return _buildProviderIcon();
    }
    
    // Try to load provider logo from package assets
    final assetPath = 'packages/file_cloud/assets/logos/${providerType.name}.svg';
    
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
  IconData _getProviderIcon(CloudProviderType providerType) {
    switch (providerType) {
      case CloudProviderType.googleDrive:
        return Icons.drive_eta;
      case CloudProviderType.dropbox:
        return Icons.cloud;
      case CloudProviderType.oneDrive:
        return Icons.cloud_outlined;
      case CloudProviderType.custom:
        return Icons.storage;
      case CloudProviderType.localServer:
        return Icons.dns;
    }
  }

  /// Get brand color for provider
  Color _getProviderColor(CloudProviderType providerType) {
    switch (providerType) {
      case CloudProviderType.googleDrive:
        return const Color(0xFF4285F4); // Google Blue
      case CloudProviderType.dropbox:
        return const Color(0xFF0061FF); // Dropbox Blue
      case CloudProviderType.oneDrive:
        return const Color(0xFF0078D4); // Microsoft Blue
      case CloudProviderType.custom:
        return const Color(0xFF6B7280); // Gray
      case CloudProviderType.localServer:
        return const Color(0xFF10B981); // Emerald Green
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
  static Widget? getCustomLogoWidget(CloudProviderType providerType) {
    if (_providersMap == null) return null;
    
    final provider = _providersMap![providerType.name];
    if (provider is CustomProvider) {
      return provider.config.logoWidget;
    }
    return null;
  }
  
  /// Check if provider should show account management features
  static bool getShowAccountManagement(CloudProviderType providerType) {
    if (_providersMap == null) return true; // Default to true for standard providers
    
    final provider = _providersMap![providerType.name];
    if (provider is CustomProvider) {
      return provider.config.showAccountManagement;
    }
    
    // Check if provider requires account management
    if (provider is BaseCloudProvider) {
      return provider.requiresAccountManagement;
    }
    
    return true; // Default to true for all other providers
  }

  static String getDisplayName(CloudProviderType providerType) {
    return providerType.displayName;
  }

  /// Check if provider is currently supported/configured
  static bool isProviderEnabled(CloudProviderType providerType) {
    switch (providerType) {
      case CloudProviderType.googleDrive:
      case CloudProviderType.localServer:
        return true; // Google Drive and Local Server providers are implemented
      case CloudProviderType.custom:
      case CloudProviderType.dropbox:
      case CloudProviderType.oneDrive:
        return false; // Not yet implemented
    }
  }

  /// Get list of enabled providers only
  static List<CloudProviderType> getEnabledProviders() {
    return [CloudProviderType.googleDrive, CloudProviderType.localServer]; // Return actually implemented providers
  }
}