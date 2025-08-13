import 'package:flutter/material.dart';
import 'package:file_drive/file_drive.dart';

/// Example showing how to use custom logo widgets with CustomProvider
class CustomLogoExample extends StatelessWidget {
  const CustomLogoExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Logo Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Custom Provider Examples:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Example 1: Material Icon
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Storage Icon Example'),
                    const SizedBox(height: 8),
                    ProviderLogo(
                      providerType: 'custom',
                      size: 48,
                      customWidget: const Icon(
                        Icons.storage,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Example 2: Cloud Icon
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Cloud Icon Example'),
                    const SizedBox(height: 8),
                    ProviderLogo(
                      providerType: 'custom',
                      size: 48,
                      customWidget: const Icon(
                        Icons.cloud,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Example 3: Server Icon
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Server Icon Example'),
                    const SizedBox(height: 8),
                    ProviderLogo(
                      providerType: 'custom',
                      size: 48,
                      customWidget: const Icon(
                        Icons.dns,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Note: These examples show how custom widgets\nappear in the ProviderLogo widget.\nIn actual usage, the FileCloudWidget will\nautomatically use the logoWidget from\nCustomProviderConfig.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example of how to configure custom providers with logo widgets
class CustomProviderUsageExample {
  static void demonstrateUsage() {
    // Example 1: Storage icon
    final storageProvider = CustomProvider(
      config: CustomProviderConfig(
        displayName: 'My Storage Server',
        baseUrl: 'https://storage.example.com',
        logoWidget: const Icon(
          Icons.storage,
          color: Colors.blue,
        ),
      ),
    );
    
    // Example 2: Cloud icon  
    final cloudProvider = CustomProvider(
      config: CustomProviderConfig(
        displayName: 'Private Cloud',
        baseUrl: 'https://cloud.company.com',
        logoWidget: const Icon(
          Icons.cloud,
          color: Colors.green,
        ),
      ),
    );
    
    // Example 3: Server icon
    final serverProvider = CustomProvider(
      config: CustomProviderConfig(
        displayName: 'File Server',
        baseUrl: 'http://fileserver.local',
        logoWidget: const Icon(
          Icons.dns,
          color: Colors.orange,
        ),
      ),
    );
    
    // Note: These providers would be configured in your app
    // and automatically used by FileCloudWidget
    print('Custom providers configured with logo widgets');
  }
}