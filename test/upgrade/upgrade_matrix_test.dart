import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_service.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The upgrade matrix: a database, a backup and a settings file made by
/// every released version's own code (tool/fixtures/make_fixtures.sh), each
/// opened by this version. Adding a release means adding a row here and
/// running the script for it.
class _Release {
  const _Release(
    this.version, {
    this.media = false,
    this.video = false,
    this.backup = false,
    this.settings = false,
    this.themes = false,
    this.streaks = false,
    this.widget = false,
  });
  final String version;
  final bool media, video, backup, settings, themes, streaks, widget;

  String get dir => p.join('test', 'fixtures', 'releases', version);

  /// Logs the generator wrote, Trash included.
  int get logs => 5 + (media ? 2 : 0) + (video ? 2 : 0);
}

const _releases = [
  _Release('0.1.0'),
  _Release('0.2.0', media: true, backup: true),
  _Release('0.3.0', media: true, video: true, backup: true, settings: true),
  _Release(
    '0.4.0',
    media: true,
    video: true,
    backup: true,
    settings: true,
    themes: true,
  ),
  _Release(
    '0.5.0',
    media: true,
    video: true,
    backup: true,
    settings: true,
    themes: true,
    streaks: true,
  ),
  _Release(
    '0.6.0',
    media: true,
    video: true,
    backup: true,
    settings: true,
    themes: true,
    streaks: true,
    widget: true,
  ),
];

/// The bytes the generator wrote for a media file called [name].
List<int> _mediaBytes(String name, int size) =>
    List.generate(size, (i) => (i * 31 + name.length) % 256);

Future<void> _expectEveryLog(LogRepository repo, _Release r) async {
  final feed = await repo.watchFeed().first;
  final trash = await repo.watchTrash().first;
  expect(feed.length + trash.length, r.logs);
  expect(trash.single, isA<EmojiLog>());
  expect((trash.single as EmojiLog).emoji, '😴');

  final byId = {for (final log in feed) log.id: log};
  final first = byId['log-00'] as TextLog;
  expect(first.body, 'First entry, before any upgrade.');
  expect(first.editedAt, isNull);
  final edited = byId['log-01'] as TextLog;
  expect(edited.body, 'Edited after writing it');
  expect(edited.editedAt, isNotNull);
  // Backdated to 23:50 local in a +05:30 zone: still that day, not the
  // next one in UTC.
  final late = byId['log-02'] as TextLog;
  expect(late.tzOffsetMinutes, 330);
  expect(late.localDay, DateTime.utc(2026, 3, 10));
  final calm = byId['log-03'] as EmojiLog;
  expect((calm.emoji, calm.label, calm.strength), ('😌', 'Calm', 4));

  if (r.media) {
    final photo = feed.whereType<PhotoLog>().single;
    expect(photo.caption, 'Lake at dawn');
    expect(p.basename(photo.path), 'photo.jpg');
    expect(p.basename(photo.thumbnailPath), 'photo-thumb.jpg');
    final audio = feed.whereType<AudioLog>().single;
    expect(audio.title, 'Voice note');
    expect(audio.duration, const Duration(seconds: 42));
  }
  if (r.video) {
    final video = feed.whereType<VideoLog>().single;
    expect(video.caption, 'Walk to the station');
    expect(video.duration, const Duration(seconds: 48));
    final place = feed.whereType<LocationLog>().single;
    // Stored as REAL: exactly what was saved.
    expect((place.latitude, place.longitude), (12.91227, 77.7165));
    expect(place.accuracyMeters, 12);
    expect((place.name, place.note), ('Favourite bench', 'by the lake'));
  }

  // Search reaches logs written before the index existed.
  expect((await repo.search('edited')).map((l) => l.id), ['log-01']);
  if (r.video) {
    expect((await repo.search('lake')).map((l) => l.id).toSet(), {
      'log-05',
      'log-08',
    });
  }
  // Streaks read days straight from SQL; the backdated day is there.
  expect(
    await repo.watchActiveDays().first,
    containsAll([DateTime.utc(2026, 3, 10), DateTime.utc(2026, 3, 14)]),
  );
}

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('upgrade_matrix_'));
  tearDown(() => temp.deleteSync(recursive: true));

  for (final r in _releases) {
    group('from ${r.version}', () {
      test('the database opens with every log intact and searchable', () async {
        final file = File(
          p.join(r.dir, 'moment.db'),
        ).copySync(p.join(temp.path, 'moment.db'));
        final db = AppDatabase(NativeDatabase(file));
        await _expectEveryLog(LogRepository(db), r);
        await db.close();

        // Opening it again is a no-op: same version, same rows.
        final raw = sqlite3.sqlite3.open(file.path);
        expect(raw.select('PRAGMA user_version').single.values.single, 6);
        raw.close();
        final again = AppDatabase(NativeDatabase(file));
        expect(
          (await LogRepository(again).watchFeed().first).length,
          r.logs - 1,
        );
        await again.close();
      });

      if (r.backup) {
        test(
          'its backup restores onto a new phone, every file intact',
          () async {
            final root = Directory(p.join(temp.path, 'phone'))..createSync();
            final db = AppDatabase(NativeDatabase.memory());
            final service = BackupService(
              db: db,
              mediaRoot: root,
              cipher: BackupCipher(),
            );
            final summary = await service.restoreFrom(
              File(p.join(r.dir, 'library.moment')),
              passphrase: 'fixture passphrase',
            );
            expect(summary.logsRestored, r.logs);
            final repo = LogRepository(db);
            await _expectEveryLog(repo, r);

            final feed = await repo.watchFeed().first;
            final photo = feed.whereType<PhotoLog>().single;
            expect(p.isWithin(root.path, photo.path), isTrue);
            expect(
              File(photo.path).readAsBytesSync(),
              _mediaBytes('photo.jpg', 2048),
            );
            final audio = feed.whereType<AudioLog>().single;
            expect(
              File(audio.path).readAsBytesSync(),
              _mediaBytes('voice.m4a', 4096),
            );
            if (r.video) {
              final video = feed.whereType<VideoLog>().single;
              expect(
                File(video.path).readAsBytesSync(),
                _mediaBytes('walk.mp4', 8192),
              );
            }

            // Restoring the same backup twice adds nothing.
            final twice = await service.restoreFrom(
              File(p.join(r.dir, 'library.moment')),
              passphrase: 'fixture passphrase',
            );
            expect((twice.logsRestored, twice.logsSkipped), (0, r.logs));
            await db.close();
          },
        );
      }

      if (r.settings) {
        test(
          'its settings keep their values; newer ones take defaults',
          () async {
            final file = File(
              p.join(r.dir, 'settings.json'),
            ).copySync(p.join(temp.path, 'settings.json'));
            final s = await AppSettings.load(FileSettingsStore(file));
            expect(s.lookUpPlaceNames, isTrue);
            expect(s.themeMode, r.themes ? ThemeMode.dark : ThemeMode.system);
            expect(s.reduceTransparency, r.themes);
            expect(s.reminderOn, r.themes);
            if (r.themes) {
              expect((s.reminderTime.hour, s.reminderTime.minute), (21, 15));
            }
            expect(s.showStreaks, !r.streaks);
            expect(s.graceDays, r.streaks ? 3 : 1);
            expect(s.widgetShowsStreak, !r.widget);
          },
        );
      }
    });
  }
}
