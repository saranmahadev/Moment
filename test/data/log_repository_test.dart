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

    test('creates an audio log and reads it back', () async {
      final id = await repo.createAudio(
        path: photoFile('a.m4a').path,
        duration: const Duration(seconds: 42),
        peaks: [0.1, 0.5, 0.9, 0.3],
        title: 'Voice note',
        note: 'Idea for the weekend',
      );
      final log = await repo.getById(id) as AudioLog;

      expect(log.path, photoFile('a.m4a').path);
      expect(log.duration, const Duration(seconds: 42));
      expect(log.peaks, [0.1, 0.5, 0.9, 0.3]);
      expect(log.title, 'Voice note');
      expect(log.note, 'Idea for the weekend');
      expect(log.type, LogType.audio);
    });

    test(
      'an audio log without a title or note reads back with both null',
      () async {
        final id = await repo.createAudio(
          path: photoFile('a.m4a').path,
          duration: const Duration(seconds: 10),
          peaks: [0.2, 0.4],
        );
        final log = await repo.getById(id) as AudioLog;
        expect(log.title, isNull);
        expect(log.note, isNull);
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

    test('updateAudio changes title and/or note and stamps editedAt', () async {
      final id = await repo.createAudio(
        path: photoFile('a.m4a').path,
        duration: const Duration(seconds: 5),
        peaks: [0.1],
        title: 'Original title',
      );
      now = now.add(const Duration(hours: 1));

      await repo.updateAudio(id, title: 'Edited title', note: 'A note');

      final log = await repo.getById(id) as AudioLog;
      expect(log.title, 'Edited title');
      expect(log.note, 'A note');
      expect(log.editedAt, now);
    });

    test('updateAudio on a text log throws', () async {
      final id = await repo.createText(body: 'hi');
      expect(() => repo.updateAudio(id, title: 'x'), throwsArgumentError);
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

  group('getAll', () {
    test('returns every log once, Trash included, without a stream', () async {
      final kept = await repo.createText(body: 'kept');
      final trashed = await repo.createEmoji(emoji: '😌', strength: 3);
      await repo.softDelete(trashed);

      final all = await repo.getAll();

      expect(all.map((l) => l.id), unorderedEquals([kept, trashed]));
      expect(all.firstWhere((l) => l.id == trashed).deletedAt, isNotNull);
    });

    test('is empty for an empty library', () async {
      expect(await repo.getAll(), isEmpty);
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

    test('includes audio logs', () async {
      final id = await repo.createAudio(
        path: photoFile('a.m4a').path,
        duration: const Duration(seconds: 5),
        peaks: [0.1],
      );

      final feed = await repo.watchFeed().first;
      expect(feed.map((l) => l.id), [id]);
      expect(feed.single, isA<AudioLog>());
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

    test('deletePermanently removes an audio log\'s file from disk', () async {
      final audio = photoFile('a.m4a');
      final id = await repo.createAudio(
        path: audio.path,
        duration: const Duration(seconds: 5),
        peaks: [0.1],
      );

      await repo.deletePermanently(id);

      expect(audio.existsSync(), isFalse);
    });
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

  group('video', () {
    test('creates a video log and reads it back', () async {
      final id = await repo.createVideo(
        path: '/media/2026/01/a.mp4',
        posterPath: '/media/2026/01/a-poster.jpg',
        duration: const Duration(seconds: 48),
        caption: 'Walk to the station',
      );

      final log = await repo.getById(id) as VideoLog;
      expect(log.type, LogType.video);
      expect(log.path, '/media/2026/01/a.mp4');
      expect(log.posterPath, '/media/2026/01/a-poster.jpg');
      expect(log.duration, const Duration(seconds: 48));
      expect(log.caption, 'Walk to the station');
      expect(log.createdAt, now);
    });

    test('a video without a caption reads back with a null caption', () async {
      final id = await repo.createVideo(
        path: '/a.mp4',
        posterPath: '/a.jpg',
        duration: const Duration(seconds: 1),
      );
      expect((await repo.getById(id) as VideoLog).caption, isNull);
    });

    test('updateVideo changes the caption and stamps editedAt', () async {
      final id = await repo.createVideo(
        path: '/a.mp4',
        posterPath: '/a.jpg',
        duration: const Duration(seconds: 1),
        caption: 'Before',
      );
      now = now.add(const Duration(minutes: 5));

      await repo.updateVideo(id, caption: 'After');

      final log = await repo.getById(id) as VideoLog;
      expect(log.caption, 'After');
      expect(log.editedAt, now);
    });

    test('updateVideo can clear the caption', () async {
      final id = await repo.createVideo(
        path: '/a.mp4',
        posterPath: '/a.jpg',
        duration: const Duration(seconds: 1),
        caption: 'Before',
      );
      await repo.updateVideo(id, caption: null);
      expect((await repo.getById(id) as VideoLog).caption, isNull);
    });

    test('updateVideo on a text log throws', () async {
      final id = await repo.createText(body: 'hi');
      expect(() => repo.updateVideo(id, caption: 'x'), throwsArgumentError);
    });

    test('appears in the feed and in getAll', () async {
      final id = await repo.createVideo(
        path: '/a.mp4',
        posterPath: '/a.jpg',
        duration: const Duration(seconds: 1),
      );
      expect((await repo.watchFeed().first).single, isA<VideoLog>());
      expect(
        (await repo.watchFeed(types: {LogType.video}).first).single.id,
        id,
      );
      expect((await repo.getAll()).single, isA<VideoLog>());
    });

    test('deletePermanently removes the video and its poster', () async {
      final video = photoFile('a.mp4');
      final poster = photoFile('a-poster.jpg');
      final id = await repo.createVideo(
        path: video.path,
        posterPath: poster.path,
        duration: const Duration(seconds: 1),
      );

      await repo.deletePermanently(id);

      expect(video.existsSync(), isFalse);
      expect(poster.existsSync(), isFalse);
    });

    test('emptyTrash and purgeExpired remove trashed video files', () async {
      final video1 = photoFile('1.mp4');
      final poster1 = photoFile('1.jpg');
      final video2 = photoFile('2.mp4');
      final poster2 = photoFile('2.jpg');
      final first = await repo.createVideo(
        path: video1.path,
        posterPath: poster1.path,
        duration: const Duration(seconds: 1),
      );
      await repo.softDelete(first);
      await repo.purgeExpired(now.add(const Duration(days: 31)));
      expect(video1.existsSync(), isFalse);
      expect(poster1.existsSync(), isFalse);

      final second = await repo.createVideo(
        path: video2.path,
        posterPath: poster2.path,
        duration: const Duration(seconds: 1),
      );
      await repo.softDelete(second);
      await repo.emptyTrash();
      expect(video2.existsSync(), isFalse);
      expect(poster2.existsSync(), isFalse);
    });
  });

  group('location', () {
    // Values that do not survive a round trip through float32 or a decimal
    // string with too few digits.
    const latitude = 12.971598765432101;
    const longitude = -77.59456234567891;

    test('creates a location log and reads it back', () async {
      final id = await repo.createLocation(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: 12,
        name: 'Favourite bench',
        note: 'Under the big tree',
      );

      final log = await repo.getById(id) as LocationLog;
      expect(log.type, LogType.location);
      expect(log.accuracyMeters, 12);
      expect(log.name, 'Favourite bench');
      expect(log.note, 'Under the big tree');
      expect(log.createdAt, now);
    });

    test('coordinates round-trip exactly', () async {
      final id = await repo.createLocation(
        latitude: latitude,
        longitude: longitude,
      );

      final log = await repo.getById(id) as LocationLog;
      expect(log.latitude, latitude);
      expect(log.longitude, longitude);
    });

    test('accuracy, name and note are optional', () async {
      final id = await repo.createLocation(latitude: 0, longitude: 0);
      final log = await repo.getById(id) as LocationLog;
      expect(log.accuracyMeters, isNull);
      expect(log.name, isNull);
      expect(log.note, isNull);
    });

    test('rejects coordinates that are not on Earth', () {
      expect(
        () => repo.createLocation(latitude: 90.1, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => repo.createLocation(latitude: -90.1, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => repo.createLocation(latitude: 0, longitude: 180.1),
        throwsArgumentError,
      );
      expect(
        () => repo.createLocation(latitude: 0, longitude: -180.1),
        throwsArgumentError,
      );
      expect(
        () => repo.createLocation(latitude: double.nan, longitude: 0),
        throwsArgumentError,
      );
    });

    test('the poles and the antimeridian are accepted', () async {
      await repo.createLocation(latitude: 90, longitude: 180);
      await repo.createLocation(latitude: -90, longitude: -180);
      expect(await repo.getAll(), hasLength(2));
    });

    test('moveLocation moves the pin and stamps editedAt', () async {
      final id = await repo.createLocation(
        latitude: 1,
        longitude: 2,
        accuracyMeters: 30,
        name: 'Tea stall',
      );
      now = now.add(const Duration(minutes: 5));

      await repo.moveLocation(
        id,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: 8,
      );

      final log = await repo.getById(id) as LocationLog;
      expect(log.latitude, latitude);
      expect(log.longitude, longitude);
      expect(log.accuracyMeters, 8);
      expect(log.name, 'Tea stall');
      expect(log.editedAt, now);
    });

    test('moveLocation without an accuracy clears the old one', () async {
      final id = await repo.createLocation(
        latitude: 1,
        longitude: 2,
        accuracyMeters: 30,
      );
      await repo.moveLocation(id, latitude: 3, longitude: 4);
      expect((await repo.getById(id) as LocationLog).accuracyMeters, isNull);
    });

    test('moveLocation rejects coordinates that are not on Earth', () async {
      final id = await repo.createLocation(latitude: 1, longitude: 2);
      expect(
        () => repo.moveLocation(id, latitude: 91, longitude: 0),
        throwsArgumentError,
      );
    });

    test('updateLocation changes the name and note, leaving the pin', () async {
      final id = await repo.createLocation(
        latitude: latitude,
        longitude: longitude,
        name: 'Before',
      );
      now = now.add(const Duration(minutes: 5));

      await repo.updateLocation(id, name: 'After', note: 'A note');

      final log = await repo.getById(id) as LocationLog;
      expect(log.name, 'After');
      expect(log.note, 'A note');
      expect(log.latitude, latitude);
      expect(log.editedAt, now);
    });

    test('updateLocation can clear the name and note', () async {
      final id = await repo.createLocation(
        latitude: 1,
        longitude: 2,
        name: 'Before',
        note: 'Note',
      );
      await repo.updateLocation(id, name: null, note: null);
      final log = await repo.getById(id) as LocationLog;
      expect(log.name, isNull);
      expect(log.note, isNull);
    });

    test('updateLocation and moveLocation on a text log throw', () async {
      final id = await repo.createText(body: 'hi');
      expect(
        () => repo.updateLocation(id, name: 'x', note: null),
        throwsArgumentError,
      );
      expect(
        () => repo.moveLocation(id, latitude: 1, longitude: 2),
        throwsArgumentError,
      );
    });

    test('appears in the feed and in getAll', () async {
      final id = await repo.createLocation(latitude: 1, longitude: 2);
      expect((await repo.watchFeed().first).single, isA<LocationLog>());
      expect(
        (await repo.watchFeed(types: {LogType.location}).first).single.id,
        id,
      );
      expect((await repo.getAll()).single, isA<LocationLog>());
    });

    test('can be trashed, restored and deleted for good', () async {
      final id = await repo.createLocation(latitude: 1, longitude: 2);
      await repo.softDelete(id);
      expect((await repo.watchTrash().first).single, isA<LocationLog>());
      await repo.restore(id);
      expect(await repo.watchTrash().first, isEmpty);
      await repo.deletePermanently(id);
      expect(await repo.getById(id), isNull);
    });
  });

  group('watchActiveDays', () {
    test('is empty for an empty journal', () async {
      expect(await repo.watchActiveDays().first, isEmpty);
    });

    test('lists each day once, however many logs it has', () async {
      await repo.createText(body: 'a', createdAt: DateTime.utc(2026, 1, 14, 9));
      await repo.createText(
        body: 'b',
        createdAt: DateTime.utc(2026, 1, 14, 21),
      );
      await repo.createEmoji(
        emoji: '😌',
        strength: 3,
        createdAt: DateTime.utc(2026, 1, 15, 8),
      );

      expect(await repo.watchActiveDays().first, {
        DateTime.utc(2026, 1, 14),
        DateTime.utc(2026, 1, 15),
      });
    });

    test('uses the day in the zone the log was made in', () async {
      final id = await repo.createText(
        body: 'late',
        createdAt: DateTime.utc(2026, 1, 14, 23, 50),
      );
      await db.customStatement(
        'UPDATE log SET tz_offset_minutes = 330 WHERE id = ?',
        [id],
      );

      expect(await repo.watchActiveDays().first, {DateTime.utc(2026, 1, 15)});
    });

    test('leaves out logs in Trash and brings them back on restore', () async {
      final id = await repo.createText(body: 'gone');

      await repo.softDelete(id);
      expect(await repo.watchActiveDays().first, isEmpty);

      await repo.restore(id);
      expect(await repo.watchActiveDays().first, {DateTime.utc(2026, 1, 15)});
    });

    test('follows a log moved to another day', () async {
      final id = await repo.createText(body: 'move me');
      final days = repo.watchActiveDays();
      final seen = expectLater(
        days,
        emitsInOrder([
          {DateTime.utc(2026, 1, 15)},
          {DateTime.utc(2026, 1, 10)},
        ]),
      );

      await repo.setCreatedAt(id, DateTime.utc(2026, 1, 10, 12));
      await seen;
    });
  });

  group('watchDayCounts', () {
    test('counts the logs on each day, Trash left out', () async {
      await repo.createText(body: 'a', createdAt: DateTime.utc(2026, 1, 14, 9));
      await repo.createText(
        body: 'b',
        createdAt: DateTime.utc(2026, 1, 14, 21),
      );
      final gone = await repo.createText(
        body: 'c',
        createdAt: DateTime.utc(2026, 1, 14, 22),
      );
      await repo.createEmoji(
        emoji: '😌',
        strength: 3,
        createdAt: DateTime.utc(2026, 1, 15, 8),
      );
      await repo.softDelete(gone);

      expect(await repo.watchDayCounts().first, {
        DateTime.utc(2026, 1, 14): 2,
        DateTime.utc(2026, 1, 15): 1,
      });
    });

    test('has the same days as watchActiveDays', () async {
      await repo.createText(body: 'a', createdAt: DateTime.utc(2026, 1, 3));
      await repo.createText(body: 'b', createdAt: DateTime.utc(2026, 1, 9));

      final counts = await repo.watchDayCounts().first;
      expect(counts.keys.toSet(), await repo.watchActiveDays().first);
    });
  });
}
