import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:moment/backup/backup_archive.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_exceptions.dart';
import 'package:moment/backup/backup_service.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:path/path.dart' as p;

/// One side of a backup: a database plus the app-private directory its
/// media lives under, standing in for one phone.
class _Phone {
  _Phone(Directory parent, String name, DateTime now)
    : root = Directory(p.join(parent.path, name))..createSync(),
      db = AppDatabase(NativeDatabase.memory()) {
    repo = LogRepository(db, clock: () => now);
    media = MediaStore(root: root, clock: () => now);
    backup = BackupService(
      db: db,
      mediaRoot: root,
      cipher: BackupCipher(kdfIterations: 10, chunkSize: 1024),
      clock: () => now,
    );
  }

  final Directory root;
  final AppDatabase db;
  late final LogRepository repo;
  late final MediaStore media;
  late final BackupService backup;

  Future<Map<String, Map<String, dynamic>>> rows<T extends DataClass>(
    TableInfo<Table, T> table,
  ) async {
    final all = await db.select(table).get();
    return {
      for (final row in all)
        (row.toJson()['id'] ?? row.toJson()['logId']).toString(): row.toJson(),
    };
  }

  /// Every file under the media directory, keyed by its path relative to
  /// [root], with its content hash.
  Map<String, String> mediaHashes() {
    final media = Directory(p.join(root.path, 'media'));
    if (!media.existsSync()) return {};
    return {
      for (final f in media.listSync(recursive: true).whereType<File>())
        p.relative(f.path, from: root.path): sha256
            .convert(f.readAsBytesSync())
            .toString(),
    };
  }

  Future<void> close() => db.close();
}

