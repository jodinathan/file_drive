import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:file_drive/src/widgets/provider_content.dart';
import 'package:file_drive/src/providers/base/oauth_cloud_provider.dart';
import 'package:file_drive/src/providers/base/cloud_provider.dart';
import 'package:file_drive/src/models/file_drive_config.dart';

import '../test_helpers.dart';

// Generate mocks
@GenerateMocks([OAuthCloudProvider])
import 'provider_content_needsreauth_test.mocks.dart';

void main() {
  group('ProviderContent - NeedsReauth State', () {
    late MockOAuthCloudProvider mockProvider;
    late FileDriveTheme theme;

    setUp(() {
      mockProvider = MockOAuthCloudProvider();
      theme = FileDriveTheme.light();
      
      // Setup default behavior
      when(mockProvider.providerName).thenReturn('Google Drive');
      when(mockProvider.status).thenReturn(ProviderStatus.needsReauth);
      when(mockProvider.statusStream).thenAnswer((_) => 
          Stream.fromIterable([ProviderStatus.needsReauth]));
      when(mockProvider.authenticate()).thenAnswer((_) async => true);
    });

    testWidgets('should display reauth screen when status is needsReauth', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderContent(
              provider: mockProvider,
              theme: theme,
            ),
          ),
        ),
      );

      // Should display reauth state
      expect(find.text('Permissões Insuficientes'), findsOneWidget);
      expect(find.textContaining('Esta conta precisa de permissões'), findsOneWidget);
      expect(find.text('Refazer Login'), findsOneWidget);
      
      // Verify that back button was removed to prevent unintended logout
      expect(find.text('Voltar'), findsNothing);
      
      expect(mockProvider.status, equals(ProviderStatus.needsReauth));
    });

    testWidgets('should call authenticate when reauth button is pressed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderContent(
              provider: mockProvider,
              theme: theme,
            ),
          ),
        ),
      );

      // Tap the reauth button
      await tester.tap(find.text('Refazer Login'));
      await tester.pump();

      // Should call authenticate
      verify(mockProvider.authenticate()).called(1);
    });
  });
}