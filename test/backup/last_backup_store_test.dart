import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/backup/last_backup_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('last_backup_store_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('reads null when nothing has been written', () async {
    final store = FileLastBackupStore(File(p.join(tempDir.path, 'b.json')));
    expect(await store.read(), isNull);
  });

  test('a written time survives a fresh store on the same file', () async {
    final file = File(p.join(tempDir.path, 'b.json'));
    await FileLastBackupStore(file).write(DateTime.utc(2026, 11, 7, 10));

    expect(
      await FileLastBackupStore(file).read(),
      DateTime.utc(2026, 11, 7, 10),
    );
  });

  test('an unreadable file reads as null rather than crashing', () async {
    final file = File(p.join(tempDir.path, 'b.json'))..writeAsStringSync('{');
    expect(await FileLastBackupStore(file).read(), isNull);
  });
}
