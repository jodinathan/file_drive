// This is a basic Flutter widget test for FileDrive app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_drive/src/widgets/file_drive_widget.dart';

import 'package:file_drive/main.dart';

void main() {
  testWidgets('FileDrive smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app starts without errors.
    expect(find.byType(MyApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Verify that FileDriveWidget is rendered
    expect(find.byType(FileDriveWidget), findsOneWidget);
  });
}