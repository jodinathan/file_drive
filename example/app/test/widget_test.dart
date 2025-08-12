import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:file_cloud_example_app/main.dart';

void main() {
  testWidgets('File Cloud Example App smoke test', (WidgetTester tester) async {
    // Set a reasonable screen size for testing
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FileCloudExampleApp());

    // Verify that the app loads without errors
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Verify that the app is rendered properly
    expect(find.byType(FileCloudExampleApp), findsOneWidget);
    
    // Reset the screen size
    addTearDown(tester.view.resetPhysicalSize);
  });
}
