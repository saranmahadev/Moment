import 'package:drift/drift.dart';

import 'tables.dart';

part 'database.g.dart';

/// The app's single local database. Opened unencrypted for now; the
/// `secure-database` chunk adds the sqlite3mc key.
@DriftDatabase(
  tables: [LogsTable, TextLogsTable, EmojiLogsTable, PhotoLogsTable],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(photoLogsTable);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
