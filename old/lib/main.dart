import 'package:flutter/material.dart';
import 'src/widgets/file_drive_widget.dart';
import 'src/models/file_drive_config.dart';
import 'src/providers/google_drive/google_drive_provider.dart';
import 'src/storage/token_storage_factory.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize token storage using factory
    final tokenStorage = TokenStorageFactory.create();
    
    // Create Google Drive provider
    final googleDriveProvider = GoogleDriveProvider(
      tokenStorage: tokenStorage,
    );
    
    // Initialize from storage to restore saved tokens
    googleDriveProvider.initializeFromStorage();
    
    return MaterialApp(
      title: 'FileDrive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FileDriveWidget(
        config: FileDriveConfig(
          providers: [
            googleDriveProvider,
          ],
        ),
      ),
    );
  }
}
