import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/audio/audio_recorder_controller.dart';
import 'package:moment/audio/create_audio_screen.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:path/path.dart' as p;

class _FakeAudioRecorderController implements AudioRecorderController {
  _FakeAudioRecorderController({this.permissionGranted = true, this.stopPath});

  final bool permissionGranted;
  String? stopPath;

  final _amplitude = StreamController<double>.broadcast();
  bool started = false;
  bool paused = false;
  bool resumed = false;
  bool stopped = false;
  bool canceled = false;
  bool disposed = false;

  @override
  Stream<double> get amplitudeStream => _amplitude.stream;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> resume() async {
    resumed = true;
    paused = false;
  }

  @override
  Future<String?> stop() async {
    stopped = true;
    return stopPath;
  }

  @override
  Future<void> cancel() async => canceled = true;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _amplitude.close();
  }

  void emit(double value) => _amplitude.add(value);
}

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;
  late MediaStore mediaStore;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('create_audio_screen_test_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
    mediaStore = MediaStore(
      root: Directory(p.join(tempDir.path, 'app_support')),
      clock: () => now,
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    required _FakeAudioRecorderController recorder,
    ValueChanged<String>? onSaved,
    VoidCallback? onClose,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: CreateAudioScreen(
          repository: repo,
          mediaStore: mediaStore,
          recorder: recorder,
          now: () => now,
          onSaved: onSaved ?? (_) {},
          onClose: onClose ?? () {},
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

  testWidgets('starts recording as soon as the screen opens', (tester) async {
    final recorder = _FakeAudioRecorderController();
    await pump(tester, recorder: recorder);

    expect(recorder.started, isTrue);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    await close(tester);
  });

  testWidgets('each amplitude sample grows the timer and the waveform', (
    tester,
  ) async {
    final recorder = _FakeAudioRecorderController();
    await pump(tester, recorder: recorder);

    recorder.emit(0.4);
    await tester.pump();
    recorder.emit(0.8);
    await tester.pump();

    expect(find.text('00:00'), findsNothing);
    expect(
      find.text(
        '00:${(audioSampleInterval.inMilliseconds * 2 ~/ 1000).toString().padLeft(2, '0')}',
      ),
      findsOneWidget,
    );

    await close(tester);
  });

  testWidgets('Pause pauses the recorder and shows Resume', (tester) async {
    final recorder = _FakeAudioRecorderController();
    await pump(tester, recorder: recorder);

    await tester.tap(find.text('Pause'));
    await tester.pump();

    expect(recorder.paused, isTrue);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();

    expect(recorder.resumed, isTrue);
    expect(find.text('Pause'), findsOneWidget);

    await close(tester);
  });

  testWidgets('Discard cancels the recording and calls onClose', (
    tester,
  ) async {
    final recorder = _FakeAudioRecorderController();
    var closed = false;
    await pump(tester, recorder: recorder, onClose: () => closed = true);

    await tester.tap(find.text('Discard'));
    await tester.pump();

    expect(recorder.canceled, isTrue);
    expect(closed, isTrue);
    expect(await db.select(db.logsTable).get(), isEmpty);

    await close(tester);
  });

  testWidgets('Save stops the recorder, imports the file and creates an '
      'audio log', (tester) async {
    final recordedFile = File(p.join(tempDir.path, 'recorded.m4a'))
      ..writeAsBytesSync([9, 9, 9]);
    final recorder = _FakeAudioRecorderController(
      stopPath: recordedFile.path,
    );
    String? savedId;
    await pump(
      tester,
      recorder: recorder,
      onSaved: (id) => savedId = id,
    );

    recorder.emit(0.2);
    await tester.pump();
    recorder.emit(0.6);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Morning thoughts');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(recorder.stopped, isTrue);
    expect(savedId, isNotNull);

    final log = await repo.getById(savedId!) as AudioLog;
    expect(log.title, 'Morning thoughts');
    expect(log.peaks, [0.2, 0.6]);
    expect(log.duration, audioSampleInterval * 2);
    expect(File(log.path).existsSync(), isTrue);
    expect(log.path, isNot(recordedFile.path));

    await close(tester);
  });

  testWidgets('Save with a blank title saves a null title', (tester) async {
    final recordedFile = File(p.join(tempDir.path, 'recorded.m4a'))
      ..writeAsBytesSync([1]);
    final recorder = _FakeAudioRecorderController(
      stopPath: recordedFile.path,
    );
    String? savedId;
    await pump(tester, recorder: recorder, onSaved: (id) => savedId = id);

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    final log = await repo.getById(savedId!) as AudioLog;
    expect(log.title, isNull);

    await close(tester);
  });
}
