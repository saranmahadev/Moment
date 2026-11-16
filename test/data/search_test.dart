import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_service.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;
  late LogRepository repo;
  var tick = 0;

  /// Each log a minute after the one before, so "newest first" is defined.
  DateTime next() =>
      DateTime.utc(2026, 11, 6, 8).add(Duration(minutes: tick++));

  setUp(() {
    tick = 0;
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: next);
  });

  tearDown(() => db.close());

  Future<List<String>> bodies(String query, {LogType? type}) async => [
    for (final log in await repo.search(query, type: type))
      (log as TextLog).body,
  ];

  Future<int> indexed() async =>
      (await db
              .customSelect('SELECT count(*) AS n FROM log_search')
              .getSingle())
          .read<int>('n');

  group('matching', () {
    test('finds a word wherever it sits, whatever its case', () async {
      await repo.createText(body: 'Morning light on the balcony.');
      await repo.createText(body: 'Nothing to see here');

      expect(await bodies('balcony'), ['Morning light on the balcony.']);
      expect(await bodies('BALCONY'), ['Morning light on the balcony.']);
      expect(await bodies('light'), ['Morning light on the balcony.']);
    });

    test('matches from the start of a word, as you type', () async {
      await repo.createText(body: 'Morning light on the balcony.');

      expect(await bodies('balc'), hasLength(1));
      expect(await bodies('b'), hasLength(1));
      // Not from the middle of a word.
      expect(await bodies('cony'), isEmpty);
    });

    test('ignores accents', () async {
      await repo.createText(body: 'Café by the río');

      expect(await bodies('cafe'), hasLength(1));
      expect(await bodies('rio'), hasLength(1));
    });

    test('every word must be there, in any order', () async {
      await repo.createText(body: 'Morning light on the balcony.');
      await repo.createText(body: 'Evening light in the hall.');

      expect(await bodies('balcony morning'), [
        'Morning light on the balcony.',
      ]);
      expect(await bodies('light'), hasLength(2));
      expect(await bodies('light kitchen'), isEmpty);
    });

    test('newest first', () async {
      await repo.createText(body: 'first walk');
      await repo.createText(body: 'second walk');
      await repo.createText(body: 'third walk');

      expect(await bodies('walk'), ['third walk', 'second walk', 'first walk']);
    });

    test('a blank or wordless query finds nothing, and never throws', () async {
      await repo.createText(body: 'anything');

      for (final query in ['', '   ', '"', '***', ':-)', 'a"b', "it's", '(x']) {
        expect(await repo.search(query), isA<List<Log>>(), reason: query);
      }
      expect(await repo.search(''), isEmpty);
      expect(await repo.search('  " * '), isEmpty);
      expect(await bodies("it's"), isEmpty);
    });

    test('at most the limit asked for', () async {
      for (var i = 0; i < 5; i++) {
        await repo.createText(body: 'walk $i');
      }

      expect(await repo.search('walk', limit: 3), hasLength(3));
    });
  });

  test('results match across all six types', () async {
    await repo.createText(body: 'Sat on the balcony');
    await repo.createEmoji(emoji: '😌', label: 'Balcony calm', strength: 4);
    await repo.createPhoto(
      path: '/a.jpg',
      thumbnailPath: '/a-t.jpg',
      caption: 'Light on the balcony',
    );
    await repo.createVideo(
      path: '/v.mp4',
      posterPath: '/v.jpg',
      duration: const Duration(seconds: 3),
      caption: 'Rain from the balcony',
    );
    await repo.createAudio(
      path: '/a.m4a',
      duration: const Duration(seconds: 3),
      peaks: const [0.1],
      title: 'Balcony thoughts',
    );
    await repo.createLocation(latitude: 1, longitude: 2, name: 'Home balcony');
    // And one that should not match, of each kind of text.
    await repo.createAudio(
      path: '/b.m4a',
      duration: const Duration(seconds: 3),
      peaks: const [0.1],
      title: 'Kitchen',
      note: 'nothing here',
    );

    final found = await repo.search('balcony');

    expect({for (final log in found) log.type}, LogType.values.toSet());
    expect(found, hasLength(6));
  });

  test('notes are searched too', () async {
    await repo.createAudio(
      path: '/a.m4a',
      duration: const Duration(seconds: 3),
      peaks: const [0.1],
      title: 'Morning',
      note: 'recorded on the terrace',
    );
    final place = await repo.createLocation(latitude: 1, longitude: 2);
    await repo.updateLocation(place, name: null, note: 'quiet terrace');

    expect(await repo.search('terrace'), hasLength(2));
  });

  test('a type filter keeps only that type', () async {
    await repo.createText(body: 'balcony words');
    await repo.createEmoji(emoji: '😌', label: 'Balcony calm', strength: 4);

    final found = await repo.search('balcony', type: LogType.emoji);

    expect(found.single, isA<EmojiLog>());
  });

  group('the index follows the logs', () {
    test('deleted logs never appear; restored ones come back', () async {
      final id = await repo.createText(body: 'balcony');

      await repo.softDelete(id);
      expect(await repo.search('balcony'), isEmpty);

      await repo.restore(id);
      expect(await repo.search('balcony'), hasLength(1));
    });

    test('a log deleted for good leaves nothing in the index', () async {
      final id = await repo.createText(body: 'balcony');
      await repo.createText(body: 'kept');
      expect(await indexed(), 2);

      await repo.softDelete(id);
      await repo.deletePermanently(id);

      expect(await indexed(), 1);
      expect(await repo.search('balcony'), isEmpty);
    });

    test('emptying Trash clears those logs from the index', () async {
      final id = await repo.createText(body: 'balcony');
      await repo.softDelete(id);

      await repo.emptyTrash();

      expect(await indexed(), 0);
    });

    test('an edit replaces what is found, for every type', () async {
      final text = await repo.createText(body: 'oldword');
      final emoji = await repo.createEmoji(
        emoji: '😌',
        label: 'oldword',
        strength: 3,
      );
      final photo = await repo.createPhoto(
        path: '/a.jpg',
        thumbnailPath: '/a-t.jpg',
        caption: 'oldword',
      );
      final video = await repo.createVideo(
        path: '/v.mp4',
        posterPath: '/v.jpg',
        duration: const Duration(seconds: 3),
        caption: 'oldword',
      );
      final audio = await repo.createAudio(
        path: '/a.m4a',
        duration: const Duration(seconds: 3),
        peaks: const [0.1],
        title: 'oldword',
      );
      final place = await repo.createLocation(
        latitude: 1,
        longitude: 2,
        name: 'oldword',
      );
      expect(await repo.search('oldword'), hasLength(6));

      await repo.updateText(text, body: 'newword');
      await repo.updateEmoji(emoji, emoji: '😌', label: 'newword', strength: 3);
      await repo.updateCaption(photo, caption: 'newword');
      await repo.updateVideo(video, caption: 'newword');
      await repo.updateAudio(audio, title: 'newword');
      await repo.updateLocation(place, name: 'newword', note: null);

      expect(await repo.search('oldword'), isEmpty);
      expect(await repo.search('newword'), hasLength(6));
      expect(await indexed(), 6);
    });

    test('rebuilding from nothing finds everything again', () async {
      await repo.createText(body: 'balcony');
      await repo.createEmoji(emoji: '😌', label: 'Balcony calm', strength: 4);
      await db.customStatement('DELETE FROM log_search');
      expect(await repo.search('balcony'), isEmpty);

      await db.rebuildSearchIndex();

      expect(await repo.search('balcony'), hasLength(2));
      expect(await indexed(), 2);
    });

    test('rebuilding twice does not double anything', () async {
      await repo.createText(body: 'balcony');

      await db.rebuildSearchIndex();
      await db.rebuildSearchIndex();

      expect(await indexed(), 1);
    });
  });

  test('the index is right after a restore from backup', () async {
    final dir = Directory.systemTemp.createTempSync('search_restore_');
    addTearDown(() => dir.deleteSync(recursive: true));
    BackupService service(AppDatabase database, String name) => BackupService(
      db: database,
      mediaRoot: Directory(p.join(dir.path, name))..createSync(),
      cipher: BackupCipher(kdfIterations: 10),
    );
    await repo.createText(body: 'Morning on the balcony');
    await repo.createLocation(latitude: 1, longitude: 2, name: 'Home balcony');
    final trashed = await repo.createText(body: 'balcony, thrown away');
    await repo.softDelete(trashed);
    final file = File(p.join(dir.path, 'backup.moment'));
    await service(db, 'source').exportTo(file, passphrase: 'pw');

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await service(other, 'target').restoreFrom(file, passphrase: 'pw');
    final restored = LogRepository(other);

    final found = await restored.search('balcony');
    expect(found, hasLength(2));
    expect(
      {for (final log in found) log.type},
      {LogType.text, LogType.location},
    );
    // The trashed one is restored into Trash, and found once it leaves it.
    await restored.restore(trashed);
    expect(await restored.search('balcony'), hasLength(3));
  });

  test('a library of 20,000 logs answers in under 200 ms', () async {
    const words = ['walk', 'coffee', 'rain', 'train', 'garden', 'letter'];
    await db.batch((batch) {
      for (var i = 0; i < 20000; i++) {
        final id = 'log-$i';
        batch.insert(
          db.logsTable,
          LogsTableCompanion.insert(
            id: id,
            type: 'text',
            createdAtMs: 1700000000000 + i * 60000,
            tzOffsetMinutes: 0,
          ),
        );
        batch.insert(
          db.textLogsTable,
          TextLogsTableCompanion.insert(
            logId: id,
            body:
                'Entry $i about the ${words[i % words.length]} and a quiet '
                '${i % 997 == 0 ? 'balcony' : 'evening'} at home',
          ),
        );
      }
    });
    expect(await indexed(), 20000);

    // Warm up, then time a rare word, a common word and a prefix.
    await repo.search('balcony');
    for (final query in ['balcony', 'garden', 'balc', 'quiet evening']) {
      final watch = Stopwatch()..start();
      final found = await repo.search(query, limit: 50);
      watch.stop();

      expect(found, isNotEmpty, reason: query);
      expect(
        watch.elapsedMilliseconds,
        lessThan(200),
        reason: '"$query" took ${watch.elapsedMilliseconds} ms',
      );
    }
    expect(await repo.search('balcony'), hasLength(21));
  });
}
