import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/video/video_detail_screen.dart';
import 'package:path/path.dart' as p;

import 'video_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;
  late VideoLog log;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('video_detail_test_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
    final id = await repo.createVideo(
      path: p.join(tempDir.path, 'a.mp4'),
      posterPath: (File(
        p.join(tempDir.path, 'a.jpg'),
      )..writeAsStringSync('fake')).path,
      duration: const Duration(seconds: 48),
      caption: 'Walk to the station',
      createdAt: DateTime.utc(2026, 11, 6, 12, 20),
    );
    log = await repo.getById(id) as VideoLog;
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    required FakeVideoPlaybackController playback,
    VideoLog? log_,
    VoidCallback? onBack,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: VideoDetailScreen(
          log: log_ ?? log,
          repository: repo,
          mediaStore: MediaStore(root: tempDir, clock: () => now),
          picker: FakeVideoPicker(),
          probe: FakeVideoProbe(),
          playback: playback,
          now: () => now,
          onBack: onBack ?? () {},
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets('loads the video and shows its date, length and caption', (
    tester,
  ) async {
    final playback = FakeVideoPlaybackController();
    await pump(tester, playback: playback);

    expect(playback.loadedPath, log.path);
    expect(find.text('Friday 6 November · 12:20'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('0:48'), findsOneWidget);
    expect(find.text('Walk to the station'), findsOneWidget);
    expect(find.text('Stored on this device'), findsOneWidget);

    await close(tester);
  });

  testWidgets('the poster gives way to the video once it is played', (
    tester,
  ) async {
    final playback = FakeVideoPlaybackController();
    await pump(tester, playback: playback);
    expect(find.byKey(const ValueKey('fake-video-view')), findsNothing);

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump(const Duration(milliseconds: 1));

    expect(playback.played, isTrue);
    expect(find.byKey(const ValueKey('fake-video-view')), findsOneWidget);
    expect(find.bySemanticsLabel('Pause'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump(const Duration(milliseconds: 1));

    expect(playback.paused, isTrue);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);

    await close(tester);
  });

  testWidgets('skipping forward and back seeks, clamped to the video', (
    tester,
  ) async {
    final playback = FakeVideoPlaybackController();
    await pump(tester, playback: playback);

    await tester.tap(find.bySemanticsLabel('Back 15 seconds'));
    await tester.pump(const Duration(milliseconds: 1));
    expect(playback.lastSeek, Duration.zero);

    await tester.tap(find.bySemanticsLabel('Forward 15 seconds'));
    await tester.pump(const Duration(milliseconds: 1));
    expect(playback.lastSeek, const Duration(seconds: 15));

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.bySemanticsLabel('Forward 15 seconds'));
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(playback.lastSeek, log.duration);

    await close(tester);
  });

  testWidgets('dragging the scrubber seeks within the video', (tester) async {
    final playback = FakeVideoPlaybackController();
    await pump(tester, playback: playback);

    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 1));

    expect(playback.lastSeek, isNotNull);
    expect(playback.lastSeek! > Duration.zero, isTrue);
    expect(playback.lastSeek! <= log.duration, isTrue);

    await close(tester);
  });

  testWidgets('the position label follows playback', (tester) async {
    final playback = FakeVideoPlaybackController();
    await pump(tester, playback: playback);

    await playback.seek(const Duration(seconds: 12));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('0:12'), findsOneWidget);

    await close(tester);
  });

  testWidgets('a video without a caption shows no caption text', (
    tester,
  ) async {
    final id = await repo.createVideo(
      path: p.join(tempDir.path, 'b.mp4'),
      posterPath: p.join(tempDir.path, 'b.jpg'),
      duration: const Duration(seconds: 5),
    );
    final bare = await repo.getById(id) as VideoLog;
    await pump(tester, playback: FakeVideoPlaybackController(), log_: bare);

    expect(find.text('Walk to the station'), findsNothing);
    expect(find.text('Stored on this device'), findsOneWidget);

    await close(tester);
  });

  testWidgets('Edit opens the caption editor; saving goes back', (
    tester,
  ) async {
    var backed = false;
    await pump(
      tester,
      playback: FakeVideoPlaybackController(),
      onBack: () => backed = true,
    );

    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Edited caption');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(backed, isTrue);
    expect((await repo.getById(log.id) as VideoLog).caption, 'Edited caption');

    await close(tester);
  });

  testWidgets('Delete soft-deletes the log and calls onBack', (tester) async {
    var backed = false;
    await pump(
      tester,
      playback: FakeVideoPlaybackController(),
      onBack: () => backed = true,
    );

    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pump();

    expect(backed, isTrue);
    expect((await repo.getById(log.id))!.deletedAt, isNotNull);

    await close(tester);
  });

  testWidgets('the back button calls onBack', (tester) async {
    var backed = false;
    await pump(
      tester,
      playback: FakeVideoPlaybackController(),
      onBack: () => backed = true,
    );

    await tester.tap(find.bySemanticsLabel('Back'));

    expect(backed, isTrue);

    await close(tester);
  });

  testWidgets('leaving the screen disposes the player', (tester) async {
    final playback = FakeVideoPlaybackController();
    await pump(tester, playback: playback);

    await close(tester);

    expect(playback.disposed, isTrue);
  });
}
