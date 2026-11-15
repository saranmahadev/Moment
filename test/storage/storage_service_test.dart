import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/storage/storage_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;
  late StorageService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('storage_service_test_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db);
    service = StorageService(repository: repo);
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  File mediaFile(String name, int size) =>
      File(p.join(tempDir.path, name))..writeAsBytesSync(List.filled(size, 7));

  test('every built type is reported, at zero for an empty library', () async {
    final usage = await service.measure();

    expect(usage.keys, builtLogTypes);
    expect(usage.values, everyElement(0));
  });

  test('text and emoji count the bytes of what was written', () async {
    await repo.createText(body: 'hello'); // 5 bytes
    await repo.createText(body: 'héllo'); // 6 bytes in UTF-8
    await repo.createEmoji(emoji: '😌', label: 'Calm', strength: 4);

    final usage = await service.measure();

    expect(usage[LogType.text], 11);
    expect(usage[LogType.emoji], 4 + 4); // 😌 is 4 bytes, "Calm" is 4
  });

  test('photos count the original and the thumbnail', () async {
    await repo.createPhoto(
      path: mediaFile('a.jpg', 1000).path,
      thumbnailPath: mediaFile('a-thumb.jpg', 100).path,
    );

    expect((await service.measure())[LogType.photo], 1100);
  });

  test('audio counts the recording', () async {
    await repo.createAudio(
      path: mediaFile('a.m4a', 2500).path,
      duration: const Duration(seconds: 3),
      peaks: [0.1],
    );

    expect((await service.measure())[LogType.audio], 2500);
  });

  test('video counts the clip and its poster', () async {
    await repo.createVideo(
      path: mediaFile('a.mp4', 5000).path,
      posterPath: mediaFile('a-poster.jpg', 300).path,
      duration: const Duration(seconds: 3),
    );

    expect((await service.measure())[LogType.video], 5300);
  });

  test('logs in Trash still take up space until they are purged', () async {
    final id = await repo.createAudio(
      path: mediaFile('a.m4a', 2500).path,
      duration: const Duration(seconds: 3),
      peaks: [0.1],
    );
    await repo.softDelete(id);

    expect((await service.measure())[LogType.audio], 2500);
  });

  test('a missing file counts as nothing rather than failing', () async {
    await repo.createAudio(
      path: p.join(tempDir.path, 'gone.m4a'),
      duration: const Duration(seconds: 3),
      peaks: [0.1],
    );

    expect((await service.measure())[LogType.audio], 0);
  });

  group('formatBytes', () {
    test('rounds to a readable unit, with "<1 MB" for the very small', () {
      expect(formatBytes(0), '<1 MB');
      expect(formatBytes(900 * 1024), '<1 MB');
      expect(formatBytes(1024 * 1024), '1 MB');
      expect(formatBytes(180 * 1024 * 1024), '180 MB');
      expect(formatBytes((1.1 * 1024 * 1024 * 1024).round()), '1.1 GB');
      expect(formatBytes((2.4 * 1024 * 1024 * 1024).round()), '2.4 GB');
    });
  });
}
