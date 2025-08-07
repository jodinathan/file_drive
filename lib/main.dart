import 'package:flutter/material.dart';
import 'src/widgets/file_drive_widget.dart';
import 'src/models/file_drive_config.dart';
import 'src/providers/google_drive/google_drive_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FileDrive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FileDriveWidget(
        config: FileDriveConfig(
          providers: [
            GoogleDriveProvider(),
          ],
        ),
      ),
    );
  }
}
