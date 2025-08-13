import 'package:flutter/material.dart';
import '../lib/src/widgets/file_cloud_widget.dart';
import '../lib/src/models/file_entry.dart';
import '../lib/src/models/selection_config.dart';
import '../lib/src/auth/oauth_config.dart';
import '../lib/src/storage/shared_preferences_account_storage.dart';

/// Example showing how to use the existing CustomProvider without account management.
/// 
/// To demonstrate showAccountManagement: false, you would need to:
/// 1. Modify the hardcoded CustomProvider in FileCloudWidget._initializeProviders()
/// 2. Set showAccountManagement: false in the CustomProviderConfig
/// 
/// This example shows the intended usage for enterprise scenarios.
class CustomProviderNoAccountsExample extends StatelessWidget {
  const CustomProviderNoAccountsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise File Browser'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FileCloudWidget(
          // Account storage - required parameter
          accountStorage: SharedPreferencesAccountStorage(),
          
          // OAuth configuration - required parameter
          oauthConfig: OAuthConfig(
            generateAuthUrl: (state) => 'https://yourserver.com/auth/start?state=$state',
            generateTokenUrl: (state) => 'https://yourserver.com/auth/tokens/$state',
            redirectScheme: 'com.yourcompany.yourapp://oauth',
            providerType: 'google_drive',
          ),
          
          // File selection configuration
          selectionConfig: const SelectionConfig(
            minSelection: 1,
            maxSelection: 5,
            allowedMimeTypes: ['image/jpeg', 'image/png', 'application/pdf'],
          ),
          
          // Set initial provider to 'custom' to use the CustomProvider
          initialProvider: 'custom',
          
          // Callback when files are selected
          onFilesSelected: (List<FileEntry> files) {
            // Handle selected files
            debugPrint('Selected ${files.length} files');
            for (final file in files) {
              debugPrint('- ${file.name} (${file.size} bytes)');
            }
            
            // Show success dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Files Selected'),
                content: Text('Selected ${files.length} files successfully'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Instructions to enable CustomProvider without account management:
/// 
/// 1. In lib/src/widgets/file_cloud_widget.dart, find the _initializeProviders() method
/// 2. Locate the 'custom' case in the switch statement (around line 133)
/// 3. Modify the CustomProviderConfig to include:
/// 
/// ```dart
/// case 'custom':
///   _providers[providerType] = CustomProvider(
///     config: CustomProviderConfig(
///       displayName: 'Enterprise Storage',
///       baseUrl: 'https://your-enterprise-server.com',
///       showAccountManagement: false, // 🔑 This disables account management
///       logoWidget: const Icon(Icons.business, color: Colors.indigo),
///     ),
///   );
///   break;
/// ```
/// 
/// Key Benefits when showAccountManagement: false:
/// ✅ No account selection UI shown
/// ✅ No "Add Account" buttons  
/// ✅ No account counters in provider cards
/// ✅ Automatic temporary account creation
/// ✅ Direct access to file browser
/// ✅ Perfect for enterprise scenarios
/// ✅ Authentication handled externally
/// 
/// Usage Examples:
/// - Enterprise systems with LDAP/SSO authentication
/// - Internal company file servers
/// - B2B applications with simplified UI
/// - Systems where users are pre-authenticated
/// - Corporate environments with external auth