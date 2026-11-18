import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/journal_opener.dart';
import 'package:moment/data/key_store.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/secure_database.dart';
import 'package:path/path.dart' as p;

class _MemoryKeys implements KeyStorage {
  _MemoryKeys([this.key]);
  String? key;

  @override
  Future<String?> read() async => key;

  @override
  Future<void> write(String key) async => this.key = key;
}

void main() {
  late Directory dir;
  late File file;
  final now = DateTime(2026, 11, 18, 21, 5, 9);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('journal_opener_');
    file = File(p.join(dir.path, 'moment.db'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  JournalOpener opener(KeyStorage keys) =>
      JournalOpener(file: file, keys: keys, clock: () => now);

  /// A journal on disk, written with [key], holding one text log.
  Future<void> writeJournal(String key) async {
    final db = AppDatabase(openEncryptedDatabase(file.path, key));
    await LogRepository(db).createText(body: 'kept safe');
    await db.close();
  }

  test('first launch: makes a key and an empty journal', () async {
    final keys = _MemoryKeys();
    final opening = await opener(keys).open();
    expect(opening, isA<JournalOpened>());
    expect(keys.key, hasLength(64));
    await (opening as JournalOpened).db.close();
    expect(file.existsSync(), isTrue);
  });

  test('a journal and its key: opens with everything in it', () async {
    final keys = _MemoryKeys('a' * 64);
    await writeJournal(keys.key!);
    final opening = await opener(keys).open() as JournalOpened;
    final feed = await LogRepository(opening.db).watchFeed().first;
    expect(feed, hasLength(1));
    await opening.db.close();
  });

  test('a journal with no key: blocked, and nothing is changed', () async {
    await writeJournal('b' * 64);
    final before = file.readAsBytesSync();
    final keys = _MemoryKeys();

    final opening = await opener(keys).open();

    expect(opening, isA<JournalBlocked>());
    expect((opening as JournalBlocked).problem, JournalProblem.keyMissing);
    // No new key was made: one made now would hide the problem for good.
    expect(keys.key, isNull);
    expect(file.readAsBytesSync(), before);
  });

  test('a journal the key does not open: blocked, nothing changed', () async {
    await writeJournal('c' * 64);
    final before = file.readAsBytesSync();
    final keys = _MemoryKeys('d' * 64);

    final opening = await opener(keys).open();

    expect((opening as JournalBlocked).problem, JournalProblem.unreadable);
    expect(keys.key, 'd' * 64);
    expect(file.readAsBytesSync(), before);
  });

  test(
    'starting fresh keeps the old file aside and opens an empty journal',
    () async {
      await writeJournal('e' * 64);
      final before = file.readAsBytesSync();
      final keys = _MemoryKeys();
      final o = opener(keys);
      expect(await o.open(), isA<JournalBlocked>());

      final db = await o.startFresh();

      final aside = File(
        p.join(dir.path, 'moment-unopened-20261118-210509.db'),
      );
      expect(aside.readAsBytesSync(), before);
      expect(keys.key, hasLength(64));
      expect(await LogRepository(db).watchFeed().first, isEmpty);
      await LogRepository(db).createText(body: 'a new start');
      await db.close();

      // The new journal opens again with the new key.
      final again = await opener(keys).open() as JournalOpened;
      expect(await LogRepository(again.db).watchFeed().first, hasLength(1));
      await again.db.close();
    },
  );

  test('starting fresh twice never overwrites an earlier file', () async {
    await writeJournal('f' * 64);
    final keys = _MemoryKeys();
    final first = await opener(keys).startFresh();
    await first.close();
    keys.key = null; // lost again
    final second = await opener(keys).startFresh();
    await second.close();

    final aside = dir
        .listSync()
        .map((e) => p.basename(e.path))
        .where((n) => n.startsWith('moment-unopened-'))
        .toList();
    expect(aside, hasLength(2));
  });
}
