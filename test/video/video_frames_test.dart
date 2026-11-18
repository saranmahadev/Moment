import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/video/video_frames.dart';
import 'package:path/path.dart' as p;

import 'video_fakes.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('video_frames_test_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db);
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<VideoLog> video({int seconds = 48, String name = 'a'}) async {
    final id = await repo.createVideo(
      path: p.join(tempDir.path, '$name.mp4'),
      posterPath: p.join(tempDir.path, '$name.jpg'),
      duration: Duration(seconds: seconds),
    );
    return await repo.getById(id) as VideoLog;
  }

  VideoFrameStrip strip(
    FakeVideoProbe probe, {
    int count = 12,
    int maxCachedVideos = 40,
  }) => VideoFrameStrip(
    probe: probe,
    cacheRoot: Directory(p.join(tempDir.path, 'cache')),
    count: count,
    maxCachedVideos: maxCachedVideos,
  );

  test(
    'takes one frame from the middle of each equal slice of the clip',
    () async {
      final probe = FakeVideoProbe();
      final log = await video();

      final lists = await strip(probe).framesFor(log).toList();

      expect(probe.frameRequests.map((r) => r.at.inSeconds), [
        for (var i = 0; i < 12; i++) 2 + 4 * i,
      ]);
      expect(lists.last, hasLength(12));
      expect(lists.last.every((f) => f != null && f.existsSync()), isTrue);
    },
  );

  test('the strip fills in as frames are made', () async {
    final probe = FakeVideoProbe();
    final lists = await strip(
      probe,
      count: 4,
    ).framesFor(await video()).toList();

    expect(lists.first.every((f) => f == null), isTrue);
    expect(lists.map((l) => l.whereType<File>().length), [0, 1, 2, 3, 4]);
  });

  test('frames made before are reused, not made again', () async {
    final probe = FakeVideoProbe();
    final log = await video();
    final frames = strip(probe, count: 4);

    await frames.framesFor(log).toList();
    probe.frameRequests.clear();
    final again = await frames.framesFor(log).toList();

    expect(probe.frameRequests, isEmpty);
    expect(again.last.whereType<File>(), hasLength(4));
  });

  test(
    'a frame that cannot be made is a gap; the others are still made',
    () async {
      final probe = FakeVideoProbe(failFramesAt: {6});
      final lists = await strip(
        probe,
        count: 4,
      ).framesFor(await video()).toList();

      // 48 s in 4 slices: frames at 6, 18, 30 and 42 seconds.
      expect(lists.last.map((f) => f != null), [false, true, true, true]);
    },
  );

  test('a very short clip still gets distinct times inside it', () async {
    final probe = FakeVideoProbe();
    await strip(probe, count: 4).framesFor(await video(seconds: 2)).toList();

    final times = probe.frameRequests.map((r) => r.at).toList();
    expect(
      times.every((t) => t >= Duration.zero && t < const Duration(seconds: 2)),
      isTrue,
    );
    expect(times.toSet(), hasLength(4));
  });

  test('frames live in a folder per video under the cache', () async {
    final log = await video();
    final frames = strip(FakeVideoProbe());

    expect(
      frames.dirFor(log.id).path,
      p.join(tempDir.path, 'cache', 'video-frames', log.id),
    );
  });

  test('only the most recently used videos keep their frames', () async {
    final probe = FakeVideoProbe();
    final frames = strip(probe, count: 2, maxCachedVideos: 2);
    final a = await video(name: 'a');
    final b = await video(name: 'b');
    final c = await video(name: 'c');

    await frames.framesFor(a).toList();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await frames.framesFor(b).toList();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await frames.framesFor(c).toList();

    expect(frames.dirFor(a.id).existsSync(), isFalse);
    expect(frames.dirFor(b.id).existsSync(), isTrue);
    expect(frames.dirFor(c.id).existsSync(), isTrue);
  });

  test('delete removes one video\'s frames', () async {
    final frames = strip(FakeVideoProbe(), count: 2);
    final log = await video();
    await frames.framesFor(log).toList();

    await frames.delete(log.id);

    expect(frames.dirFor(log.id).existsSync(), isFalse);
  });
}
