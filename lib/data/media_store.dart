import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Returns a new unique id. Injected so tests can control identity.
typedef IdGenerator = String Function();

String _defaultId() => const Uuid().v4();

/// The file for an imported photo: the EXIF-stripped original and its
/// thumbnail, both under the app-private media directory.
class ImportedPhoto {
  const ImportedPhoto({required this.path, required this.thumbnailPath});

  final String path;
  final String thumbnailPath;
}

/// The file for an imported audio recording, under the app-private media
/// directory.
class ImportedAudio {
  const ImportedAudio({required this.path});

  final String path;
}

class _ProcessedPhoto {
  const _ProcessedPhoto(this.strippedBytes, this.thumbnailBytes);

  final Uint8List strippedBytes;
  final Uint8List thumbnailBytes;
}

_ProcessedPhoto _processPhoto(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    throw ArgumentError.value(bytes, 'bytes', 'not a decodable image');
  }

  // Strips every EXIF directory, GPS included: shell() in
  // design/generators/lib.py and docs/ROADMAP.md both call for photos to
  // carry no location data once imported.
  decoded.exif.clear();
  final strippedBytes = img.encodeJpg(decoded);

  final thumbnail = img.copyResize(decoded, width: MediaStore.thumbnailWidth);
  final thumbnailBytes = img.encodeJpg(thumbnail, quality: 80);

  return _ProcessedPhoto(strippedBytes, thumbnailBytes);
}

/// Copies photos into this app's private storage, under
/// `media/YYYY/MM/<id>.jpg`, stripping EXIF (including GPS) and writing a
/// thumbnail alongside. The source file is left untouched. Decoding,
/// stripping, resizing and encoding all happen off the main thread.
class MediaStore {
  MediaStore({
    required Directory root,
    DateTime Function() clock = DateTime.now,
    IdGenerator generateId = _defaultId,
  }) : _root = root,
       _clock = clock,
       _generateId = generateId;

  static const thumbnailWidth = 320;

  final Directory _root;
  final DateTime Function() _clock;
  final IdGenerator _generateId;

  Future<Directory> _monthDir() async {
    final now = _clock();
    final dir = Directory(
      p.join(
        _root.path,
        'media',
        now.year.toString(),
        now.month.toString().padLeft(2, '0'),
      ),
    );
    await dir.create(recursive: true);
    return dir;
  }

  Future<ImportedPhoto> importPhoto(File source) async {
    final originalBytes = await source.readAsBytes();
    final processed = await compute(_processPhoto, originalBytes);

    final monthDir = await _monthDir();
    final id = _generateId();
    final photoPath = p.join(monthDir.path, '$id.jpg');
    final thumbnailPath = p.join(monthDir.path, '$id-thumb.jpg');

    await File(photoPath).writeAsBytes(processed.strippedBytes);
    await File(thumbnailPath).writeAsBytes(processed.thumbnailBytes);

    return ImportedPhoto(path: photoPath, thumbnailPath: thumbnailPath);
  }

  /// Copies a recorded audio file into this app's private storage. Unlike
  /// [importPhoto], there is no decoding to do off the main thread: the
  /// bytes are copied as-is.
  Future<ImportedAudio> importAudio(File source) async {
    final monthDir = await _monthDir();
    final id = _generateId();
    final extension = p.extension(source.path);
    final audioPath = p.join(monthDir.path, '$id$extension');

    await source.copy(audioPath);

    return ImportedAudio(path: audioPath);
  }
}
