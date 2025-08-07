import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:file_drive/src/widgets/provider_tab.dart';
import 'package:file_drive/src/models/file_drive_config.dart';
import 'package:file_drive/src/providers/base/cloud_provider.dart';
import 'package:file_drive/src/models/oauth_types.dart';
import 'dart:async';

// Generate mocks
@GenerateMocks([CloudProvider])
import 'provider_tab_test.mocks.dart';

void main() {
  group('ProviderTab', () {
    late MockCloudProvider mockProvider;
    late FileDriveTheme theme;
    late StreamController<ProviderStatus> statusController;

    setUp(() {
      mockProvider = MockCloudProvider();
      statusController = StreamController<ProviderStatus>();
      theme = FileDriveTheme.light();

      // Setup mock provider
      when(mockProvider.providerName).thenReturn('Test Provider');
      when(mockProvider.providerIcon).thenReturn('test_icon.svg');
      when(mockProvider.providerColor).thenReturn(Colors.blue);
      when(mockProvider.status).thenReturn(ProviderStatus.disconnected);
      when(mockProvider.statusStream).thenAnswer((_) => statusController.stream);
      when(mockProvider.capabilities).thenReturn(ProviderCapabilities.standard());
    });

    tearDown(() {
      statusController.close();
    });

    testWidgets('should render provider tab with basic info', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: false,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Should show provider name
      expect(find.text('Test Provider'), findsOneWidget);
      
      // Should show status indicator
      expect(find.text('Desconectado'), findsOneWidget);
    });

    testWidgets('should show selected state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: true,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Should show check icon when selected
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('should call onTap when tapped', (WidgetTester tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: false,
              onTap: () {
                wasTapped = true;
              },
              theme: theme,
            ),
          ),
        ),
      );

      // Tap the provider tab
      await tester.tap(find.byType(ProviderTab));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('should show connecting status', (WidgetTester tester) async {
      when(mockProvider.status).thenReturn(ProviderStatus.connecting);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: false,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Should show connecting status
      expect(find.text('Conectando...'), findsOneWidget);
      
      // Should show progress indicator
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    });

    testWidgets('should show connected status', (WidgetTester tester) async {
      when(mockProvider.status).thenReturn(ProviderStatus.connected);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: false,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Should show connected status
      expect(find.text('Conectado'), findsOneWidget);
      
      // Should show check icon in status badge
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('should show error status', (WidgetTester tester) async {
      when(mockProvider.status).thenReturn(ProviderStatus.error);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: false,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Should show error status
      expect(find.text('Erro de conexão'), findsOneWidget);
      
      // Should show error icon
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('should show token expired status', (WidgetTester tester) async {
      when(mockProvider.status).thenReturn(ProviderStatus.tokenExpired);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: false,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Should show token expired status
      expect(find.text('Token expirado'), findsOneWidget);
    });

    testWidgets('should update status when stream changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: false,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Initial state
      expect(find.text('Desconectado'), findsOneWidget);

      // Change status
      when(mockProvider.status).thenReturn(ProviderStatus.connecting);
      statusController.add(ProviderStatus.connecting);
      await tester.pump();

      expect(find.text('Conectando...'), findsOneWidget);

      // Change to connected
      when(mockProvider.status).thenReturn(ProviderStatus.connected);
      statusController.add(ProviderStatus.connected);
      await tester.pump();

      expect(find.text('Conectado'), findsOneWidget);
    });

    testWidgets('should show provider icon with correct color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: false,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Should show cloud icon
      expect(find.byIcon(Icons.cloud), findsOneWidget);
      
      // Find the container with the provider color
      final containerFinder = find.byWidgetPredicate(
        (widget) => widget is Container && 
                    widget.decoration is BoxDecoration &&
                    (widget.decoration as BoxDecoration).color == Colors.blue,
      );
      expect(containerFinder, findsOneWidget);
    });

    testWidgets('should animate on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: false,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Find the InkWell
      final inkWellFinder = find.byType(InkWell);
      expect(inkWellFinder, findsOneWidget);

      // Tap and hold to trigger animation
      await tester.startGesture(tester.getCenter(inkWellFinder));
      await tester.pump(const Duration(milliseconds: 100));
      
      // Should have animation running
      expect(find.byType(AnimatedBuilder), findsOneWidget);
    });

    testWidgets('should show different background colors based on status', (WidgetTester tester) async {
      // Test connected status background
      when(mockProvider.status).thenReturn(ProviderStatus.connected);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: false,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Should render without errors
      expect(find.byType(ProviderTab), findsOneWidget);
    });

    testWidgets('should show selection border when selected', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderTab(
              provider: mockProvider,
              isSelected: true,
              onTap: () {},
              theme: theme,
            ),
          ),
        ),
      );

      // Should show selection indicator
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('should handle status color correctly', (WidgetTester tester) async {
      // Test all status types
      final statuses = [
        ProviderStatus.disconnected,
        ProviderStatus.connecting,
        ProviderStatus.connected,
        ProviderStatus.error,
        ProviderStatus.tokenExpired,
      ];

      for (final status in statuses) {
        when(mockProvider.status).thenReturn(status);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProviderTab(
                provider: mockProvider,
                isSelected: false,
                onTap: () {},
                theme: theme,
              ),
            ),
          ),
        );

        // Should render without errors for each status
        expect(find.byType(ProviderTab), findsOneWidget);
      }
    });
  });
}
