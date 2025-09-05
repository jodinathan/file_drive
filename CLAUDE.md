# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter package that provides a cloud storage file browser widget with OAuth2 authentication. It supports multiple cloud providers (Google Drive, Dropbox, OneDrive, etc.) with a unified interface for file operations, selection, upload/download, and image cropping functionality.

## Development Commands

### Testing
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/models/provider_configuration_test.dart

# Test the local server for development
./test_local_server.sh
```

### Code Analysis
```bash
# Run static analysis
flutter analyze

# More strict analysis (as used in this project)
dart analyze lib/src --fatal-infos
```

### Localization
```bash
# Generate localization files (after updating ARB files)
flutter gen-l10n
```

### Example Application
```bash
# Run example app (Web - recommended for development)
cd example/app
flutter run -d chrome

# Run example app (Mobile platforms)
cd example/app
flutter run -d android  # or -d ios

# Run example with local OAuth server
cd example
# Terminal 1: Start OAuth server
cd server && dart run lib/main.dart
# Terminal 2: Run Flutter app
cd app && flutter run
```

### Development Server Setup
```bash
# Setup and run local file server for testing
./test_local_server.sh

# This script:
# - Creates test files in ./storage directory  
# - Starts local OAuth server on port 8080
# - Provides health check endpoint at http://localhost:8080/health
```

## Architecture Overview

### Core Components

- **FileCloudWidget**: Main widget providing cloud storage integration
- **BaseCloudProvider**: Abstract base class for all cloud storage providers
- **ProviderConfiguration**: Unified configuration system replacing fragmented configs
- **AccountStorage**: Interface for persistent account storage (SharedPreferences implementation included)
- **OAuth Manager**: Handles OAuth2 flow without client secrets in app code

### Provider System

The architecture uses a provider pattern with factory-based configuration:

**Configuration Factory Pattern:**
```dart
// Google Drive
ProviderConfigurationFactories.googleDrive(
  generateAuthUrl: (state) => 'https://your-server.com/auth/google?state=$state',
  generateTokenUrl: (state) => 'https://your-server.com/auth/tokens/$state',
  redirectScheme: 'com.example.myapp',
  requiredScopes: {OAuthScope.readFiles, OAuthScope.writeFiles},
)

// Custom Provider  
ProviderConfigurationFactories.custom(
  displayName: 'My Provider',
  capabilities: ProviderCapabilities(...),
  createProvider: () => MyCustomProvider(),
)
```

**Provider Hierarchy:**
- `BaseCloudProvider` (abstract base)
  - `OAuthCloudProvider` (OAuth2 providers)
    - `GoogleDriveProvider`
    - `DropboxProvider`
    - `OneDriveProvider`
  - `LocalCloudProvider` (file system providers)
    - `LocalServerProvider`
    - `ExampleLocalServerProvider`

### Key Models

- **FileEntry**: Represents files and folders with metadata
- **ImageFileEntry**: Extends FileEntry with image-specific features
- **CloudAccount**: User account with OAuth tokens and profile info
- **ProviderCapabilities**: Defines what operations a provider supports
- **SelectionConfig**: Configuration for file selection UI
- **CropConfig**: Configuration for image cropping functionality

### Security Architecture

**OAuth2 Without Client Secrets:**
- Client secrets are stored on your server, never in the app
- App receives authorization URLs from your server endpoints
- Token exchange happens on your server
- App only receives final tokens, never sees client secrets

## File Structure

```
lib/
├── src/
│   ├── models/           # Data models (FileEntry, ProviderConfiguration, etc.)
│   ├── providers/        # Cloud provider implementations
│   ├── widgets/          # UI components
│   ├── managers/         # Business logic (upload, navigation, drag-drop)
│   ├── storage/          # Account persistence
│   ├── auth/            # OAuth2 authentication
│   ├── factory/         # Provider factory pattern
│   ├── theme/           # Material 3 theme and constants
│   ├── utils/           # Utilities and logging
│   ├── enums/           # Enums for providers, scopes, etc.
│   └── l10n/            # Internationalization (English/Portuguese)
├── file_cloud.dart     # Public API exports
│
example/
├── server/              # Dart OAuth server example
│   ├── lib/main.dart    # Server entry point
│   └── lib/config.dart  # OAuth credentials (not committed)
└── app/                 # Flutter demo application
    └── lib/main.dart    # App demonstrating widget usage
│
test/
├── models/              # Model unit tests
├── crop_config_test.dart
└── file_cloud_test.dart
```

## Development Patterns

### Provider Implementation

When creating a new cloud provider:

1. **Extend appropriate base class:**
   - `OAuthCloudProvider` for OAuth2 providers
   - `BaseCloudProvider` for custom authentication

2. **Implement required methods:**
   - `getCapabilities()`: Define supported operations
   - `listFolder()`: File/folder listing with pagination
   - `uploadFile()`: File upload with progress
   - `downloadFile()`: File download with streaming
   - `createFolder()`, `deleteEntry()`: Management operations
   - `searchByName()`: Search functionality (if supported)

3. **Follow resource management patterns:**
   - Use single HTTP client instance
   - Implement proper `dispose()` method
   - Handle authentication state properly
   - Use streaming for large file operations

### Widget Integration

```dart
FileCloudWidget(
  providers: [
    // Multiple providers supported simultaneously
    ProviderConfigurationFactories.googleDrive(/*...*/),
    ProviderConfigurationFactories.localServer(/*...*/),
  ],
  accountStorage: SharedPreferencesAccountStorage(),
  selectionConfig: SelectionConfig(
    minSelection: 1,
    maxSelection: 5,
    allowedMimeTypes: ['image/*', 'application/pdf'],
  ),
)
```

### Testing Patterns

- **Unit Tests**: Focus on model classes and business logic
- **Widget Tests**: Test individual UI components  
- **Integration Tests**: Use local server for OAuth flow testing
- **Mock Providers**: Use `CustomProvider` for testing scenarios

### Localization

- ARB files in `lib/src/l10n/`
- Currently supports English (en) and Portuguese (pt)
- Use `AppLocalizations.of(context)` for translations
- Run `flutter gen-l10n` after updating ARB files

## Common Development Tasks

### Adding New Cloud Provider

1. Create provider class extending `OAuthCloudProvider`
2. Add to `CloudProviderType` enum
3. Implement required abstract methods
4. Add factory method to `ProviderConfigurationFactories`
5. Add logo asset and update exports
6. Write unit tests for the new provider

### Adding New Capabilities  

1. Add to `ProviderCapability` enum
2. Update `ProviderCapabilities` model
3. Implement in relevant provider classes
4. Update UI to show/hide features based on capabilities
5. Add validation in `BaseCloudProvider.ensureCapability()`

### Debugging OAuth Flow

1. Start example server: `cd example/server && dart run lib/main.dart`
2. Check health endpoint: `http://localhost:8080/health`
3. Monitor server logs for OAuth state flow
4. Use browser dev tools to trace authorization redirects
5. Verify token exchange in server logs

## Important Notes

- **No client secrets in app code**: Always use server endpoints for OAuth
- **Resource management**: Always call `dispose()` on providers 
- **Flutter Web compatibility**: Use Uri objects, not String URLs for HTTP requests
- **Capabilities-based UI**: Features show/hide based on provider capabilities
- **Streaming for large files**: Avoid loading entire files into memory
- **Error handling**: Use `CloudProviderException` for provider-specific errors
- **Account management**: Support multiple accounts per provider type