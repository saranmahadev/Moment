import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:moment/data/media_store.dart';
import 'package:moment/settings/media_quality.dart';
import 'package:moment/video/video_probe.dart';
import 'package:path/path.dart' as p;

/// Builds a small JPEG with GPS and other EXIF metadata attached, as a
/// stand-in for a photo straight off a phone's camera.
File _samplePhotoWithExif(String path) {
  final image = img.Image(width: 800, height: 600);
  img.fill(image, color: img.ColorRgb8(200, 120, 60));
  image.exif.imageIfd['Software'] = 'TestCam 1.0';
  image.exif.gpsIfd['GPSLatitudeRef'] = 'N';
  image.exif.gpsIfd['GPSLongitudeRef'] = 'E';

  final file = File(path);
  file.writeAsBytesSync(img.encodeJpg(image));
  return file;
}

/// Stands in for the device's video tooling: reports a fixed duration and
/// writes a small poster file, or none at all when the video is unreadable.
class _FakeVideoProbe implements VideoProbe {
  _FakeVideoProbe({this.readable = true});

  final bool readable;

  @override
  Future<Duration> duration(File video) async {
    if (!readable) throw const FormatException('not a video');
    return const Duration(seconds: 48);
  }

  @override
  Future<bool> writePoster(File video, File destination) async {
    if (!readable) return false;
    await destination.writeAsBytes([1, 2, 3]);
    return true;
  }
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

  test(
    'copies the photo into media/YYYY/MM under the app-private root',
    () async {
      final source = _samplePhotoWithExif(p.join(tempDir.path, 'source.jpg'));
      final now = DateTime.utc(2026, 11, 7);
      final store = MediaStore(
        root: root,
        clock: () => now,
        generateId: () => 'abc123',
      );

      final imported = await store.importPhoto(source);

      final expectedDir = p.join(root.path, 'media', '2026', '11');
      expect(p.dirname(imported.path), expectedDir);
      expect(File(imported.path).existsSync(), isTrue);
    },
  );

  test('leaves the original source file untouched', () async {
    final source = _samplePhotoWithExif(p.join(tempDir.path, 'source.jpg'));
    final originalBytes = source.readAsBytesSync();
    final store = MediaStore(
      root: root,
      clock: () => DateTime.utc(2026, 11, 7),
    );

    await store.importPhoto(source);

    expect(source.existsSync(), isTrue);
    expect(source.readAsBytesSync(), originalBytes);
  });

  test('strips GPS and other EXIF metadata from the stored photo', () async {
    final source = _samplePhotoWithExif(p.join(tempDir.path, 'source.jpg'));
    final store = MediaStore(
      root: root,
      clock: () => DateTime.utc(2026, 11, 7),
    );

    final imported = await store.importPhoto(source);

    final decoded = img.decodeImage(File(imported.path).readAsBytesSync());
    expect(decoded!.exif.isEmpty, isTrue);
  });

  test('writes a smaller thumbnail alongside the stored photo', () async {
    final source = _samplePhotoWithExif(p.join(tempDir.path, 'source.jpg'));
    final store = MediaStore(
      root: root,
      clock: () => DateTime.utc(2026, 11, 7),
    );

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
    final store = MediaStore(
      root: root,
      clock: () => DateTime.utc(2026, 11, 7),
    );

    expect(() => store.importPhoto(source), throwsArgumentError);
  });

  group('importAudio', () {
    test(
      'copies the recording into media/YYYY/MM under the app-private root',
      () async {
        final source = File(p.join(tempDir.path, 'source.m4a'))
          ..writeAsBytesSync([1, 2, 3, 4]);
        final now = DateTime.utc(2026, 11, 7);
        final store = MediaStore(
          root: root,
          clock: () => now,
          generateId: () => 'audio123',
        );

        final imported = await store.importAudio(source);

        final expectedDir = p.join(root.path, 'media', '2026', '11');
        expect(p.dirname(imported.path), expectedDir);
        expect(File(imported.path).existsSync(), isTrue);
        expect(File(imported.path).readAsBytesSync(), [1, 2, 3, 4]);
      },
    );

    test('leaves the original recording untouched', () async {
      final source = File(p.join(tempDir.path, 'source.m4a'))
        ..writeAsBytesSync([5, 6, 7]);
      final store = MediaStore(
        root: root,
        clock: () => DateTime.utc(2026, 11, 7),
      );

      await store.importAudio(source);

      expect(source.existsSync(), isTrue);
      expect(source.readAsBytesSync(), [5, 6, 7]);
    });
  });

