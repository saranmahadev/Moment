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
    'INSERT INTO log (id, type, created_at_ms, tz_offset_minutes) '
    "VALUES ('from-0.1.0', 'text', 0, 0)",
  );
  raw.execute(
    'INSERT INTO text_log (log_id, body) '
    "VALUES ('from-0.1.0', 'written before the upgrade')",
  );
  raw.execute('PRAGMA user_version = 1');
  raw.close();
}

/// Builds a real on-disk database file matching the schema as it shipped
/// in 0.2.0 (schemaVersion 2: adds photo_log over 0.1.0's schema; no
/// audio_log yet), with one photo log already in it.
void _writeV2Database(String path) {
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
    CREATE TABLE photo_log (
      log_id TEXT NOT NULL PRIMARY KEY REFERENCES log(id) ON DELETE CASCADE,
      path TEXT NOT NULL,
      thumbnail_path TEXT NOT NULL,
      caption TEXT
    );
  ''');
  raw.execute(
    'INSERT INTO log (id, type, created_at_ms, tz_offset_minutes) '
    "VALUES ('from-0.2.0', 'photo', 0, 0)",
  );
  raw.execute(
    'INSERT INTO photo_log (log_id, path, thumbnail_path) '
    "VALUES ('from-0.2.0', '/a.jpg', '/a-thumb.jpg')",
  );
  raw.execute('PRAGMA user_version = 2');
  raw.close();
}

/// Builds a real on-disk database file matching the schema as it shipped
/// in 0.2.0 (schemaVersion 3: log, text_log, emoji_log, photo_log and
/// audio_log; no video_log or location_log), with one log of each type.
void _writeV3Database(String path) {
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
    CREATE TABLE photo_log (
      log_id TEXT NOT NULL PRIMARY KEY REFERENCES log(id) ON DELETE CASCADE,
      path TEXT NOT NULL,
      thumbnail_path TEXT NOT NULL,
      caption TEXT
    );
    CREATE TABLE audio_log (
      log_id TEXT NOT NULL PRIMARY KEY REFERENCES log(id) ON DELETE CASCADE,
      path TEXT NOT NULL,
      duration_ms INTEGER NOT NULL,
      peaks TEXT NOT NULL,
      title TEXT,
      note TEXT
    );
  ''');
  for (final (id, type) in [
    ('t', 'text'),
    ('e', 'emoji'),
    ('p', 'photo'),
    ('a', 'audio'),
  ]) {
    raw.execute(
      'INSERT INTO log (id, type, created_at_ms, tz_offset_minutes) '
      "VALUES ('$id', '$type', 0, 0)",
    );
  }
  raw.execute("INSERT INTO text_log VALUES ('t', 'written in 0.2.0')");
  raw.execute("INSERT INTO emoji_log VALUES ('e', '😌', 'Calm', 4)");
  raw.execute("INSERT INTO photo_log VALUES ('p', '/a.jpg', '/a-t.jpg', NULL)");
  raw.execute(
    "INSERT INTO audio_log VALUES ('a', '/a.m4a', 42000, '[0.1,0.5]', "
    "'Voice note', NULL)",
  );
  raw.execute('PRAGMA user_version = 3');
  raw.close();
}

