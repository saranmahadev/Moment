import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'backup_exceptions.dart';

/// One media file inside a backup: its path relative to the app-private
/// root (e.g. `media/2026/11/<id>.jpg`), size and SHA-256 hex digest.
class BackupFileEntry {
  const BackupFileEntry({
    required this.name,
    required this.size,
    required this.sha256,
  });

  factory BackupFileEntry.fromJson(Map<String, dynamic> json) =>
      BackupFileEntry(
        name: json['name'] as String,
        size: json['size'] as int,
        sha256: json['sha256'] as String,
      );

  final String name;
  final int size;
  final String sha256;

  Map<String, dynamic> toJson() => {
    'name': name,
    'size': size,
    'sha256': sha256,
  };
}

/// What a backup contains: every table's rows (as Drift's JSON maps, with
/// media paths made relative to the app-private root) and the list of media
/// files that follow it in the archive, in order.
class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.createdAtMs,
    required this.logs,
    required this.textLogs,
    required this.emojiLogs,
    required this.photoLogs,
    required this.audioLogs,
    required this.videoLogs,
    required this.locationLogs,
    required this.files,
  });

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    // Lists added in later format versions are absent from older backups.
    List<Map<String, dynamic>> rows(String key) => [
      for (final row in json[key] as List? ?? const [])
        (row as Map).cast<String, dynamic>(),
    ];
    return BackupManifest(
      formatVersion: json['formatVersion'] as int,
      schemaVersion: json['schemaVersion'] as int,
      createdAtMs: json['createdAtMs'] as int,
      logs: rows('logs'),
      textLogs: rows('textLogs'),
      emojiLogs: rows('emojiLogs'),
      photoLogs: rows('photoLogs'),
      audioLogs: rows('audioLogs'),
      videoLogs: rows('videoLogs'),
      locationLogs: rows('locationLogs'),
      files: [
        for (final f in json['files'] as List)
          BackupFileEntry.fromJson((f as Map).cast<String, dynamic>()),
      ],
    );
  }

  /// Bumped whenever the manifest or archive layout changes in a way an
  /// older app could not read; older versions stay readable here.
  ///
  /// 1: text, emoji, photo and audio (0.2.0).
  /// 2: adds video and location (0.3.0).
  static const currentFormatVersion = 2;

  final int formatVersion;
  final int schemaVersion;
  final int createdAtMs;
  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> textLogs;
  final List<Map<String, dynamic>> emojiLogs;
  final List<Map<String, dynamic>> photoLogs;
  final List<Map<String, dynamic>> audioLogs;
  final List<Map<String, dynamic>> videoLogs;
  final List<Map<String, dynamic>> locationLogs;
  final List<BackupFileEntry> files;

  Map<String, dynamic> toJson() => {
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'createdAtMs': createdAtMs,
    'logs': logs,
    'textLogs': textLogs,
    'emojiLogs': emojiLogs,
    'photoLogs': photoLogs,
    'audioLogs': audioLogs,
    'videoLogs': videoLogs,
    'locationLogs': locationLogs,
    'files': [for (final f in files) f.toJson()],
  };
}

/// The plaintext inside a `.moment` file: a sequence of entries, the
/// manifest first and then each listed file in manifest order.
///
/// ```
/// entry
///   kind       1   0x01 manifest (JSON, UTF-8), 0x02 file
///   name       2 + n   uint16 length, then UTF-8 name
///   size       8   uint64 byte length of the body
///   body    size
/// ```
///
/// Reading verifies that the manifest comes first and is a version this
/// app understands, that files arrive in manifest order with the listed
/// size and hash, and that no listed file is missing. Names are rejected
/// if they could reach outside the directory they are restored into.
abstract final class BackupArchive {
  static const _kindManifest = 0x01;
  static const _kindFile = 0x02;
  static const _manifestName = 'manifest.json';

  static Stream<List<int>> write(
    BackupManifest manifest,
    Stream<List<int>> Function(BackupFileEntry entry) openFile,
  ) async* {
    final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
    yield _entryHeader(_kindManifest, _manifestName, manifestBytes.length);
    yield manifestBytes;
    for (final entry in manifest.files) {
      yield _entryHeader(_kindFile, entry.name, entry.size);
      yield* openFile(entry);
    }
  }