  group('importVideo', () {
    test(
      'copies the video into media/YYYY/MM with a poster and its duration',
      () async {
        final source = File(p.join(tempDir.path, 'clip.mp4'))
          ..writeAsBytesSync([1, 2, 3, 4, 5]);
        final store = MediaStore(
          root: root,
          clock: () => DateTime.utc(2026, 11, 7),
          generateId: () => 'video123',
        );

        final imported = await store.importVideo(
          source,
          probe: _FakeVideoProbe(),
        );

        final dir = p.join(root.path, 'media', '2026', '11');
        expect(imported.path, p.join(dir, 'video123.mp4'));
        expect(imported.posterPath, p.join(dir, 'video123-poster.jpg'));
        expect(File(imported.path).readAsBytesSync(), [1, 2, 3, 4, 5]);
        expect(File(imported.posterPath).existsSync(), isTrue);
        expect(imported.duration, const Duration(seconds: 48));
      },
    );

    test('leaves the original video untouched', () async {
      final source = File(p.join(tempDir.path, 'clip.mov'))
        ..writeAsBytesSync([9, 8, 7]);
      final store = MediaStore(
        root: root,
        clock: () => DateTime.utc(2026, 11, 7),
      );

      await store.importVideo(source, probe: _FakeVideoProbe());

      expect(source.readAsBytesSync(), [9, 8, 7]);
    });

    test('an unreadable video is rejected and leaves nothing behind', () async {
      final source = File(p.join(tempDir.path, 'broken.mp4'))
        ..writeAsStringSync('not a video');
      final store = MediaStore(
        root: root,
        clock: () => DateTime.utc(2026, 11, 7),
      );

      await expectLater(
        store.importVideo(source, probe: _FakeVideoProbe(readable: false)),
        throwsArgumentError,
      );

      final media = Directory(p.join(root.path, 'media'));
      final leftovers = media.existsSync()
          ? media.listSync(recursive: true).whereType<File>().toList()
          : const <File>[];
      expect(leftovers, isEmpty);
    });

    test('a 1 GB video is copied without loading it into memory', () async {
      const oneGigabyte = 1024 * 1024 * 1024;
      final source = File(p.join(tempDir.path, 'big.mp4'));
      // A sparse file: 1 GB long without writing 1 GB from the test.
      final handle = source.openSync(mode: FileMode.write);
      handle.truncateSync(oneGigabyte);
      handle.closeSync();
      final store = MediaStore(
        root: root,
        clock: () => DateTime.utc(2026, 11, 7),
      );
      final before = ProcessInfo.currentRss;

      final imported = await store.importVideo(
        source,
        probe: _FakeVideoProbe(),
      );

      expect(File(imported.path).lengthSync(), oneGigabyte);
      // Holding the file in memory would add about 1 GB; a streamed copy
      // adds next to nothing. 64 MB leaves room for ordinary noise.
      expect(ProcessInfo.currentRss - before, lessThan(64 * 1024 * 1024));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('photo quality', () {
    File wide(String name) {
      final image = img.Image(width: 2000, height: 1000);
      img.fill(image, color: img.ColorRgb8(40, 120, 200));
      return File(p.join(tempDir.path, name))
        ..writeAsBytesSync(img.encodeJpg(image));
    }

    Future<img.Image> stored(MediaQuality quality) async {
      final store = MediaStore(
        root: root,
        clock: () => DateTime.utc(2026, 11, 7),
        photoQuality: () => quality,
      );
      final imported = await store.importPhoto(wide('${quality.name}.jpg'));
      return img.decodeImage(File(imported.path).readAsBytesSync())!;
    }

    test('Original keeps every pixel', () async {
      final photo = await stored(MediaQuality.original);
      expect((photo.width, photo.height), (2000, 1000));
    });

    test('High leaves a photo under its limit alone', () async {
      final photo = await stored(MediaQuality.high);
      expect((photo.width, photo.height), (2000, 1000));
    });

    test(
      'Smaller scales the long edge down to 1600, keeping the shape',
      () async {
        final photo = await stored(MediaQuality.smaller);
        expect((photo.width, photo.height), (1600, 800));
      },
    );

    test('a tall photo is limited by its height', () async {
      final image = img.Image(width: 1000, height: 2000);
      final source = File(p.join(tempDir.path, 'tall.jpg'))
        ..writeAsBytesSync(img.encodeJpg(image));
      final store = MediaStore(
        root: root,
        photoQuality: () => MediaQuality.smaller,
      );

      final imported = await store.importPhoto(source);
      final photo = img.decodeImage(File(imported.path).readAsBytesSync())!;

      expect((photo.width, photo.height), (800, 1600));
    });

    test('the quality is read at the time of each import', () async {
      var quality = MediaQuality.original;
      final store = MediaStore(root: root, photoQuality: () => quality);

      final first = await store.importPhoto(wide('first.jpg'));
      quality = MediaQuality.smaller;
      final second = await store.importPhoto(wide('second.jpg'));

      expect(img.decodeImage(File(first.path).readAsBytesSync())!.width, 2000);
      expect(img.decodeImage(File(second.path).readAsBytesSync())!.width, 1600);
    });
  });
}
