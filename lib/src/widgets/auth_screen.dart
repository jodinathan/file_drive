/// Authentication screen widget
library;

import 'package:flutter/material.dart';
import '../models/file_drive_config.dart';
import '../providers/base/cloud_provider.dart';

/// Authentication screen for OAuth providers
class AuthenticationScreen extends StatefulWidget {
  final CloudProvider provider;
  final FileDriveTheme theme;
  
  const AuthenticationScreen({
    Key? key,
    required this.provider,
    required this.theme,
  }) : super(key: key);
  
  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isAuthenticating = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.theme.colorScheme.background,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildContent(),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildProviderLogo(),
            const SizedBox(height: 32),
            _buildWelcomeText(),
            const SizedBox(height: 24),
            _buildDescription(),
            const SizedBox(height: 40),
            _buildAuthButton(),
            const SizedBox(height: 24),
            _buildSecurityInfo(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProviderLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: widget.provider.providerColor.withOpacity(0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.provider.providerColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.cloud,
        size: 60,
        color: widget.provider.providerColor,
      ),
    );
  }
  
  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Conectar com',
          style: widget.theme.typography.title.copyWith(
            color: widget.theme.colorScheme.onBackground.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.provider.providerName,
          style: widget.theme.typography.headline.copyWith(
            color: widget.provider.providerColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(widget.theme.layout.borderRadius),
        border: Border.all(
          color: widget.theme.colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.security,
            color: widget.theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            'Autenticação Segura',
            style: widget.theme.typography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: widget.theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Faça login com sua conta ${widget.provider.providerName} para acessar e gerenciar seus arquivos de forma segura.',
            textAlign: TextAlign.center,
            style: widget.theme.typography.caption.copyWith(
              color: widget.theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAuthButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isAuthenticating ? null : _handleAuthentication,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.provider.providerColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.theme.layout.borderRadius),
          ),
          elevation: 4,
        ),
        child: _isAuthenticating
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Conectando...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Conectar com ${widget.provider.providerName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(widget.theme.layout.borderRadius),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Suas credenciais são processadas diretamente pelo ${widget.provider.providerName} e não são armazenadas por este aplicativo.',
              style: widget.theme.typography.caption.copyWith(
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _handleAuthentication() async {
    setState(() {
      _isAuthenticating = true;
    });
    
    try {
      final success = await widget.provider.authenticate();
      
      if (!mounted) return;
      
      if (success) {
        // Show success message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sucesso'),
            content: const Text('Conectado com sucesso!'),
            backgroundColor: Colors.green.shade50,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Show error message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Erro'),
            content: const Text('Falha na autenticação. Tente novamente.'),
            backgroundColor: Colors.red.shade50,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleAuthentication();
                },
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erro'),
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red.shade50,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }
}