  static Uint8List _entryHeader(int kind, String name, int size) {
    final nameBytes = utf8.encode(name);
    final header = Uint8List(1 + 2 + nameBytes.length + 8);
    final data = ByteData.sublistView(header);
    header[0] = kind;
    data.setUint16(1, nameBytes.length);
    header.setAll(3, nameBytes);
    data.setUint64(3 + nameBytes.length, size);
    return header;
  }

  /// Walks an archive. [onManifest] is awaited before any file is read;
  /// [onFile] must drain [bytes] (exactly `entry.size` of them) before it
  /// completes.
  static Future<void> read(
    Stream<List<int>> archive, {
    required FutureOr<void> Function(BackupManifest manifest) onManifest,
    required Future<void> Function(
      BackupFileEntry entry,
      Stream<List<int>> bytes,
    )
    onFile,
  }) async {
    final reader = ChunkedStreamReader(archive);
    try {
      final first = await _readEntryHeader(reader);
      if (first == null || first.kind != _kindManifest) {
        throw const CorruptBackupException(
          'The backup does not start with its manifest.',
        );
      }
      final manifestBytes = await reader.readBytes(first.size);
      if (manifestBytes.length < first.size) {
        throw const CorruptBackupException('The manifest is cut short.');
      }
      final BackupManifest manifest;
      try {
        manifest = BackupManifest.fromJson(
          (jsonDecode(utf8.decode(manifestBytes)) as Map)
              .cast<String, dynamic>(),
        );
      } on Object {
        throw const CorruptBackupException('The manifest cannot be read.');
      }
      if (manifest.formatVersion > BackupManifest.currentFormatVersion) {
        throw const BackupFormatException(
          'This backup was made by a newer version of Moment.',
        );
      }
      for (final entry in manifest.files) {
        if (!isSafeName(entry.name)) {
          throw CorruptBackupException(
            'The backup lists an invalid file name: ${entry.name}',
          );
        }
      }
      await onManifest(manifest);

      for (final expected in manifest.files) {
        final header = await _readEntryHeader(reader);
        if (header == null ||
            header.kind != _kindFile ||
            header.name != expected.name ||
            header.size != expected.size) {
          throw CorruptBackupException(
            'The backup is missing or misplaces ${expected.name}.',
          );
        }
        final digestSink = _DigestSink();
        final hasher = sha256.startChunkedConversion(digestSink);
        var received = 0;
        await onFile(
          expected,
          reader.readStream(expected.size).map((chunk) {
            hasher.add(chunk);
            received += chunk.length;
            return chunk;
          }),
        );
        hasher.close();
        if (received != expected.size ||
            digestSink.digest.toString() != expected.sha256) {
          throw CorruptBackupException(
            '${expected.name} does not match the backup manifest.',
          );
        }
      }
      if ((await reader.readBytes(1)).isNotEmpty) {
        throw const CorruptBackupException(
          'The backup has data after its last file.',
        );
      }
    } finally {
      await reader.cancel();
    }
  }

  /// A name is safe when it is relative and never steps up a directory, so
  /// joining it onto a root cannot leave that root.
  static bool isSafeName(String name) {
    if (name.isEmpty ||
        p.posix.isAbsolute(name) ||
        p.windows.isAbsolute(name)) {
      return false;
    }
    final segments = p.posix.split(name);
    return !segments.any((s) => s == '..' || s == '.' || s.isEmpty) &&
        !name.contains('\\');
  }

  static Future<({int kind, String name, int size})?> _readEntryHeader(
    ChunkedStreamReader<int> reader,
  ) async {
    final fixed = await reader.readBytes(3);
    if (fixed.isEmpty) return null;
    if (fixed.length < 3) {
      throw const CorruptBackupException('An entry header is cut short.');
    }
    final nameLength = ByteData.sublistView(fixed).getUint16(1);
    final nameBytes = await reader.readBytes(nameLength);
    final sizeBytes = await reader.readBytes(8);
    if (nameBytes.length < nameLength || sizeBytes.length < 8) {
      throw const CorruptBackupException('An entry header is cut short.');
    }
    return (
      kind: fixed[0],
      name: utf8.decode(nameBytes),
      size: ByteData.sublistView(sizeBytes).getUint64(0),
    );
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _digest;

  Digest get digest => _digest!;

  @override
  void add(Digest data) => _digest = data;

  @override
  void close() {}
}
