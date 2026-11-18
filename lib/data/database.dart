import 'package:drift/drift.dart';

import 'tables.dart';

part 'database.g.dart';

/// The app's single local database. Opened unencrypted for now; the
/// `secure-database` chunk adds the sqlite3mc key.
@DriftDatabase(
  tables: [
    LogsTable,
    TextLogsTable,
    EmojiLogsTable,
    PhotoLogsTable,
    AudioLogsTable,
    VideoLogsTable,
    LocationLogsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSearchIndex();
      await _createFeedIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(photoLogsTable);
      }
      if (from < 3) {
        await migrator.createTable(audioLogsTable);
      }
      if (from < 4) {
        await migrator.createTable(videoLogsTable);
        await migrator.createTable(locationLogsTable);
      }
      if (from < 5) {
        await _createSearchIndex();
        await rebuildSearchIndex();
      }
      if (from < 6) {
        await _createFeedIndexes();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// What of each type is searchable: the table, and the SQL expression
  /// (over a row called `new` in a trigger, or the table itself in a
  /// rebuild) that yields its words.
  static const _searchable = {
    'text_log': ['body'],
    'emoji_log': ['label'],
    'photo_log': ['caption'],
    'video_log': ['caption'],
    'audio_log': ['title', 'note'],
    'location_log': ['name', 'note'],
  };

  static String _words(List<String> columns, String row) =>
      columns.map((column) => "coalesce($row.$column, '')").join(" || ' ' || ");

  /// Creates the full-text index (FTS5) and the triggers that keep it in
  /// step with the logs: one row per log, holding its words. Because the
  /// upkeep is in the database itself, every way a row can change is
  /// covered, restore from backup and cascading deletes included.
  Future<void> _createSearchIndex() async {
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS log_search USING fts5('
      'log_id UNINDEXED, content, '
      "tokenize = 'unicode61 remove_diacritics 2')",
    );
    for (final MapEntry(key: table, value: columns) in _searchable.entries) {
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS ${table}_search_insert '
        'AFTER INSERT ON $table BEGIN '
        'INSERT INTO log_search (log_id, content) '
        "VALUES (new.log_id, ${_words(columns, 'new')}); END",
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS ${table}_search_update '
        'AFTER UPDATE ON $table BEGIN '
        'DELETE FROM log_search WHERE log_id = old.log_id; '
        'INSERT INTO log_search (log_id, content) '
        "VALUES (new.log_id, ${_words(columns, 'new')}); END",
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS ${table}_search_delete '
        'AFTER DELETE ON $table BEGIN '
        'DELETE FROM log_search WHERE log_id = old.log_id; END',
      );
    }
  }

  /// Indexes in the order every feed reads logs (newest first, ties by
  /// id), so a page of the newest logs is read straight off the index
  /// instead of sorting the whole table. Not Drift tables, so not in
  /// backups; a restore writes rows and SQLite keeps these current.
  Future<void> _createFeedIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS log_feed_order '
      'ON log (deleted_at_ms, created_at_ms DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS log_type_feed_order '
      'ON log (type, deleted_at_ms, created_at_ms DESC, id DESC)',
    );
  }

  /// Empties the full-text index and fills it again from the logs. Used
  /// when upgrading a database that had no index, and safe to run at any
  /// time.
  Future<void> rebuildSearchIndex() => transaction(() async {
    await customStatement('DELETE FROM log_search');
    for (final MapEntry(key: table, value: columns) in _searchable.entries) {
      await customStatement(
        'INSERT INTO log_search (log_id, content) '
        'SELECT log_id, ${_words(columns, table)} FROM $table',
      );
    }
  });
}
