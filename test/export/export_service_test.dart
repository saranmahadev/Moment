import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/export/export_service.dart';
import 'package:path/path.dart' as p;

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;
  late ExportService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('export_service_test_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
    service = ExportService(repository: repo, clock: () => now);
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  File mediaFile(String name, List<int> bytes) =>
      File(p.join(tempDir.path, name))..writeAsBytesSync(bytes);

  Future<Archive> exportArchive(Set<LogType> types) async {
    final file = await service.exportTo(
      Directory(p.join(tempDir.path, 'out')),
      types: types,
    );
    return ZipDecoder().decodeBytes(file.readAsBytesSync());
  }

  Map<String, dynamic> jsonIn(Archive archive, String name) => {
    'rows': jsonDecode(
      utf8.decode(archive.findFile(name)!.content as List<int>),
    ),
  };

  String textIn(Archive archive, String name) =>
      utf8.decode(archive.findFile(name)!.content as List<int>);

  test('writes a dated zip named for the export', () async {
    await repo.createText(body: 'Hello');
    final file = await service.exportTo(
      Directory(p.join(tempDir.path, 'out')),
      types: {LogType.text},
    );
    expect(p.basename(file.path), 'Moment export 2026-11-07.zip');
    expect(file.existsSync(), isTrue);
  });

  test('text logs export as JSON and Markdown', () async {
    final id = await repo.createText(
      body: 'Quiet evening.',
      createdAt: DateTime.utc(2026, 11, 6, 20, 12),
    );
    await repo.createText(body: 'Second');

    final archive = await exportArchive({LogType.text});

    final rows = jsonIn(archive, 'text/text.json')['rows'] as List;
    expect(rows, hasLength(2));
    final first = rows.firstWhere((r) => r['id'] == id) as Map;
    expect(first['body'], 'Quiet evening.');
    expect(first['createdAt'], '2026-11-06T20:12:00.000Z');
    expect(first['tzOffsetMinutes'], 0);

    final md = textIn(archive, 'text/text.md');
    expect(md, contains('# Text'));
    expect(md, contains('Quiet evening.'));
    expect(md, contains('Fri 6 Nov 2026'));
  });

  test('emoji logs export with emoji, label and strength', () async {
    await repo.createEmoji(emoji: '😌', label: 'Calm', strength: 4);

    final archive = await exportArchive({LogType.emoji});

    final row = (jsonIn(archive, 'emoji/emoji.json')['rows'] as List).single;
    expect(row['emoji'], '😌');
    expect(row['label'], 'Calm');
    expect(row['strength'], 4);
    expect(textIn(archive, 'emoji/emoji.md'), contains('😌 Calm'));
  });

  test('photos and audio export with their original files', () async {
    final photo = mediaFile('a.jpg', [1, 2, 3]);
    final thumb = mediaFile('a-thumb.jpg', [9]);
    await repo.createPhoto(
      path: photo.path,
      thumbnailPath: thumb.path,
      caption: 'By the lake',
    );
    final audio = mediaFile('b.m4a', [4, 5, 6, 7]);
    await repo.createAudio(
      path: audio.path,
      duration: const Duration(seconds: 42),
      peaks: [0.1, 0.2],
      title: 'Voice note',
      note: 'Call back',
    );

    final archive = await exportArchive({LogType.photo, LogType.audio});

    expect(archive.findFile('photo/files/a.jpg')!.content, [1, 2, 3]);
    expect(archive.findFile('audio/files/b.m4a')!.content, [4, 5, 6, 7]);
    expect(archive.findFile('photo/files/a-thumb.jpg'), isNull);

    final photoRow =
        (jsonIn(archive, 'photo/photo.json')['rows'] as List).single;
    expect(photoRow['caption'], 'By the lake');
    expect(photoRow['file'], 'files/a.jpg');
    final audioRow =
        (jsonIn(archive, 'audio/audio.json')['rows'] as List).single;
    expect(audioRow['title'], 'Voice note');
    expect(audioRow['note'], 'Call back');
    expect(audioRow['durationMs'], 42000);
    expect(audioRow['file'], 'files/b.m4a');
    expect(textIn(archive, 'photo/photo.md'), contains('By the lake'));
    expect(textIn(archive, 'audio/audio.md'), contains('Voice note'));
  });

  test('only the selected types are exported', () async {
    await repo.createText(body: 'Hello');
    await repo.createEmoji(emoji: '😌', strength: 3);

    final archive = await exportArchive({LogType.emoji});

    expect(archive.findFile('emoji/emoji.json'), isNotNull);
    expect(archive.findFile('text/text.json'), isNull);
  });

  test('logs in Trash are not exported', () async {
    await repo.createText(body: 'Keep');
    final gone = await repo.createText(body: 'Trashed');
    await repo.softDelete(gone);

    final archive = await exportArchive({LogType.text});

    final rows = jsonIn(archive, 'text/text.json')['rows'] as List;
    expect(rows.map((r) => r['body']), ['Keep']);
    expect(textIn(archive, 'text/text.md'), isNot(contains('Trashed')));
  });

  test('a selected type with no logs still exports an empty list', () async {
    final archive = await exportArchive({LogType.text});
    expect(jsonIn(archive, 'text/text.json')['rows'], isEmpty);
  });

  test('an empty selection is rejected', () async {
    await expectLater(
      service.exportTo(Directory(p.join(tempDir.path, 'out')), types: {}),
      throwsArgumentError,
    );
  });

  test('types that are not built yet are rejected', () async {
    await expectLater(
      service.exportTo(
        Directory(p.join(tempDir.path, 'out')),
        types: {LogType.video},
      ),
      throwsArgumentError,
    );
  });

  test('a missing media file is skipped without failing the export', () async {
    await repo.createPhoto(
      path: p.join(tempDir.path, 'gone.jpg'),
      thumbnailPath: p.join(tempDir.path, 'gone-thumb.jpg'),
    );

    final archive = await exportArchive({LogType.photo});

    expect(archive.findFile('photo/files/gone.jpg'), isNull);
    expect(jsonIn(archive, 'photo/photo.json')['rows'] as List, hasLength(1));
  });
}
