import 'package:flutter_test/flutter_test.dart';
import '../lib/src/models/file_entry.dart';

void main() {
  group('FileEntry Thumbnail Tests', () {
    test('should create FileEntry with thumbnail fields', () {
      final file = FileEntry(
        id: 'test-id',
        name: 'test-file.jpg',
        isFolder: false,
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        hasThumbnail: true,
        thumbnailVersion: '1.0',
      );

      expect(file.id, 'test-id');
      expect(file.name, 'test-file.jpg');
      expect(file.isFolder, false);
      expect(file.thumbnailUrl, 'https://example.com/thumbnail.jpg');
      expect(file.hasThumbnail, true);
      expect(file.thumbnailVersion, '1.0');
    });

    test('should create FileEntry with default thumbnail values', () {
      final file = FileEntry(
        id: 'test-id',
        name: 'test-file.txt',
        isFolder: false,
      );

      expect(file.thumbnailUrl, null);
      expect(file.hasThumbnail, false);
      expect(file.thumbnailVersion, null);
    });

    test('should serialize and deserialize FileEntry with thumbnails', () {
      final originalFile = FileEntry(
        id: 'test-id',
        name: 'test-image.png',
        isFolder: false,
        size: 1024,
        mimeType: 'image/png',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        hasThumbnail: true,
        thumbnailVersion: '2.0',
        createdAt: DateTime(2023, 1, 1),
        modifiedAt: DateTime(2023, 1, 2),
      );

      final json = originalFile.toJson();
      final deserializedFile = FileEntry.fromJson(json);

      expect(deserializedFile.id, originalFile.id);
      expect(deserializedFile.name, originalFile.name);
      expect(deserializedFile.thumbnailUrl, originalFile.thumbnailUrl);
      expect(deserializedFile.hasThumbnail, originalFile.hasThumbnail);
      expect(deserializedFile.thumbnailVersion, originalFile.thumbnailVersion);
      expect(deserializedFile.createdAt, originalFile.createdAt);
      expect(deserializedFile.modifiedAt, originalFile.modifiedAt);
    });

    test('should handle JSON without thumbnail fields', () {
      final json = {
        'id': 'test-id',
        'name': 'old-file.txt',
        'isFolder': false,
        'size': 512,
      };

      final file = FileEntry.fromJson(json);

      expect(file.thumbnailUrl, null);
      expect(file.hasThumbnail, false);
      expect(file.thumbnailVersion, null);
    });

    test('should copy FileEntry with thumbnail modifications', () {
      final originalFile = FileEntry(
        id: 'test-id',
        name: 'test-file.jpg',
        isFolder: false,
        hasThumbnail: false,
      );

      final updatedFile = originalFile.copyWith(
        thumbnailUrl: 'https://example.com/new-thumb.jpg',
        hasThumbnail: true,
        thumbnailVersion: '1.5',
      );

      expect(updatedFile.id, originalFile.id);
      expect(updatedFile.name, originalFile.name);
      expect(updatedFile.thumbnailUrl, 'https://example.com/new-thumb.jpg');
      expect(updatedFile.hasThumbnail, true);
      expect(updatedFile.thumbnailVersion, '1.5');
    });

    test('should validate thumbnail URL format', () {
      expect(
        () => FileEntry(
          id: 'test-id',
          name: 'test-file.jpg',
          isFolder: false,
          thumbnailUrl: 'invalid-url',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should accept valid thumbnail URL', () {
      expect(
        () => FileEntry(
          id: 'test-id',
          name: 'test-file.jpg',
          isFolder: false,
          thumbnailUrl: 'https://example.com/thumb.jpg',
        ),
        returnsNormally,
      );
    });

    test('should accept null thumbnail URL', () {
      expect(
        () => FileEntry(
          id: 'test-id',
          name: 'test-file.jpg',
          isFolder: false,
          thumbnailUrl: null,
        ),
        returnsNormally,
      );
    });

    test('should validate required fields', () {
      expect(
        () => FileEntry(
          id: '',
          name: 'test-file.jpg',
          isFolder: false,
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => FileEntry(
          id: 'test-id',
          name: '',
          isFolder: false,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should handle folder with thumbnails gracefully', () {
      final folder = FileEntry(
        id: 'folder-id',
        name: 'My Folder',
        isFolder: true,
        thumbnailUrl: 'https://example.com/folder-thumb.jpg',
        hasThumbnail: true,
      );

      expect(folder.isFolder, true);
      expect(folder.thumbnailUrl, 'https://example.com/folder-thumb.jpg');
      expect(folder.hasThumbnail, true);
    });
  });

  group('FileEntry Thumbnail Edge Cases', () {
    test('should handle very long thumbnail URLs', () {
      final longUrl = 'https://example.com/' + 'a' * 2000 + '.jpg';
      
      final file = FileEntry(
        id: 'test-id',
        name: 'test-file.jpg',
        isFolder: false,
        thumbnailUrl: longUrl,
      );

      expect(file.thumbnailUrl, longUrl);
    });

    test('should handle special characters in thumbnail version', () {
      final file = FileEntry(
        id: 'test-id',
        name: 'test-file.jpg',
        isFolder: false,
        thumbnailVersion: 'v1.0-beta+build.123',
      );

      expect(file.thumbnailVersion, 'v1.0-beta+build.123');
    });

    test('should maintain thumbnail consistency after JSON roundtrip', () {
      final originalFile = FileEntry(
        id: 'test-id',
        name: 'test-file.jpg',
        isFolder: false,
        thumbnailUrl: 'https://example.com/thumb.jpg',
        hasThumbnail: true,
        thumbnailVersion: '1.0',
      );

      final json = originalFile.toJson();
      final restored = FileEntry.fromJson(json);
      final secondJson = restored.toJson();

      expect(secondJson['thumbnailUrl'], json['thumbnailUrl']);
      expect(secondJson['hasThumbnail'], json['hasThumbnail']);
      expect(secondJson['thumbnailVersion'], json['thumbnailVersion']);
    });
  });
}