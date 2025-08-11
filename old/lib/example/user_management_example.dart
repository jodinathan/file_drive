/// Example widget demonstrating the new user management functionality
library;

import 'package:flutter/material.dart';
import '../src/widgets/file_explorer.dart';
import '../src/providers/google_drive/google_drive_provider.dart';
import '../src/storage/shared_preferences_token_storage.dart';
import '../src/models/file_drive_config.dart';

/// Example app showing the breadcrumb with user management
class UserManagementExample extends StatefulWidget {
  const UserManagementExample({Key? key}) : super(key: key);

  @override
  State<UserManagementExample> createState() => _UserManagementExampleState();
}

class _UserManagementExampleState extends State<UserManagementExample> {
  late GoogleDriveProvider _provider;
  
  @override
  void initState() {
    super.initState();
    _initializeProvider();
  }
  
  void _initializeProvider() async {
    final tokenStorage = SharedPreferencesTokenStorage();
    
    _provider = GoogleDriveProvider(
      tokenStorage: tokenStorage,
      onTokenDelete: (providerId, userId) {
        print('Token deleted for provider: $providerId, user: $userId');
        setState(() {}); // Trigger rebuild when user is deleted
      },
    );
    
    // Initialize from stored tokens
    await _provider.initializeFromStorage();
    
    if (mounted) {
      setState(() {});
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = FileDriveTheme.light();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Drive - Gerenciamento de Usuários'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: FileExplorer(
        provider: _provider,
        theme: theme,
        onFilesSelected: (files) {
          print('Selected files: ${files.map((f) => f.name).join(', ')}');
        },
      ),
    );
  }
}

/// Main app with user management
class FileDriveApp extends StatelessWidget {
  const FileDriveApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Drive',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const UserManagementExample(),
    );
  }
}