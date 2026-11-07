import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:moment/data/media_store.dart';
import 'package:path/path.dart' as p;

/// Builds a small JPEG with GPS and other EXIF metadata attached, as a
/// stand-in for a photo straight off a phone's camera.
File _samplePhotoWithExif(String path) {
  final image = img.Image(width: 40, height: 30);
  img.fill(image, color: img.ColorRgb8(200, 120, 60));
  image.exif.imageIfd['Software'] = 'TestCam 1.0';
  image.exif.gpsIfd['GPSLatitudeRef'] = 'N';
  image.exif.gpsIfd['GPSLongitudeRef'] = 'E';

  final file = File(path);
  file.writeAsBytesSync(img.encodeJpg(image));
  return file;
}

void main() {
  late Directory tempDir;
  late Directory root;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('media_store_test_');
    root = Directory(p.join(tempDir.path, 'app_support'));
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('copies the photo into media/YYYY/MM under the app-private root', () async {
    final source = _samplePhotoWithExif(p.join(tempDir.path, 'source.jpg'));
    final now = DateTime.utc(2026, 11, 7);
    final store = MediaStore(root: root, clock: () => now, generateId: () => 'abc123');

    final imported = await store.importPhoto(source);

    final expectedDir = p.join(root.path, 'media', '2026', '11');
    expect(p.dirname(imported.path), expectedDir);
    expect(File(imported.path).existsSync(), isTrue);
  });

  test('leaves the original source file untouched', () async {
    final source = _samplePhotoWithExif(p.join(tempDir.path, 'source.jpg'));
    final originalBytes = source.readAsBytesSync();
    final store = MediaStore(root: root, clock: () => DateTime.utc(2026, 11, 7));

    await store.importPhoto(source);

    expect(source.existsSync(), isTrue);
    expect(source.readAsBytesSync(), originalBytes);
  });

  test('strips GPS and other EXIF metadata from the stored photo', () async {
    final source = _samplePhotoWithExif(p.join(tempDir.path, 'source.jpg'));
    final store = MediaStore(root: root, clock: () => DateTime.utc(2026, 11, 7));

    final imported = await store.importPhoto(source);

    final decoded = img.decodeImage(File(imported.path).readAsBytesSync());
    expect(decoded!.exif.isEmpty, isTrue);
  });

  test('writes a smaller thumbnail alongside the stored photo', () async {
    final source = _samplePhotoWithExif(p.join(tempDir.path, 'source.jpg'));
    final store = MediaStore(root: root, clock: () => DateTime.utc(2026, 11, 7));

    final imported = await store.importPhoto(source);

    final thumbnailFile = File(imported.thumbnailPath);
    expect(thumbnailFile.existsSync(), isTrue);

    final thumbnail = img.decodeImage(thumbnailFile.readAsBytesSync());
    final original = img.decodeImage(File(imported.path).readAsBytesSync());
    expect(thumbnail!.width, lessThan(original!.width));
  });

  test('throws when the source file is not a decodable image', () async {
    final source = File(p.join(tempDir.path, 'not-a-photo.jpg'))
      ..writeAsStringSync('definitely not a jpeg');
    final store = MediaStore(root: root, clock: () => DateTime.utc(2026, 11, 7));

    expect(() => store.importPhoto(source), throwsArgumentError);
  });
}
