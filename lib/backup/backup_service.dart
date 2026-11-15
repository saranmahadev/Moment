import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import 'backup_archive.dart';
import 'backup_cipher.dart';
import 'backup_exceptions.dart';

/// What a restore did.
class RestoreSummary {
  const RestoreSummary({
    required this.logsRestored,
    required this.logsSkipped,
    required this.filesRestored,
  });

  final int logsRestored;

  /// Logs already on this phone (same id), left as they were.
  final int logsSkipped;
  final int filesRestored;
}

/// Writes and reads `.moment` backups: every log of every type, including
/// Trash, plus every media file, in one passphrase-protected file.
///
/// Restore is all or nothing. Files are decrypted and verified into a
/// staging directory first; only once the whole archive has checked out are
/// files moved into place and rows written, in one transaction. Logs whose
/// id already exists are skipped, so restoring the same file twice is safe.
class BackupService {
  BackupService({
    required AppDatabase db,
    required Directory mediaRoot,
    BackupCipher? cipher,
    DateTime Function() clock = DateTime.now,
  }) : _db = db,
       _root = mediaRoot,
       _cipher = cipher ?? BackupCipher(),
       _clock = clock;

  final AppDatabase _db;
  final Directory _root;
  final BackupCipher _cipher;
  final DateTime Function() _clock;

  /// Snapshot of the library as it would be written: rows with media paths
  /// relative to the app-private root, and the media files that exist.
  Future<BackupManifest> buildManifest() async {
    final logs = await (_db.select(
      _db.logsTable,
    )..orderBy([(l) => OrderingTerm(expression: l.id)])).get();
    final texts = await _db.select(_db.textLogsTable).get();
    final emojis = await _db.select(_db.emojiLogsTable).get();
    final photos = await _db.select(_db.photoLogsTable).get();
    final audios = await _db.select(_db.audioLogsTable).get();

    final files = <BackupFileEntry>[];
    Future<String> relativize(String absolute) async {
      final name = p.relative(absolute, from: _root.path);
      if (!BackupArchive.isSafeName(name)) {
        throw StateError('$absolute is outside the media root ${_root.path}');
      }
      final file = File(absolute);
      if (await file.exists()) {
        files.add(
          BackupFileEntry(
            name: p.posix.joinAll(p.split(name)),
            size: await file.length(),
            sha256: (await sha256.bind(file.openRead()).single).toString(),
          ),
        );
      }
      return p.posix.joinAll(p.split(name));
    }

    return BackupManifest(
      formatVersion: BackupManifest.currentFormatVersion,
      schemaVersion: _db.schemaVersion,
      createdAtMs: _clock().toUtc().millisecondsSinceEpoch,
      logs: [for (final r in logs) r.toJson()],
      textLogs: [for (final r in texts) r.toJson()],
      emojiLogs: [for (final r in emojis) r.toJson()],
      photoLogs: [
        for (final r in photos)
          {
            ...r.toJson(),
            'path': await relativize(r.path),
            'thumbnailPath': await relativize(r.thumbnailPath),
          },
      ],
      audioLogs: [
        for (final r in audios)
          {...r.toJson(), 'path': await relativize(r.path)},
      ],
      files: files,
    );
  }

  /// The complete `.moment` file, produced piece by piece.
  Stream<List<int>> exportStream({required String passphrase}) async* {
    final manifest = await buildManifest();
    yield* _cipher.encrypt(
      BackupArchive.write(
        manifest,
        (entry) => File(p.join(_root.path, entry.name)).openRead(),
      ),
      passphrase: passphrase,
    );
  }

  Future<void> exportTo(File destination, {required String passphrase}) =>
      _writeStream(destination, exportStream(passphrase: passphrase));

  /// Like `file.openWrite().addStream(bytes)`, but when [bytes] fails the
  /// original error surfaces rather than the "file closed" that closing an
  /// already-failed sink would raise.
  static Future<void> _writeStream(File file, Stream<List<int>> bytes) async {
    final sink = file.openWrite();
    try {
      await sink.addStream(bytes);
      await sink.close();
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      rethrow;
    }
  }

  Future<RestoreSummary> restoreFrom(
    File source, {
    required String passphrase,
  }) async {
    final staging = Directory(
      p.join(_root.path, '.restore-${const Uuid().v4()}'),
    );
    try {
      late BackupManifest manifest;
      late Set<String> existing;
      await BackupArchive.read(
        _cipher.decrypt(source.openRead(), passphrase: passphrase),
        onManifest: (m) async {
          manifest = m;
          existing = {
            for (final row in await _db.select(_db.logsTable).get()) row.id,
          };
        },
        onFile: (entry, bytes) async {
          final file = File(p.join(staging.path, entry.name));
          await file.parent.create(recursive: true);
          await _writeStream(file, bytes);
        },
      );

      return await _commit(manifest, existing, staging);
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  /// Moves verified files into place and writes rows for every log not
  /// already present. Called only once the entire archive has checked out.
  Future<RestoreSummary> _commit(
    BackupManifest manifest,
    Set<String> existing,
    Directory staging,
  ) async {
    final restoredIds = {
      for (final row in manifest.logs)
        if (!existing.contains(row['id'] as String)) row['id'] as String,
    };
    bool keep(Map<String, dynamic> row) =>
        restoredIds.contains(row['logId'] as String);
    String absolute(String name) => p.join(_root.path, name);

    final photoRows = manifest.photoLogs.where(keep).toList();
    final audioRows = manifest.audioLogs.where(keep).toList();
    final wantedFiles = {
      for (final r in photoRows) ...[
        r['path'] as String,
        r['thumbnailPath'] as String,
      ],
      for (final r in audioRows) r['path'] as String,
    };

    final moved = <File>[];
    try {
      for (final entry in manifest.files) {
        if (!wantedFiles.contains(entry.name)) continue;
        final target = File(absolute(entry.name));
        if (await target.exists()) continue;
        await target.parent.create(recursive: true);
        await File(p.join(staging.path, entry.name)).rename(target.path);
        moved.add(target);
      }

      await _db.transaction(() async {
        for (final row in manifest.logs) {
          if (!restoredIds.contains(row['id'] as String)) continue;
          await _db.into(_db.logsTable).insert(LogRow.fromJson(row));
        }
        for (final row in manifest.textLogs.where(keep)) {
          await _db.into(_db.textLogsTable).insert(TextLogRow.fromJson(row));
        }
        for (final row in manifest.emojiLogs.where(keep)) {
          await _db.into(_db.emojiLogsTable).insert(EmojiLogRow.fromJson(row));
        }
        for (final row in photoRows) {
          await _db
              .into(_db.photoLogsTable)
              .insert(
                PhotoLogRow.fromJson({
                  ...row,
                  'path': absolute(row['path'] as String),
                  'thumbnailPath': absolute(row['thumbnailPath'] as String),
                }),
              );
        }
        for (final row in audioRows) {
          await _db
              .into(_db.audioLogsTable)
              .insert(
                AudioLogRow.fromJson({
                  ...row,
                  'path': absolute(row['path'] as String),
                }),
              );
        }
      });
    } catch (_) {
      for (final file in moved) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }

    return RestoreSummary(
      logsRestored: restoredIds.length,
      logsSkipped: manifest.logs.length - restoredIds.length,
      filesRestored: moved.length,
    );
  }
}

/// Convenience for callers that only have a [BackupException] to show.
String describeBackupError(Object error) => switch (error) {
  BackupException(:final message) => message,
  _ => 'The backup could not be read.',
};