File _samplePhoto(String path, int seed) {
  final image = img.Image(width: 120, height: 90);
  img.fill(image, color: img.ColorRgb8(seed, 120, 60));
  return File(path)..writeAsBytesSync(img.encodeJpg(image));
}

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late Directory tempDir;
  late _Phone source;
  late _Phone target;
  late File backupFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('backup_service_test_');
    source = _Phone(tempDir, 'source', now);
    target = _Phone(tempDir, 'target', now);
    backupFile = File(p.join(tempDir.path, 'library.moment'));
  });

  tearDown(() async {
    await source.close();
    await target.close();
    tempDir.deleteSync(recursive: true);
  });

  /// A library with every built type, an edit, a backdate and a trashed log.
  Future<void> fillSource() async {
    final text = await source.repo.createText(body: 'Quiet evening.');
    await source.repo.updateText(text, body: 'Quiet evening, edited.');
    await source.repo.createText(
      body: 'Yesterday',
      createdAt: now.subtract(const Duration(days: 1)),
    );
    await source.repo.createEmoji(emoji: '😌', label: 'Calm', strength: 4);
    final trashed = await source.repo.createEmoji(emoji: '😴', strength: 2);
    await source.repo.softDelete(trashed);

    for (var i = 0; i < 2; i++) {
      final photo = await source.media.importPhoto(
        _samplePhoto(p.join(tempDir.path, 'src$i.jpg'), 100 + i),
      );
      await source.repo.createPhoto(
        path: photo.path,
        thumbnailPath: photo.thumbnailPath,
        caption: i == 0 ? 'By the lake' : null,
      );
    }

    final recording = File(p.join(tempDir.path, 'rec.m4a'))
      ..writeAsBytesSync(List.generate(3000, (i) => Random(i).nextInt(256)));
    final audio = await source.media.importAudio(recording);
    await source.repo.createAudio(
      path: audio.path,
      duration: const Duration(seconds: 42),
      peaks: [0.1, 0.5, 0.9],
      title: 'Voice note',
    );
  }

  /// The source's rows with media paths rewritten to where they would land
  /// under [root]: what a faithful restore onto another phone looks like.
  Future<Map<String, Map<String, Map<String, dynamic>>>> expectedRows(
    Directory root,
  ) async {
    String rebase(String path) =>
        p.join(root.path, p.relative(path, from: source.root.path));
    final photos = await source.rows(source.db.photoLogsTable);
    final audios = await source.rows(source.db.audioLogsTable);
    return {
      'log': await source.rows(source.db.logsTable),
      'text': await source.rows(source.db.textLogsTable),
      'emoji': await source.rows(source.db.emojiLogsTable),
      'photo': {
        for (final e in photos.entries)
          e.key: {
            ...e.value,
            'path': rebase(e.value['path'] as String),
            'thumbnailPath': rebase(e.value['thumbnailPath'] as String),
          },
      },
      'audio': {
        for (final e in audios.entries)
          e.key: {...e.value, 'path': rebase(e.value['path'] as String)},
      },
    };
  }

  Future<Map<String, Map<String, Map<String, dynamic>>>> actualRows(
    _Phone phone,
  ) async => {
    'log': await phone.rows(phone.db.logsTable),
    'text': await phone.rows(phone.db.textLogsTable),
    'emoji': await phone.rows(phone.db.emojiLogsTable),
    'photo': await phone.rows(phone.db.photoLogsTable),
    'audio': await phone.rows(phone.db.audioLogsTable),
  };

  test(
    'a backup restores every row and file onto an empty phone, byte for byte',
    () async {
      await fillSource();

      await source.backup.exportTo(backupFile, passphrase: 'correct horse');
      final summary = await target.backup.restoreFrom(
        backupFile,
        passphrase: 'correct horse',
      );

      expect(await actualRows(target), await expectedRows(target.root));
      expect(target.mediaHashes(), source.mediaHashes());
      expect(target.mediaHashes(), hasLength(5));
      expect(summary.logsRestored, 7);
      expect(summary.logsSkipped, 0);
      expect(summary.filesRestored, 5);
    },
  );

  test(
    'a wrong passphrase fails cleanly and leaves the phone untouched',
    () async {
      await fillSource();
      await source.backup.exportTo(backupFile, passphrase: 'right');
      final existing = await target.repo.createText(body: 'Already here');

      await expectLater(
        target.backup.restoreFrom(backupFile, passphrase: 'wrong'),
        throwsA(isA<WrongPassphraseException>()),
      );

      expect((await target.rows(target.db.logsTable)).keys, [existing]);
      expect(target.mediaHashes(), isEmpty);
      expect(target.root.listSync().map((e) => p.basename(e.path)), isEmpty);
    },
  );

  test('a damaged backup is rejected without touching existing data', () async {
    await fillSource();
    await source.backup.exportTo(backupFile, passphrase: 'pw');
    final bytes = backupFile.readAsBytesSync();
    bytes[bytes.length - 20] ^= 0xFF;
    backupFile.writeAsBytesSync(bytes);
    final existing = await target.repo.createText(body: 'Already here');

    await expectLater(
      target.backup.restoreFrom(backupFile, passphrase: 'pw'),
      throwsA(isA<CorruptBackupException>()),
    );

    expect((await target.rows(target.db.logsTable)).keys, [existing]);
    expect(target.mediaHashes(), isEmpty);
    expect(target.root.listSync().map((e) => p.basename(e.path)), isEmpty);
  });

  test('restore is all or nothing: a bad file late in the archive restores '
      'no rows at all', () async {
    await fillSource();
    // Build an otherwise valid backup whose last file's hash is wrong, so
    // every row and the earlier files have already streamed in by the time
    // the problem is found.
    final manifest = await source.backup.buildManifest();
    final corrupted = BackupManifest.fromJson({
      ...manifest.toJson(),
      'files': [
        for (final f in manifest.files.take(manifest.files.length - 1))
          f.toJson(),
        {...manifest.files.last.toJson(), 'sha256': 'f' * 64},
      ],
    });
    final cipher = BackupCipher(kdfIterations: 10, chunkSize: 1024);
    await backupFile.openWrite().addStream(
      cipher.encrypt(
        BackupArchive.write(
          corrupted,
          (entry) => File(p.join(source.root.path, entry.name)).openRead(),
        ),
        passphrase: 'pw',
      ),
    );

    await expectLater(
      target.backup.restoreFrom(backupFile, passphrase: 'pw'),
      throwsA(isA<CorruptBackupException>()),
    );

    expect(await target.rows(target.db.logsTable), isEmpty);
    expect(target.mediaHashes(), isEmpty);
    expect(target.root.listSync(), isEmpty);
  });

  test('restoring the same backup twice does not duplicate anything', () async {
    await fillSource();
    await source.backup.exportTo(backupFile, passphrase: 'pw');

    await target.backup.restoreFrom(backupFile, passphrase: 'pw');
    final second = await target.backup.restoreFrom(
      backupFile,
      passphrase: 'pw',
    );

    expect(second.logsRestored, 0);
    expect(second.logsSkipped, 7);
    expect(await actualRows(target), await expectedRows(target.root));
    expect(target.mediaHashes(), source.mediaHashes());
  });

  test('restoring onto a phone with other logs keeps both sets', () async {
    await fillSource();
    await source.backup.exportTo(backupFile, passphrase: 'pw');
    final own = await target.repo.createText(body: 'Mine already');

    await target.backup.restoreFrom(backupFile, passphrase: 'pw');

    final logs = await target.rows(target.db.logsTable);
    expect(logs, hasLength(8));
    expect(logs.keys, contains(own));
  });

  test('an empty library exports and restores to an empty library', () async {
    await source.backup.exportTo(backupFile, passphrase: 'pw');
    final summary = await target.backup.restoreFrom(
      backupFile,
      passphrase: 'pw',
    );

    expect(summary.logsRestored, 0);
    expect(await target.rows(target.db.logsTable), isEmpty);
    expect(target.mediaHashes(), isEmpty);
  });

  test(
    'exporting streams: the file is written in more than one piece',
    () async {
      await fillSource();
      final sizes = <int>[];
      await for (final chunk in source.backup.exportStream(passphrase: 'pw')) {
        sizes.add(chunk.length);
      }
      expect(sizes.length, greaterThan(3));
      expect(sizes.reduce(max), lessThanOrEqualTo(1024 + 5 + 16));
    },
  );

  test('export writes a file that starts with the backup magic', () async {
    await source.backup.exportTo(backupFile, passphrase: 'pw');
    expect(
      Uint8List.fromList(backupFile.readAsBytesSync().sublist(0, 8)),
      BackupCipher.magic,
    );
  });
}
