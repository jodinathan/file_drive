import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:file_drive/src/widgets/file_drive_widget.dart';
import 'package:file_drive/src/models/file_drive_config.dart';
import 'package:file_drive/src/providers/base/cloud_provider.dart';
import 'package:file_drive/src/models/oauth_types.dart';
import 'dart:async';

// Generate mocks
@GenerateMocks([CloudProvider])
import 'file_drive_widget_test.mocks.dart';

void main() {
  group('FileDriveWidget', () {
    late MockCloudProvider mockProvider;
    late FileDriveConfig config;

    setUp(() {
      mockProvider = MockCloudProvider();
      
      // Setup mock provider
      when(mockProvider.providerName).thenReturn('Test Provider');
      when(mockProvider.providerIcon).thenReturn('test_icon.svg');
      when(mockProvider.providerColor).thenReturn(Colors.blue);
      when(mockProvider.status).thenReturn(ProviderStatus.disconnected);
      when(mockProvider.statusStream).thenAnswer((_) => Stream.value(ProviderStatus.disconnected));
      when(mockProvider.capabilities).thenReturn(ProviderCapabilities.standard());
      when(mockProvider.dispose()).thenReturn(null);

      config = FileDriveConfig(
        providers: [mockProvider],
        theme: FileDriveTheme.light(),
      );
    });

    testWidgets('should render with single provider', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: config),
          ),
        ),
      );

      // Should find the provider name
      expect(find.text('Test Provider'), findsOneWidget);
      
      // Should find the providers header
      expect(find.text('Provedores'), findsOneWidget);
    });

    testWidgets('should render with multiple providers', (WidgetTester tester) async {
      final mockProvider2 = MockCloudProvider();
      when(mockProvider2.providerName).thenReturn('Test Provider 2');
      when(mockProvider2.providerIcon).thenReturn('test_icon2.svg');
      when(mockProvider2.providerColor).thenReturn(Colors.red);
      when(mockProvider2.status).thenReturn(ProviderStatus.disconnected);
      when(mockProvider2.statusStream).thenAnswer((_) => Stream.value(ProviderStatus.disconnected));
      when(mockProvider2.capabilities).thenReturn(ProviderCapabilities.standard());
      when(mockProvider2.dispose()).thenReturn(null);

      final multiConfig = FileDriveConfig(
        providers: [mockProvider, mockProvider2],
        theme: FileDriveTheme.light(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: multiConfig),
          ),
        ),
      );

      // Should find both provider names
      expect(find.text('Test Provider'), findsOneWidget);
      expect(find.text('Test Provider 2'), findsOneWidget);
    });

    testWidgets('should handle empty providers list', (WidgetTester tester) async {
      final emptyConfig = FileDriveConfig(
        providers: [],
        theme: FileDriveTheme.light(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: emptyConfig),
          ),
        ),
      );

      // Should show empty state
      expect(find.text('Nenhum provedor\nconfigurado'), findsOneWidget);
    });

    testWidgets('should select first provider by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: config),
          ),
        ),
      );

      // The first provider should be selected (visual indication)
      // We can't easily test the internal state, but we can verify the UI shows selection
      expect(find.text('Test Provider'), findsOneWidget);
    });

    testWidgets('should call onProviderSelected callback', (WidgetTester tester) async {
      CloudProvider? selectedProvider;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(
              config: config,
              onProviderSelected: (provider) {
                selectedProvider = provider;
              },
            ),
          ),
        ),
      );

      // Tap on the provider
      await tester.tap(find.text('Test Provider'));
      await tester.pump();

      // Callback should have been called
      expect(selectedProvider, equals(mockProvider));
    });

    testWidgets('should dispose providers on widget disposal', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: config),
          ),
        ),
      );

      // Remove the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(),
          ),
        ),
      );

      // Verify dispose was called
      verify(mockProvider.dispose()).called(1);
    });

    testWidgets('should apply custom theme', (WidgetTester tester) async {
      final customTheme = FileDriveTheme(
        colorScheme: const FileDriveColorScheme(
          primary: Colors.purple,
          secondary: Colors.orange,
          background: Colors.grey,
          surface: Colors.white,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onBackground: Colors.black,
          onSurface: Colors.black,
          onError: Colors.white,
        ),
        typography: TypographyTheme.defaultLight(),
      );

      final themedConfig = FileDriveConfig(
        providers: [mockProvider],
        theme: customTheme,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: themedConfig),
          ),
        ),
      );

      // Widget should render without errors
      expect(find.byType(FileDriveWidget), findsOneWidget);
    });

    testWidgets('should handle provider status changes', (WidgetTester tester) async {
      // Create a stream controller to simulate status changes
      final statusController = StreamController<ProviderStatus>();
      when(mockProvider.statusStream).thenAnswer((_) => statusController.stream);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: config),
          ),
        ),
      );

      // Initial state
      expect(find.text('Desconectado'), findsOneWidget);

      // Simulate connecting
      when(mockProvider.status).thenReturn(ProviderStatus.connecting);
      statusController.add(ProviderStatus.connecting);
      await tester.pump();

      expect(find.text('Conectando...'), findsOneWidget);

      // Simulate connected
      when(mockProvider.status).thenReturn(ProviderStatus.connected);
      statusController.add(ProviderStatus.connected);
      await tester.pump();

      expect(find.text('Conectado'), findsOneWidget);

      statusController.close();
    });

    group('Responsive Layout', () {
      testWidgets('should show wide layout on large screens', (WidgetTester tester) async {
        // Set large screen size
        tester.binding.window.physicalSizeTestValue = const Size(1200, 800);
        tester.binding.window.devicePixelRatioTestValue = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileDriveWidget(config: config),
            ),
          ),
        );

        // Should show sidebar layout (Row with two children)
        expect(find.byType(Row), findsWidgets);
        
        addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
        addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
      });

      testWidgets('should show compact layout on small screens', (WidgetTester tester) async {
        // Set small screen size
        tester.binding.window.physicalSizeTestValue = const Size(600, 800);
        tester.binding.window.devicePixelRatioTestValue = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileDriveWidget(config: config),
            ),
          ),
        );

        // Should show tab layout
        expect(find.byType(DefaultTabController), findsOneWidget);
        
        addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
        addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
      });
    });

    group('Breakpoints', () {
      test('should identify mobile correctly', () {
        // This would need a BuildContext, so we'll test the constants
        expect(Breakpoints.mobile, equals(600));
        expect(Breakpoints.tablet, equals(1200));
        expect(Breakpoints.desktop, equals(1200));
      });
    });
  });
}
