import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/backup/backup_archive.dart';
import 'package:moment/backup/backup_exceptions.dart';

Future<Uint8List> collect(Stream<List<int>> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

BackupFileEntry entryFor(String name, List<int> bytes) => BackupFileEntry(
  name: name,
  size: bytes.length,
  sha256: sha256.convert(bytes).toString(),
);

void main() {
  final photo = List<int>.generate(5000, (i) => i % 251);
  final audio = utf8.encode('not really audio, but bytes all the same');
  final manifest = BackupManifest(
    formatVersion: BackupManifest.currentFormatVersion,
    schemaVersion: 3,
    createdAtMs: 1762500000000,
    logs: [
      {'id': 'a', 'type': 'photo', 'createdAtMs': 1, 'tzOffsetMinutes': 0},
    ],
    textLogs: const [],
    emojiLogs: const [],
    photoLogs: [
      {'logId': 'a', 'path': 'media/2026/11/a.jpg', 'thumbnailPath': 'x'},
    ],
    audioLogs: const [],
    files: [
      entryFor('media/2026/11/a.jpg', photo),
      entryFor('media/2026/11/b.m4a', audio),
    ],
  );

  Stream<List<int>> open(BackupFileEntry entry) =>
      Stream.value(entry.name.endsWith('.jpg') ? photo : audio);

  test(
    'writes the manifest then every file, and reads them back in order',
    () async {
      final archive = await collect(BackupArchive.write(manifest, open));

      BackupManifest? readManifest;
      final files = <String, List<int>>{};
      await BackupArchive.read(
        Stream.value(archive),
        onManifest: (m) => readManifest = m,
        onFile: (entry, bytes) async =>
            files[entry.name] = await collect(bytes),
      );

      expect(readManifest!.toJson(), manifest.toJson());
      expect(files.keys, ['media/2026/11/a.jpg', 'media/2026/11/b.m4a']);
      expect(files['media/2026/11/a.jpg'], photo);
      expect(files['media/2026/11/b.m4a'], audio);
    },
  );

  test(
    'the manifest arrives before any file, so callers can plan first',
    () async {
      final archive = await collect(BackupArchive.write(manifest, open));
      final order = <String>[];
      await BackupArchive.read(
        Stream.value(archive),
        onManifest: (_) => order.add('manifest'),
        onFile: (entry, bytes) async {
          await collect(bytes);
          order.add(entry.name);
        },
      );
      expect(order.first, 'manifest');
      expect(order, hasLength(3));
    },
  );

  test(
    'a file whose bytes do not match the manifest hash is corruption',
    () async {
      Stream<List<int>> openWrong(BackupFileEntry entry) =>
          Stream.value(entry.name.endsWith('.jpg') ? audio : audio);
      final archive = await collect(BackupArchive.write(manifest, openWrong));

      await expectLater(
        BackupArchive.read(
          Stream.value(archive),
          onManifest: (_) {},
          onFile: (entry, bytes) => collect(bytes),
        ),
        throwsA(isA<CorruptBackupException>()),
      );
    },
  );

  test('an archive missing a listed file is corruption', () async {
    final archive = await collect(BackupArchive.write(manifest, open));
    // The second entry starts after the manifest entry and the first file;
    // cutting the tail off drops it entirely.
    final cut = archive.sublist(0, archive.length - audio.length - 40);

    await expectLater(
      BackupArchive.read(
        Stream.value(cut),
        onManifest: (_) {},
        onFile: (entry, bytes) => collect(bytes),
      ),
      throwsA(isA<CorruptBackupException>()),
    );
  });

  test(
    'a manifest from a newer format version is rejected as unreadable',
    () async {
      final newer = BackupManifest.fromJson({
        ...manifest.toJson(),
        'formatVersion': BackupManifest.currentFormatVersion + 1,
      });
      final archive = await collect(BackupArchive.write(newer, open));

      await expectLater(
        BackupArchive.read(
          Stream.value(archive),
          onManifest: (_) {},
          onFile: (entry, bytes) => collect(bytes),
        ),
        throwsA(isA<BackupFormatException>()),
      );
    },
  );

  test(
    'file names that could escape the media directory are rejected',
    () async {
      for (final bad in ['../etc/passwd', '/abs/path', 'media/../../x']) {
        final evil = BackupManifest.fromJson({
          ...manifest.toJson(),
          'files': [entryFor(bad, audio).toJson()],
        });
        final archive = await collect(
          BackupArchive.write(evil, (_) => Stream.value(audio)),
        );
        await expectLater(
          BackupArchive.read(
            Stream.value(archive),
            onManifest: (_) {},
            onFile: (entry, bytes) => collect(bytes),
          ),
          throwsA(isA<CorruptBackupException>()),
          reason: bad,
        );
      }
    },
  );
}
