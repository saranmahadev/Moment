import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/audio/audio_detail_screen.dart';
import 'package:moment/audio/audio_playback_controller.dart';
import 'package:moment/audio/player_waveform.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';

class _FakeAudioPlaybackController implements AudioPlaybackController {
  final _position = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();

  String? loadedPath;
  bool played = false;
  bool paused = false;
  Duration? lastSeek;
  bool? loop;
  double? speed;
  bool disposed = false;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<Duration?> get durationStream => _duration.stream;

  /// The player reports how long the file really is.
  void reportDuration(Duration d) => _duration.add(d);

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
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  Future<void> setLoop(bool on) async => loop = on;

  /// The recording reached its end.
  void ended() => _playing.add(false);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _position.close();
    await _playing.close();
    await _duration.close();
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

  testWidgets('uses the length the player finds in the file, so the end fills '
      'the waveform even when the saved length ran long', (tester) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback); // saved as 42 s

    playback.reportDuration(const Duration(seconds: 40));
    await tester.pump(const Duration(milliseconds: 1));
    await playback.seek(const Duration(seconds: 40)); // the real end
    await tester.pump(const Duration(milliseconds: 1));

    final wave = tester.widget<PlayerWaveform>(find.byType(PlayerWaveform));
    expect(wave.duration, const Duration(seconds: 40));
    expect(wave.position, wave.duration);
    expect(find.text('0:40'), findsNWidgets(2)); // position and total

    await close(tester);
  });

  testWidgets('skipping and seeking stay inside the real length', (
    tester,
  ) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);
    playback.reportDuration(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 1));

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Forward 15 seconds'));
      await tester.pump(const Duration(milliseconds: 1));
    }

    expect(playback.lastSeek, const Duration(seconds: 20));

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

    // The fallback title, and the type badge on the artwork.
    expect(find.text('Audio'), findsNWidgets(2));

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

  testWidgets('Edit lets the title be changed, Save stores it', (tester) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);

    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Morning thoughts');
    await tester.tap(find.bySemanticsLabel('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Morning thoughts'), findsOneWidget);

    final updated = await repo.getById(log.id) as AudioLog;
    expect(updated.title, 'Morning thoughts');

    await close(tester);
  });

  testWidgets('shows no note: nothing is transcribed, so there is no text '
      'under the player', (tester) async {
    await repo.updateAudio(log.id, title: 'Voice note', note: 'old note');
    final withNote = await repo.getById(log.id) as AudioLog;
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback, log_: withNote);

    expect(find.text('old note'), findsNothing);

    await close(tester);
  });

  testWidgets('when the recording ends the button offers Play again', (
    tester,
  ) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    playback.ended();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);

    await close(tester);
  });

  testWidgets('Loop is off until asked for, then on, then off', (tester) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);

    await tester.tap(find.bySemanticsLabel('Loop off'));
    await tester.pump();
    expect(playback.loop, isTrue);
    expect(find.bySemanticsLabel('Loop on'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Loop on'));
    await tester.pump();
    expect(playback.loop, isFalse);

    await close(tester);
  });

  testWidgets('the speed chip steps 1x, 1.25x, 1.5x, 2x, 0.75x and round', (
    tester,
  ) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);

    final seen = <double>[];
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.textContaining('×'));
      await tester.pump();
      seen.add(playback.speed!);
    }

    expect(seen, [1.25, 1.5, 2.0, 0.75, 1.0]);
    expect(find.text('1×'), findsOneWidget);

    await close(tester);
  });

  testWidgets('the waveform is a slider and scrubbing it seeks', (
    tester,
  ) async {
    final playback = _FakeAudioPlaybackController();
    await pump(tester, playback: playback);

    final rect = tester.getRect(find.byType(PlayerWaveform));
    final gesture = await tester.startGesture(
      rect.centerLeft + const Offset(4, 0),
    );
    await gesture.moveTo(rect.center);
    await gesture.up();
    await tester.pump();

    expect(
      playback.lastSeek!.inSeconds,
      inInclusiveRange(18, 24),
    ); // about half of 42 s

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
