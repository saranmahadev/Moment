import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/audio/audio_detail_screen.dart';
import 'package:moment/audio/audio_playback_controller.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';

class _FakeAudioPlaybackController implements AudioPlaybackController {
  final _position = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  String? loadedPath;
  bool played = false;
  bool paused = false;
  Duration? lastSeek;
  bool disposed = false;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<void> load(String path) async => loadedPath = path;

  @override
  Future<void> play() async {
    played = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    paused = true;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _position.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _position.close();
    await _playing.close();
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;
  late AudioLog log;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('audio_detail_screen_test_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
    final id = await repo.createAudio(
      path: '/media/2026/11/a.m4a',
      duration: const Duration(seconds: 42),
      peaks: [0.2, 0.5, 0.8, 0.3],
      title: 'Voice note',
      createdAt: DateTime.utc(2026, 11, 6, 18, 5),
    );
    log = await repo.getById(id) as AudioLog;
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    required _FakeAudioPlaybackController playback,
    AudioLog? log_,
    VoidCallback? onBack,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: AudioDetailScreen(
          log: log_ ?? log,
          repository: repo,
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

  testWidgets('loads the recording and shows its title, date and duration', (
    tester,
  ) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);

    expect(playback.loadedPath, log.path);
    expect(find.text('Voice note'), findsOneWidget);
    expect(find.textContaining('Friday 6 November'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget);

    await close(tester);
  });

  testWidgets('falls back to "Audio" when there is no title', (tester) async {
    final untitled = AudioLog(
      id: log.id,
      createdAt: log.createdAt,
      tzOffsetMinutes: log.tzOffsetMinutes,
      editedAt: null,
      deletedAt: null,
      path: log.path,
      duration: log.duration,
      peaks: log.peaks,
      title: null,
      note: null,
    );
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback, log_: untitled);

    expect(find.text('Audio'), findsOneWidget);

    await close(tester);
  });

  testWidgets('tapping play plays, tapping again pauses', (tester) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(milliseconds: 1));

    expect(playback.played, isTrue);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump(const Duration(milliseconds: 1));

    expect(playback.paused, isTrue);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await close(tester);
  });

  testWidgets('skipping forward 15s seeks ahead, clamped to the duration', (
    tester,
  ) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);

    await tester.tap(find.bySemanticsLabel('Forward 15 seconds'));
    await tester.pump(const Duration(milliseconds: 1));
    expect(playback.lastSeek, const Duration(seconds: 15));

    // Three more skips would reach 60s, well past the 42s duration.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Forward 15 seconds'));
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(playback.lastSeek, log.duration);

    await close(tester);
  });

  testWidgets('skipping back 15s seeks behind, clamped to zero', (
    tester,
  ) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);

    await tester.tap(find.bySemanticsLabel('Back 15 seconds'));
    await tester.pump(const Duration(milliseconds: 1));

    expect(playback.lastSeek, Duration.zero);

    await close(tester);
  });

  testWidgets('Edit lets the title and note be changed, Save stores them', (
    tester,
  ) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);

    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.pump();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.first, 'Morning thoughts');
    await tester.enterText(fields.last, 'Remember to call back');
    await tester.tap(find.bySemanticsLabel('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Morning thoughts'), findsOneWidget);
    expect(find.text('Remember to call back'), findsOneWidget);

    final updated = await repo.getById(log.id) as AudioLog;
    expect(updated.title, 'Morning thoughts');
    expect(updated.note, 'Remember to call back');

    await close(tester);
  });

  testWidgets('Delete soft-deletes the log and calls onBack', (tester) async {
    var backCalled = false;
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback, onBack: () => backCalled = true);

    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pump();

    expect(backCalled, isTrue);
    final deleted = await repo.getById(log.id);
    expect(deleted!.deletedAt, isNotNull);

    await close(tester);
  });

  testWidgets('the back button calls onBack', (tester) async {
    var backCalled = false;
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback, onBack: () => backCalled = true);

    await tester.tap(find.bySemanticsLabel('Back'));

    expect(backCalled, isTrue);

    await close(tester);
  });
}
