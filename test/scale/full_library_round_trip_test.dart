@Tags(['slow'])
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_service.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/domain/log_type.dart';
import 'package:path/path.dart' as p;

/// The full-library check from the roadmap: 20,000 logs of every type,
/// 3,000 of them photos with files, searched, backed up, restored onto an
/// empty phone and compared row by row and file by file.
void main() {
  test('20,000 logs: create, search, back up, restore, compare', () async {
    final dir = Directory.systemTemp.createTempSync('full_library_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final sourceRoot = Directory(p.join(dir.path, 'source'))..createSync();
    final targetRoot = Directory(p.join(dir.path, 'target'))..createSync();
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);

    var t = DateTime.utc(2021);
    final repo = LogRepository(source, clock: () => t);
    final media = Directory(p.join(sourceRoot.path, 'media'))..createSync();
    await source.transaction(() async {
      for (var i = 0; i < 20000; i++) {
        t = DateTime.utc(2021).add(Duration(minutes: 97 * i));
        if (i % 20 < 3) {
          final file = File(p.join(media.path, 'p$i.jpg'))
            ..writeAsBytesSync(List.generate(600, (b) => (b * i) % 256));
          final thumb = File(p.join(media.path, 'p$i-t.jpg'))
            ..writeAsBytesSync(List.generate(80, (b) => (b + i) % 256));
          await repo.createPhoto(
            path: file.path,
            thumbnailPath: thumb.path,
            caption: i % 7 == 0 ? 'harbour $i' : null,
          );
        } else {
          switch (i % 4) {
            case 0:
              await repo.createText(body: 'Day $i by the harbour');
            case 1:
              await repo.createEmoji(emoji: '😌', label: 'Calm', strength: 3);
            case 2:
              await repo.createLocation(
                latitude: 12,
                longitude: 77,
                name: 'Pier $i',
              );
            default:
              await repo.createText(body: 'Plain day $i');
          }
        }
      }
    });
    expect((await repo.watchTypeSummaries().first)[LogType.photo]!.count, 3000);

    final watch = Stopwatch()..start();
    final hits = await repo.search('harbour');
    expect(watch.elapsedMilliseconds, lessThan(200));
    expect(hits, hasLength(200)); // the search's own limit
    expect(hits.first.createdAt.isAfter(hits.last.createdAt), isTrue);

    final backup = File(p.join(dir.path, 'library.moment'));
    await BackupService(
      db: source,
      mediaRoot: sourceRoot,
      cipher: BackupCipher(kdfIterations: 10),
    ).exportTo(backup, passphrase: 'pass');
    final summary = await BackupService(
      db: target,
      mediaRoot: targetRoot,
      cipher: BackupCipher(kdfIterations: 10),
    ).restoreFrom(backup, passphrase: 'pass');
    expect(summary.logsRestored, 20000);
    expect(summary.filesRestored, 6000);

    Future<List<Map<String, Object?>>> rows<T extends DataClass>(
      AppDatabase db,
      TableInfo<Table, T> table,
      Directory root,
    ) async => [
      for (final row
          in (await db.select(table).get())..sort(
            (a, b) => '${a.toJson().values.first}'.compareTo(
              '${b.toJson().values.first}',
            ),
          ))
        {
          for (final MapEntry(:key, :value) in row.toJson().entries)
            key: value is String && value.startsWith(root.path)
                ? p.relative(value, from: root.path)
                : value,
        },
    ];
    Future<void> same<T extends DataClass>(
      TableInfo<Table, T> from,
      TableInfo<Table, T> to,
    ) async => expect(
      await rows(target, to, targetRoot),
      await rows(source, from, sourceRoot),
    );
    await same(source.logsTable, target.logsTable);
    await same(source.textLogsTable, target.textLogsTable);
    await same(source.emojiLogsTable, target.emojiLogsTable);
    await same(source.photoLogsTable, target.photoLogsTable);
    await same(source.locationLogsTable, target.locationLogsTable);

    String hashes(Directory root) {
      final files =
          Directory(p.join(root.path, 'media'))
              .listSync(recursive: true)
              .whereType<File>()
              .map(
                (f) =>
                    '${p.relative(f.path, from: root.path)} '
                    '${sha256.convert(f.readAsBytesSync())}',
              )
              .toList()
            ..sort();
      return files.join('\n');
    }

    expect(hashes(targetRoot), hashes(sourceRoot));
    // The restored library searches the same.
    expect(
      (await LogRepository(target).search('harbour')).map((l) => l.id),
      hits.map((l) => l.id),
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
