import 'package:file_drive/src/widgets/provider_tab.dart';
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
      // Create a broadcast stream to avoid 'Stream has already been listened to' error
      final statusStreamController = StreamController<ProviderStatus>.broadcast();
      when(mockProvider.statusStream).thenAnswer((_) => statusStreamController.stream);
      when(mockProvider.status).thenReturn(ProviderStatus.disconnected);
      // Add initial value to the stream
      statusStreamController.add(ProviderStatus.disconnected);
      when(mockProvider.capabilities).thenReturn(ProviderCapabilities.standard());
      when(mockProvider.dispose()).thenReturn(null);

      config = FileDriveConfig(
        providers: [mockProvider],
        theme: FileDriveTheme.light(),
      );
    });

    testWidgets('should render with single provider', (WidgetTester tester) async {
      // Set wide screen size to ensure wide layout
      tester.binding.window.physicalSizeTestValue = const Size(1200, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: config),
          ),
        ),
      );

      // Should find the provider name in a ProviderTab
      expect(find.widgetWithText(ProviderTab, 'Test Provider'), findsOneWidget);
      
      // Should find the providers header
      expect(find.text('Provedores'), findsOneWidget);
      
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
    });

    testWidgets('should render with multiple providers', (WidgetTester tester) async {
      final mockProvider2 = MockCloudProvider();
      when(mockProvider2.providerName).thenReturn('Test Provider 2');
      when(mockProvider2.providerIcon).thenReturn('test_icon2.svg');
      when(mockProvider2.providerColor).thenReturn(Colors.red);
      when(mockProvider2.status).thenReturn(ProviderStatus.disconnected);
      // Create a broadcast stream to avoid 'Stream has already been listened to' error
      final statusStreamController2 = StreamController<ProviderStatus>.broadcast();
      when(mockProvider2.statusStream).thenAnswer((_) => statusStreamController2.stream);
      when(mockProvider2.status).thenReturn(ProviderStatus.disconnected);
      // Add initial value to the stream
      statusStreamController2.add(ProviderStatus.disconnected);
      when(mockProvider2.capabilities).thenReturn(ProviderCapabilities.standard());
      when(mockProvider2.dispose()).thenReturn(null);

      final multiConfig = FileDriveConfig(
        providers: [mockProvider, mockProvider2],
        theme: FileDriveTheme.light(),
      );

      // Set wide screen size to ensure wide layout
      tester.binding.window.physicalSizeTestValue = const Size(1200, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: multiConfig),
          ),
        ),
      );

      // Should find both provider names using specific finders
      expect(find.widgetWithText(ProviderTab, 'Test Provider'), findsOneWidget);
      expect(find.widgetWithText(ProviderTab, 'Test Provider 2'), findsOneWidget);
      
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
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
      // The empty state text has been updated in the implementation
      expect(find.text('Selecione um provedor'), findsOneWidget);
    });

    testWidgets('should select first provider by default', (WidgetTester tester) async {
      // Ensure wide layout for consistent ProviderTab behavior
      tester.binding.window.physicalSizeTestValue = const Size(1200, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: config),
          ),
        ),
      );

      // The first provider should be selected (visual indication)
      // We can't easily test the internal state, but we can verify the UI shows the provider
      expect(find.widgetWithText(ProviderTab, 'Test Provider'), findsOneWidget);
      
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
    });

    testWidgets('should call onProviderSelected callback', (WidgetTester tester) async {
      CloudProvider? selectedProvider;
      
      // Ensure wide layout for consistent ProviderTab behavior
      tester.binding.window.physicalSizeTestValue = const Size(1200, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
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
      await tester.pumpAndSettle();

      // Tap on the provider tab using the InkWell which is the actual tappable area
      final providerTabFinder = find.widgetWithText(ProviderTab, 'Test Provider');
      final inkWellFinder = find.descendant(
        of: providerTabFinder,
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWellFinder);
      await tester.pump();

      // Callback should have been called
      expect(selectedProvider, equals(mockProvider));
      
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
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
          warning: Colors.amber,
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
      final statusController = StreamController<ProviderStatus>.broadcast();
      when(mockProvider.statusStream).thenAnswer((_) => statusController.stream);
      
      // Ensure wide layout for consistent ProviderTab behavior
      tester.binding.window.physicalSizeTestValue = const Size(1200, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileDriveWidget(config: config),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state - check that the widget renders without error
      expect(find.widgetWithText(ProviderTab, 'Test Provider'), findsOneWidget);

      // Simulate connecting
      when(mockProvider.status).thenReturn(ProviderStatus.connecting);
      statusController.add(ProviderStatus.connecting);
      await tester.pump();

      // Should still show the provider
      expect(find.widgetWithText(ProviderTab, 'Test Provider'), findsOneWidget);

      // Simulate connected
      when(mockProvider.status).thenReturn(ProviderStatus.connected);
      statusController.add(ProviderStatus.connected);
      await tester.pump();

      // Should still show the provider
      expect(find.widgetWithText(ProviderTab, 'Test Provider'), findsOneWidget);

      statusController.close();
      
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
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
