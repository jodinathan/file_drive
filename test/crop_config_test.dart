import 'package:flutter_test/flutter_test.dart';
import '../lib/src/models/crop_config.dart';

void main() {
  group('CropConfig Tests', () {
    test('should create custom config with 9:6 ratio', () {
      final config = CropConfig.custom(
        aspectRatio: 9.0 / 6.0,
        minWidth: 300,
        minHeight: 200,
        enforceAspectRatio: true,
      );

      expect(config.aspectRatio, equals(1.5));
      expect(config.minWidth, equals(300));
      expect(config.minHeight, equals(200));
      expect(config.enforceAspectRatio, isTrue);
      expect(config.effectiveAspectRatio, equals(1.5));
    });

    test('should validate crop dimensions correctly', () {
      final config = CropConfig.custom(
        aspectRatio: 9.0 / 6.0,
        minWidth: 300,
        minHeight: 200,
        enforceAspectRatio: true,
      );

      // Valid crop (300x200 = 1.5 ratio)
      expect(config.isValidCrop(300, 200), isTrue);

      // Valid crop (450x300 = 1.5 ratio)
      expect(config.isValidCrop(450, 300), isTrue);

      // Invalid crop - too small width
      expect(config.isValidCrop(250, 167), isFalse);

      // Invalid crop - too small height
      expect(config.isValidCrop(300, 150), isFalse);

      // Invalid crop - wrong ratio
      expect(config.isValidCrop(300, 300), isFalse);
    });

    test('should create square config', () {
      final config = CropConfig.square(minSize: 200);

      expect(config.aspectRatio, equals(1.0));
      expect(config.minWidth, equals(200));
      expect(config.minHeight, equals(200));
      expect(config.enforceAspectRatio, isTrue);
    });

    test('should create free-form config', () {
      final config = CropConfig.freeForm(
        minRatio: 0.5,
        maxRatio: 2.0,
        minWidth: 100,
      );

      expect(config.aspectRatio, isNull);
      expect(config.minRatio, equals(0.5));
      expect(config.maxRatio, equals(2.0));
      expect(config.minWidth, equals(100));
      expect(config.allowFreeForm, isTrue);
    });

    test('should provide correct descriptions', () {
      final square = CropConfig.square();
      expect(square.description, equals('Square (1:1)'));

      final landscape = CropConfig.landscape();
      expect(landscape.description, equals('Landscape (16:9)'));

      final custom = CropConfig.custom(aspectRatio: 1.5);
      expect(custom.description, equals('Custom (1.50:1)'));

      final freeForm = CropConfig.freeForm();
      expect(freeForm.description, equals('Free-form'));
    });
  });
}