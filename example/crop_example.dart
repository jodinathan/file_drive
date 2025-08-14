import 'package:flutter/material.dart';
import '../lib/src/widgets/crop_panel_widget.dart';
import '../lib/src/models/image_file_entry.dart';
import '../lib/src/models/file_entry.dart';
import '../lib/src/models/crop_config.dart';

/// Example demonstrating the crop panel with automatic dimension detection
class CropExampleApp extends StatelessWidget {
  const CropExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crop Panel Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CropExamplePage(),
    );
  }
}

class CropExamplePage extends StatefulWidget {
  const CropExamplePage({super.key});

  @override
  State<CropExamplePage> createState() => _CropExamplePageState();
}

class _CropExamplePageState extends State<CropExamplePage> {
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Panel Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Crop Panel with Auto Dimension Detection',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'This example demonstrates automatic dimension detection\n'
              'for images with a 9:6 aspect ratio crop and minimum 300px width.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _showCropPanel(context),
              child: const Text('Open Crop Panel'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCropPanel(BuildContext context) {
    // Create sample image files with missing dimensions
    // These would normally come from your server without image_data
    final imageFiles = [
      _createSampleImageFile(
        '1',
        'sample1.jpg',
        'https://picsum.photos/800/600',
        'https://picsum.photos/200/150',
      ),
      _createSampleImageFile(
        '2', 
        'sample2.jpg',
        'https://picsum.photos/1200/800',
        'https://picsum.photos/200/133',
      ),
      _createSampleImageFile(
        '3',
        'sample3.jpg', 
        'https://picsum.photos/600/900',
        'https://picsum.photos/200/300',
      ),
    ];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CropPanelWidget(
          imageFiles: imageFiles,
          cropConfig: CropConfig.custom(
            aspectRatio: 9.0 / 6.0, // 9:6 aspect ratio (1.5:1)
            minWidth: 300,
            minHeight: 200, // 300 * (6/9) = 200 to maintain 9:6 ratio
            enforceAspectRatio: true,
          ),
          onCropCompleted: (croppedFiles) {
            Navigator.of(context).pop();
            _showResultDialog(context, croppedFiles);
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  ImageFileEntry _createSampleImageFile(
    String id,
    String name,
    String downloadUrl,
    String thumbnailUrl,
  ) {
    // Create a FileEntry without image_data metadata (simulating server without metadata)
    final fileEntry = FileEntry(
      id: id,
      name: name,
      isFolder: false,
      size: 1024 * 1024, // 1MB
      mimeType: 'image/jpeg',
      createdAt: DateTime.now().subtract(Duration(days: int.parse(id))),
      modifiedAt: DateTime.now().subtract(Duration(hours: int.parse(id))),
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      hasThumbnail: true,
      canDownload: true,
      metadata: {
        // Note: No 'image_data' key here - simulating server without metadata
        'some_other_data': 'value',
      },
    );

    // Convert to ImageFileEntry - dimensions will be null initially
    return ImageFileEntry.fromFileEntry(fileEntry);
  }

  void _showResultDialog(BuildContext context, List<ImageFileEntry> croppedFiles) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crop Results'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: croppedFiles.length,
            itemBuilder: (context, index) {
              final file = croppedFiles[index];
              final crop = file.getEffectiveCrop();
              
              return Card(
                child: ListTile(
                  title: Text(file.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Original: ${file.width ?? '?'}x${file.height ?? '?'}'),
                      if (file.hasCropData())
                        Text('Crop: ${crop.left},${crop.top} ${crop.width}x${crop.height}')
                      else
                        const Text('No crop applied'),
                    ],
                  ),
                  leading: file.thumbnailUrl != null
                      ? Image.network(
                          file.thumbnailUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.image, size: 50),
                        )
                      : const Icon(Icons.image, size: 50),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const CropExampleApp());
}