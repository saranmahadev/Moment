import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';
import 'package:path/path.dart' as p;

IdGenerator _sequentialIds() {
  var next = 0;
  return () => 'id-${next++}';
}

void main() {
  late AppDatabase db;
  late LogRepository repo;
  late DateTime now;
  late Directory tempDir;

  setUp(() {
    now = DateTime.utc(2026, 1, 15, 12);
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now, generateId: _sequentialIds());
    tempDir = Directory.systemTemp.createTempSync('log_repository_test_');
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  /// Creates a throwaway file (standing in for an imported photo + its
  /// thumbnail) under [tempDir], so photo tests can prove deletion for
  /// real instead of just on the database row.
  File photoFile(String name) {
    final file = File(p.join(tempDir.path, name));
    file.writeAsStringSync('fake image bytes');
    return file;
  }

  group('create and read', () {
    test('creates a text log and reads it back', () async {
      final id = await repo.createText(body: 'Quiet evening.');
      final log = await repo.getById(id);

      expect(log, isA<TextLog>());
      final text = log! as TextLog;
      expect(text.id, id);
      expect(text.type, LogType.text);
      expect(text.body, 'Quiet evening.');
      expect(text.createdAt, now);
      expect(text.tzOffsetMinutes, 0);
      expect(text.editedAt, isNull);
      expect(text.deletedAt, isNull);
    });

    test('creates an emoji log and reads it back', () async {
      final id = await repo.createEmoji(
        emoji: '😌',
        label: 'Calm',
        strength: 3,
      );
      final log = await repo.getById(id);

      final emoji = log! as EmojiLog;
      expect(emoji.emoji, '😌');
      expect(emoji.label, 'Calm');
      expect(emoji.strength, 3);
      expect(emoji.type, LogType.emoji);
    });

    test('creates a photo log and reads it back', () async {
      final photo = photoFile('a.jpg');
      final thumb = photoFile('a-thumb.jpg');

      final id = await repo.createPhoto(
        path: photo.path,
        thumbnailPath: thumb.path,
        caption: 'By the lake',
      );
      final log = await repo.getById(id);

      final photoLog = log! as PhotoLog;
      expect(photoLog.path, photo.path);
      expect(photoLog.thumbnailPath, thumb.path);
      expect(photoLog.caption, 'By the lake');
      expect(photoLog.type, LogType.photo);
    });

    test(
      'a photo log without a caption reads back with a null caption',
      () async {
        final id = await repo.createPhoto(
          path: photoFile('a.jpg').path,
          thumbnailPath: photoFile('a-thumb.jpg').path,
        );
        final log = await repo.getById(id) as PhotoLog;
        expect(log.caption, isNull);
      },
    );

    test('an emoji log without a label reads back with a null label', () async {
      final id = await repo.createEmoji(emoji: '😴', strength: 1);
      final emoji = await repo.getById(id) as EmojiLog;
      expect(emoji.label, isNull);
    });

    test('createText accepts a backdated createdAt', () async {
      final backdated = DateTime.utc(2020, 3, 1, 9, 30);
      final id = await repo.createText(body: 'Old entry', createdAt: backdated);
      final log = await repo.getById(id) as TextLog;
      expect(log.createdAt, backdated);
    });

    test('getById returns null for an unknown id', () async {
      expect(await repo.getById('missing'), isNull);
    });

    test('rejects a blank text body', () {
      expect(() => repo.createText(body: '   '), throwsArgumentError);
    });

    test('rejects an empty emoji', () {
      expect(
        () => repo.createEmoji(emoji: '', strength: 3),
        throwsArgumentError,
      );
    });

    test('rejects an emoji strength outside 1 to 5', () {
      expect(
        () => repo.createEmoji(emoji: '😌', strength: 0),
        throwsArgumentError,
      );
      expect(
        () => repo.createEmoji(emoji: '😌', strength: 6),
        throwsArgumentError,
      );
    });

    test('ids are unique across creates', () async {
      final id1 = await repo.createText(body: 'one');
      final id2 = await repo.createText(body: 'two');
      expect(id1, isNot(id2));
    });
  });

  group('update', () {
    test('updateText changes the body and stamps editedAt', () async {
      final id = await repo.createText(body: 'Original');
      now = now.add(const Duration(hours: 1));

      await repo.updateText(id, body: 'Edited');

      final log = await repo.getById(id) as TextLog;
      expect(log.body, 'Edited');
      expect(log.editedAt, now);
    });

    test('updateText rejects a blank body', () async {
      final id = await repo.createText(body: 'Original');
      expect(() => repo.updateText(id, body: '  '), throwsArgumentError);
    });

    test('updateText on an unknown id throws', () {
      expect(() => repo.updateText('missing', body: 'x'), throwsArgumentError);
    });

    test('updateText on an emoji log throws', () async {
      final id = await repo.createEmoji(emoji: '😌', strength: 2);
      expect(() => repo.updateText(id, body: 'x'), throwsArgumentError);
    });

    test(
      'updateEmoji changes emoji, label and strength, and stamps editedAt',
      () async {
        final id = await repo.createEmoji(
          emoji: '😌',
          label: 'Calm',
          strength: 2,
        );
        now = now.add(const Duration(hours: 1));

        await repo.updateEmoji(id, emoji: '😄', label: 'Happy', strength: 5);

        final log = await repo.getById(id) as EmojiLog;
        expect(log.emoji, '😄');
        expect(log.label, 'Happy');
        expect(log.strength, 5);
        expect(log.editedAt, now);
      },
    );

    test(
      'updateEmoji with only strength leaves emoji and label unchanged',
      () async {
        final id = await repo.createEmoji(
          emoji: '😌',
          label: 'Calm',
          strength: 2,
        );

        await repo.updateEmoji(id, strength: 4);

        final log = await repo.getById(id) as EmojiLog;
        expect(log.emoji, '😌');
        expect(log.label, 'Calm');
        expect(log.strength, 4);
      },
    );

    test('updateEmoji rejects a strength outside 1 to 5', () async {
      final id = await repo.createEmoji(emoji: '😌', strength: 2);
      expect(() => repo.updateEmoji(id, strength: 9), throwsArgumentError);
    });

    test('updateCaption changes the caption and stamps editedAt', () async {
      final id = await repo.createPhoto(
        path: photoFile('a.jpg').path,
        thumbnailPath: photoFile('a-thumb.jpg').path,
        caption: 'Original',
      );
      now = now.add(const Duration(hours: 1));

      await repo.updateCaption(id, caption: 'Edited');

      final log = await repo.getById(id) as PhotoLog;
      expect(log.caption, 'Edited');
      expect(log.editedAt, now);
    });

    test('updateCaption on a text log throws', () async {
      final id = await repo.createText(body: 'hi');
      expect(() => repo.updateCaption(id, caption: 'x'), throwsArgumentError);
    });
  });

  group('trash', () {
    test(
      'softDelete stamps deletedAt and moves the log into watchTrash',
      () async {
        final id = await repo.createText(body: 'Gone soon');
        now = now.add(const Duration(hours: 1));

        await repo.softDelete(id);

        final log = (await repo.getById(id))!;
        expect(log.deletedAt, now);

        final trash = await repo.watchTrash().first;
        expect(trash.map((l) => l.id), [id]);
      },
    );

    test('a soft-deleted log no longer appears in watchFeed', () async {
      final id = await repo.createText(body: 'Gone soon');
      await repo.softDelete(id);

      final feed = await repo.watchFeed().first;
      expect(feed, isEmpty);
    });

    test(
      'restore clears deletedAt and removes the log from watchTrash',
      () async {
        final id = await repo.createText(body: 'Back again');
        await repo.softDelete(id);

        await repo.restore(id);

        final log = (await repo.getById(id))!;
        expect(log.deletedAt, isNull);
        expect(await repo.watchTrash().first, isEmpty);
      },
    );

    test('watchTrash orders newest-deleted first', () async {
      final first = await repo.createText(body: 'first');
      final second = await repo.createText(body: 'second');
      await repo.softDelete(first);
      now = now.add(const Duration(minutes: 1));
      await repo.softDelete(second);

      final trash = await repo.watchTrash().first;
      expect(trash.map((l) => l.id), [second, first]);
    });
  });

  group('watchFeed', () {
    test('orders newest-created first', () async {
      final first = await repo.createText(body: 'first');
      now = now.add(const Duration(minutes: 1));
      final second = await repo.createEmoji(emoji: '😌', strength: 2);

      final feed = await repo.watchFeed().first;
      expect(feed.map((l) => l.id), [second, first]);
    });

    test('ties at the same createdAt break by id, newest first', () async {
      final first = await repo.createText(body: 'first');
      final second = await repo.createText(body: 'second');

      final feed = await repo.watchFeed().first;
      expect(feed.map((l) => l.id), [second, first]);
    });

    test('can be restricted to a set of types', () async {
      final text = await repo.createText(body: 'a text log');
      await repo.createEmoji(emoji: '😌', strength: 2);

      final feed = await repo.watchFeed(types: {LogType.text}).first;
      expect(feed.map((l) => l.id), [text]);
    });

    test('includes photo logs', () async {
      final id = await repo.createPhoto(
        path: photoFile('a.jpg').path,
        thumbnailPath: photoFile('a-thumb.jpg').path,
      );

      final feed = await repo.watchFeed().first;
      expect(feed.map((l) => l.id), [id]);
      expect(feed.single, isA<PhotoLog>());
    });

    test('re-emits when a log already in the feed is edited', () async {
      final id = await repo.createText(body: 'Original');

      final updates = <List<Log>>[];
      final sub = repo.watchFeed().listen(updates.add);
      await pumpEventQueue();

      await repo.updateText(id, body: 'Edited');
      await pumpEventQueue();
      await sub.cancel();

      expect(updates.last.single, isA<TextLog>());
      expect((updates.last.single as TextLog).body, 'Edited');
    });
  });

  group('purging', () {
    test('deletePermanently removes the log entirely', () async {
      final id = await repo.createText(body: 'Gone for good');
      await repo.deletePermanently(id);
      expect(await repo.getById(id), isNull);
    });

    test(
      'emptyTrash removes every soft-deleted log but leaves the rest',
      () async {
        final trashed = await repo.createText(body: 'trashed');
        final kept = await repo.createText(body: 'kept');
        await repo.softDelete(trashed);

        await repo.emptyTrash();

        expect(await repo.getById(trashed), isNull);
        expect(await repo.getById(kept), isNotNull);
      },
    );

    test('purgeExpired removes logs deleted more than 30 days ago', () async {
      final old = await repo.createText(body: 'old');
      await repo.softDelete(old);

      await repo.purgeExpired(now.add(const Duration(days: 31)));

      expect(await repo.getById(old), isNull);
    });

    test('purgeExpired keeps logs deleted less than 30 days ago', () async {
      final recent = await repo.createText(body: 'recent');
      await repo.softDelete(recent);

      await repo.purgeExpired(now.add(const Duration(days: 29)));

      expect(await repo.getById(recent), isNotNull);
    });

    test('purgeExpired never touches logs that are not in Trash', () async {
      final kept = await repo.createText(body: 'kept');

      await repo.purgeExpired(now.add(const Duration(days: 365)));

      expect(await repo.getById(kept), isNotNull);
    });

    test('deletePermanently removes a photo log\'s files from disk', () async {
      final photo = photoFile('a.jpg');
      final thumb = photoFile('a-thumb.jpg');
      final id = await repo.createPhoto(
        path: photo.path,
        thumbnailPath: thumb.path,
      );

      await repo.deletePermanently(id);

      expect(photo.existsSync(), isFalse);
      expect(thumb.existsSync(), isFalse);
    });

    test('emptyTrash removes a trashed photo log\'s files from disk', () async {
      final photo = photoFile('a.jpg');
      final thumb = photoFile('a-thumb.jpg');
      final id = await repo.createPhoto(
        path: photo.path,
        thumbnailPath: thumb.path,
      );
      await repo.softDelete(id);

      await repo.emptyTrash();

      expect(photo.existsSync(), isFalse);
      expect(thumb.existsSync(), isFalse);
    });

    test(
      'purgeExpired removes an expired photo log\'s files from disk',
      () async {
        final photo = photoFile('a.jpg');
        final thumb = photoFile('a-thumb.jpg');
        final id = await repo.createPhoto(
          path: photo.path,
          thumbnailPath: thumb.path,
        );
        await repo.softDelete(id);

        await repo.purgeExpired(now.add(const Duration(days: 31)));

        expect(photo.existsSync(), isFalse);
        expect(thumb.existsSync(), isFalse);
      },
    );

    test(
      'purgeExpired leaves a not-yet-expired photo log\'s files alone',
      () async {
        final photo = photoFile('a.jpg');
        final thumb = photoFile('a-thumb.jpg');
        final id = await repo.createPhoto(
          path: photo.path,
          thumbnailPath: thumb.path,
        );
        await repo.softDelete(id);

        await repo.purgeExpired(now.add(const Duration(days: 29)));

        expect(photo.existsSync(), isTrue);
        expect(thumb.existsSync(), isTrue);
      },
    );
  });

  group('setCreatedAt', () {
    test('backdates a log and recomputes its recorded offset', () async {
      final id = await repo.createText(body: 'hi');
      final backdated = DateTime.utc(2020, 6, 1, 8);

      await repo.setCreatedAt(id, backdated);

      final log = (await repo.getById(id))!;
      expect(log.createdAt, backdated);
      expect(log.tzOffsetMinutes, 0);
    });

    test('does not change editedAt', () async {
      final id = await repo.createText(body: 'hi');
      await repo.setCreatedAt(id, DateTime.utc(2020, 6, 1, 8));

      final log = (await repo.getById(id))!;
      expect(log.editedAt, isNull);
    });
  });
}
