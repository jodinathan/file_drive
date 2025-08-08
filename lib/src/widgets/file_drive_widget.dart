/// Main FileDrive widget implementation
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';
import '../providers/base/oauth_cloud_provider.dart';
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
    return Material(
      color: theme.colorScheme.background,
      child: Row(
        children: [
          // Coluna 1: Lista de Provedores
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: theme.colorScheme.onBackground.withOpacity(0.1),
                ),
              ),
            ),
            child: _buildProviderList(theme),
          ),
          // Coluna 2: Conteúdo dividido em duas linhas
          Expanded(
            child: Column(
              children: [
                // Linha superior - Carrossel de contas + botão adicionar
                Container(
                  height: 64,
                  padding: EdgeInsets.all(theme.layout.spacing / 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.onBackground.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Material(
                    color: theme.colorScheme.surface,
                    child: _buildAccountCarousel(theme),
                  ),
                ),
                // Linha inferior - Conteúdo (resto do espaço)
                Expanded(
                  child: Material(
                    color: theme.colorScheme.background,
                    child: _buildContentArea(theme),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContentArea(FileDriveTheme theme) {
    if (_selectedProvider == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Selecione um provedor',
              style: theme.typography.title.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }
    
    return ProviderContent(
      provider: _selectedProvider,
      theme: theme,
      onFilesSelected: widget.onFilesSelected,
    );
  }
  
  Widget _buildCompactLayout(FileDriveTheme theme) {
    // For compact layout, use tabs or drawer
    return Material(
      color: theme.colorScheme.background,
      child: DefaultTabController(
        length: widget.config.providers.length,
        child: Column(
          children: [
            // Tab bar for providers
            Material(
              color: theme.colorScheme.surface,
              child: Container(
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
      colorScheme: ColorScheme.fromSeed(
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
  
  Widget _buildProviderList(FileDriveTheme theme) {
    return ListView.builder(
      itemCount: widget.config.providers.length,
      itemBuilder: (context, index) {
        final provider = widget.config.providers[index];
        final isSelected = provider == _selectedProvider;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleProviderSelection(provider),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? provider.providerColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected 
                      ? Border.all(color: provider.providerColor)
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: provider.providerColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        provider.providerName,
                        style: theme.typography.body.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected 
                              ? provider.providerColor
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildAccountCarousel(FileDriveTheme theme) {
    return Row(
      children: [
        // Carrossel de contas
        Expanded(
          child: _selectedProvider != null && _selectedProvider is OAuthCloudProvider
              ? FutureBuilder<Map<String, Map<String, dynamic>>>(
                  future: (_selectedProvider as OAuthCloudProvider).getAllUsers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          'Nenhuma conta conectada',
                          style: theme.typography.caption.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      );
                    }
                    
                    final users = snapshot.data!;
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final entry = users.entries.elementAt(index);
                        final userId = entry.key;
                        final userInfo = entry.value;
                        final isActive = userId == (_selectedProvider as OAuthCloudProvider).activeUserId;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildUserAccountCard(userId, userInfo, isActive, theme),
                        );
                      },
                    );
                  },
                )
              : Center(
                  child: Text(
                    'Selecione um provedor OAuth',
                    style: theme.typography.caption.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
        ),
        // Botão adicionar conta
        const SizedBox(width: 12),
        _buildAddAccountButton(theme),
      ],
    );
  }
  
  Widget _buildUserAccountCard(String userId, Map<String, dynamic> userInfo, bool isActive, FileDriveTheme theme) {
    final name = userInfo['name'] ?? userInfo['email'] ?? 'Usuário';
    final email = userInfo['email'] ?? '';
    final picture = userInfo['picture'];
    final needsReauth = (userInfo['needsReauth'] == true) || (userInfo['hasPermissionIssues'] == true);
    
    return InkWell(
      onTap: isActive ? null : () => _switchToUser(userId),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        height: 48,
        decoration: BoxDecoration(
          color: isActive 
              ? _selectedProvider!.providerColor.withOpacity(0.1)
              : theme.colorScheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive 
                ? _selectedProvider!.providerColor
                : theme.colorScheme.onBackground.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            // Avatar com foto
            Stack(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _selectedProvider!.providerColor,
                  backgroundImage: picture != null ? NetworkImage(picture) : null,
                  child: picture == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                if (needsReauth)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.warning,
                        size: 6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (isActive && !needsReauth)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 6,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            // Info da conta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: theme.typography.body.copyWith(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      color: needsReauth 
                          ? Colors.orange
                          : (isActive 
                              ? _selectedProvider!.providerColor
                              : theme.colorScheme.onSurface),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: theme.typography.caption.copyWith(
                        fontSize: 9,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
  
  void _switchToUser(String userId) async {
    if (_selectedProvider != null && _selectedProvider is OAuthCloudProvider) {
      final success = await (_selectedProvider as OAuthCloudProvider).switchToUser(userId);
      if (success) {
        setState(() {});
      }
    }
  }
  
  Widget _buildAddAccountButton(FileDriveTheme theme) {
    return InkWell(
      onTap: _handleAddAccount,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 60,
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Icon(
          Icons.add,
          color: theme.colorScheme.primary,
          size: 24,
        ),
      ),
    );
  }
  
  void _handleAddAccount() {
    // TODO: Implementar lógica para adicionar nova conta
    // Pode abrir um dialog, navegar para tela de configuração, etc.
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