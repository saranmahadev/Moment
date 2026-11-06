import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/secure_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  late Directory tempDir;
  late String path;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('secure-database-test');
    path = p.join(tempDir.path, 'moment.db');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('a freshly opened database is usable', () async {
    final db = AppDatabase(openEncryptedDatabase(path, 'a'.padRight(64, 'a')));
    await db.customSelect('PRAGMA user_version').getSingle();
    await db.close();
  });

  test(
    'data written with the key is readable after reopening with it',
    () async {
      final key = 'b'.padRight(64, 'b');

      var db = AppDatabase(openEncryptedDatabase(path, key));
      await db
          .into(db.logsTable)
          .insert(
            LogsTableCompanion.insert(
              id: '1',
              type: 'text',
              createdAtMs: 0,
              tzOffsetMinutes: 0,
            ),
          );
      await db.close();

      db = AppDatabase(openEncryptedDatabase(path, key));
      final rows = await db.select(db.logsTable).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, '1');
      await db.close();
    },
  );

  test('the file cannot be read by plain sqlite3 without the key', () async {
    final db = AppDatabase(openEncryptedDatabase(path, 'c'.padRight(64, 'c')));
    await db.customSelect('PRAGMA user_version').getSingle();
    await db.close();

    final plain = sqlite3.sqlite3.open(path);
    addTearDown(plain.close);
    expect(
      () => plain.select('SELECT * FROM sqlite_master'),
      throwsA(isA<sqlite3.SqliteException>()),
    );
  });

  test('a wrong key fails to read existing data', () async {
    final db = AppDatabase(openEncryptedDatabase(path, 'd'.padRight(64, 'd')));
    await db.customSelect('PRAGMA user_version').getSingle();
    await db.close();

    final wrongKeyDb = sqlite3.sqlite3.open(path);
    addTearDown(wrongKeyDb.close);
    wrongKeyDb.execute("PRAGMA key = '${'e'.padRight(64, 'e')}'");
    expect(
      () => wrongKeyDb.select('SELECT * FROM sqlite_master'),
      throwsA(isA<sqlite3.SqliteException>()),
    );
  });
}