/// A database as 0.3.0 left it (schemaVersion 4): the 0.2.0 tables plus
/// video_log and location_log, with one log of every type, and no search
/// index.
void _writeV4Database(String path) {
  _writeV3Database(path);
  final raw = sqlite3.sqlite3.open(path);
  raw.execute('''
    CREATE TABLE video_log (
      log_id TEXT NOT NULL PRIMARY KEY REFERENCES log(id) ON DELETE CASCADE,
      path TEXT NOT NULL,
      poster_path TEXT NOT NULL,
      duration_ms INTEGER NOT NULL,
      caption TEXT
    );
    CREATE TABLE location_log (
      log_id TEXT NOT NULL PRIMARY KEY REFERENCES log(id) ON DELETE CASCADE,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      accuracy_m REAL,
      name TEXT,
      note TEXT
    );
  ''');
  raw.execute(
    'INSERT INTO log (id, type, created_at_ms, tz_offset_minutes) '
    "VALUES ('v', 'video', 0, 0), ('l', 'location', 0, 0)",
  );
  raw.execute(
    "INSERT INTO video_log VALUES ('v', '/v.mp4', '/v.jpg', 48000, "
    "'Walk to the station')",
  );
  raw.execute(
    "INSERT INTO location_log VALUES ('l', 12.5, 77.25, 12, "
    "'Favourite bench', 'by the lake')",
  );
  raw.execute('PRAGMA user_version = 4');
  raw.close();
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

  test(
    'a 0.2.0 database upgrades to add audio_log, with every existing log intact',
    () async {
      final dir = Directory.systemTemp.createTempSync('migration_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final dbPath = p.join(dir.path, 'moment.db');
      _writeV2Database(dbPath);

      final db = AppDatabase(NativeDatabase(File(dbPath)));
      final repo = LogRepository(db);

      final existing = await repo.getById('from-0.2.0');
      expect(existing, isA<PhotoLog>());
      expect((existing! as PhotoLog).path, '/a.jpg');

      final audioId = await repo.createAudio(
        path: '/media/2026/11/new.m4a',
        duration: const Duration(seconds: 5),
        peaks: [0.1, 0.2],
      );
      expect(await repo.getById(audioId), isA<AudioLog>());

      await db.close();
    },
  );

  test(
    'a 0.2.0 database upgrades to add video_log and location_log, with every '
    'existing log intact',
    () async {
      final dir = Directory.systemTemp.createTempSync('migration_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final dbPath = p.join(dir.path, 'moment.db');
      _writeV3Database(dbPath);

      final db = AppDatabase(NativeDatabase(File(dbPath)));
      final repo = LogRepository(db);

      expect((await repo.getById('t') as TextLog).body, 'written in 0.2.0');
      expect((await repo.getById('e') as EmojiLog).label, 'Calm');
      expect((await repo.getById('p') as PhotoLog).path, '/a.jpg');
      final audio = await repo.getById('a') as AudioLog;
      expect(audio.duration, const Duration(seconds: 42));
      expect(audio.peaks, [0.1, 0.5]);
      expect(await repo.getAll(), hasLength(4));

      final videoId = await repo.createVideo(
        path: '/new.mp4',
        posterPath: '/new.jpg',
        duration: const Duration(seconds: 3),
      );
      final locationId = await repo.createLocation(latitude: 1.5, longitude: 2);
      expect(await repo.getById(videoId), isA<VideoLog>());
      expect(await repo.getById(locationId), isA<LocationLog>());

      await db.close();
    },
  );

  test('a 0.1.0 database upgrades straight to the current schema', () async {
    final dir = Directory.systemTemp.createTempSync('migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final dbPath = p.join(dir.path, 'moment.db');
    _writeV1Database(dbPath);

    final db = AppDatabase(NativeDatabase(File(dbPath)));
    final repo = LogRepository(db);

    expect(await repo.getById('from-0.1.0'), isA<TextLog>());
    final id = await repo.createLocation(latitude: 1, longitude: 2);
    expect(await repo.getById(id), isA<LocationLog>());

    await db.close();
  });

  test(
    'a 0.3.0 database opens in 0.4.0 intact, and is searchable at once',
    () async {
      final dir = Directory.systemTemp.createTempSync('migration_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final dbPath = p.join(dir.path, 'moment.db');
      _writeV4Database(dbPath);

      final db = AppDatabase(NativeDatabase(File(dbPath)));
      final repo = LogRepository(db);

      // Nothing lost.
      expect(await repo.getAll(), hasLength(6));
      expect((await repo.getById('t') as TextLog).body, 'written in 0.2.0');
      final video = await repo.getById('v') as VideoLog;
      expect(video.caption, 'Walk to the station');
      expect(video.duration, const Duration(seconds: 48));
      final place = await repo.getById('l') as LocationLog;
      expect((place.latitude, place.longitude), (12.5, 77.25));
      expect(place.note, 'by the lake');

      // Logs written before the index existed are in it.
      expect((await repo.search('written')).single, isA<TextLog>());
      expect((await repo.search('calm')).single, isA<EmojiLog>());
      expect((await repo.search('voice')).single, isA<AudioLog>());
      expect((await repo.search('station')).single, isA<VideoLog>());
      expect((await repo.search('bench')).single, isA<LocationLog>());
      expect((await repo.search('lake')).single, isA<LocationLog>());

      // And new ones join it.
      await repo.createText(body: 'written in 0.4.0');
      expect(await repo.search('written'), hasLength(2));

      await db.close();
    },
  );

  test('a 0.1.0 database gains the search index on the way up', () async {
    final dir = Directory.systemTemp.createTempSync('migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final dbPath = p.join(dir.path, 'moment.db');
    _writeV1Database(dbPath);

    final db = AppDatabase(NativeDatabase(File(dbPath)));
    final repo = LogRepository(db);

    expect(await repo.search('written'), hasLength(1));

    await db.close();
  });

  test('opening an upgraded database again changes nothing', () async {
    final dir = Directory.systemTemp.createTempSync('migration_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final dbPath = p.join(dir.path, 'moment.db');
    _writeV4Database(dbPath);

    final first = AppDatabase(NativeDatabase(File(dbPath)));
    await LogRepository(first).search('bench');
    await first.close();
    final second = AppDatabase(NativeDatabase(File(dbPath)));
    final repo = LogRepository(second);

    expect(await repo.getAll(), hasLength(6));
    expect(await repo.search('bench'), hasLength(1));

    await second.close();
  });
}
