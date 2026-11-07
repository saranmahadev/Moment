import 'dart:io';

import 'package:drift/native.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/domain/log.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:flutter_test/flutter_test.dart';

/// Builds a real on-disk database file matching the schema as it shipped
/// in 0.1.0 (schemaVersion 1: log, text_log, emoji_log; no photo_log), with
/// one text log already in it, standing in for a real user's database from
/// before this upgrade.
void _writeV1Database(String path) {
  final raw = sqlite3.sqlite3.open(path);
  raw.execute('''
    CREATE TABLE log (
      id TEXT NOT NULL PRIMARY KEY,
      type TEXT NOT NULL,
      created_at_ms INTEGER NOT NULL,
      tz_offset_minutes INTEGER NOT NULL,
      edited_at_ms INTEGER,
      deleted_at_ms INTEGER
    );
    CREATE TABLE text_log (
      log_id TEXT NOT NULL PRIMARY KEY REFERENCES log(id) ON DELETE CASCADE,
      body TEXT NOT NULL
    );
    CREATE TABLE emoji_log (
      log_id TEXT NOT NULL PRIMARY KEY REFERENCES log(id) ON DELETE CASCADE,
      emoji TEXT NOT NULL,
      label TEXT,
      strength INTEGER NOT NULL
    );
  ''');
  raw.execute(
    "INSERT INTO log (id, type, created_at_ms, tz_offset_minutes) "
    "VALUES ('from-0.1.0', 'text', 0, 0)",
  );
  raw.execute(
    "INSERT INTO text_log (log_id, body) "
    "VALUES ('from-0.1.0', 'written before the upgrade')",
  );
  raw.execute('PRAGMA user_version = 1');
  raw.dispose();
}

void main() {
  test(
    'a 0.1.0 database upgrades to add photo_log, with every existing log intact',
    () async {
      final dir = Directory.systemTemp.createTempSync('migration_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final dbPath = p.join(dir.path, 'moment.db');
      _writeV1Database(dbPath);

      final db = AppDatabase(NativeDatabase(File(dbPath)));
      final repo = LogRepository(db);

      final existing = await repo.getById('from-0.1.0');
      expect(existing, isA<TextLog>());
      expect((existing! as TextLog).body, 'written before the upgrade');

      final photoId = await repo.createPhoto(
        path: '/media/2026/11/new.jpg',
        thumbnailPath: '/media/2026/11/new-thumb.jpg',
      );
      expect(await repo.getById(photoId), isA<PhotoLog>());

      await db.close();
    },
  );
}
