import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/video/create_video_screen.dart';
import 'package:path/path.dart' as p;

import 'video_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;
  late MediaStore mediaStore;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('create_video_screen_test_');
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

  File sourceVideo() =>
      File(p.join(tempDir.path, 'clip.mp4'))..writeAsBytesSync([1, 2, 3, 4]);

  Future<void> pump(
    WidgetTester tester, {
    required FakeVideoPicker picker,
    FakeVideoProbe? probe,
    ValueChanged<String>? onSaved,
    VoidCallback? onClose,
    VideoLog? editing,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: CreateVideoScreen(
          repository: repo,
          mediaStore: mediaStore,
          picker: picker,
          probe: probe ?? FakeVideoProbe(),
          now: () => now,
          onSaved: onSaved ?? (_) {},
          onClose: onClose ?? () {},
          editing: editing,
        ),
      ),
    );
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }

  /// Importing copies a real file, so the tap that starts it has to run
  /// outside flutter_test's fake-clock zone.
  Future<void> tapForReal(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('offers Record Video and Choose from Library to begin with', (
    tester,
  ) async {
    await pump(tester, picker: FakeVideoPicker());

    expect(find.text('Record Video'), findsOneWidget);
    expect(find.text('Choose from Library'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await close(tester);
  });

  testWidgets('recording a video shows it as selected, with Save', (
    tester,
  ) async {
    await pump(tester, picker: FakeVideoPicker(cameraResult: sourceVideo()));

    await tester.tap(find.text('Record Video'));
    await tester.pumpAndSettle();

    expect(find.text('Record Video'), findsNothing);
    expect(find.text('Video selected'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await close(tester);
  });

  testWidgets('cancelling the picker stays on the choices', (tester) async {
    await pump(tester, picker: FakeVideoPicker());

    await tester.tap(find.text('Choose from Library'));
    await tester.pumpAndSettle();

    expect(find.text('Choose from Library'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await close(tester);
  });

  testWidgets('Save imports the video and creates a video log', (tester) async {
    String? savedId;
    await pump(
      tester,
      picker: FakeVideoPicker(galleryResult: sourceVideo()),
      onSaved: (id) => savedId = id,
    );

    await tester.tap(find.text('Choose from Library'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Walk to the station');
    await tapForReal(tester, find.text('Save'));

    expect(savedId, isNotNull);
    final log = await repo.getById(savedId!) as VideoLog;
    expect(log.caption, 'Walk to the station');
    expect(log.duration, const Duration(seconds: 48));
    expect(File(log.path).readAsBytesSync(), [1, 2, 3, 4]);
    expect(File(log.posterPath).existsSync(), isTrue);
    expect(log.createdAt, now);

    await close(tester);
  });

  testWidgets('a blank caption is saved as no caption', (tester) async {
    String? savedId;
    await pump(
      tester,
      picker: FakeVideoPicker(galleryResult: sourceVideo()),
      onSaved: (id) => savedId = id,
    );

    await tester.tap(find.text('Choose from Library'));
    await tester.pumpAndSettle();
    await tapForReal(tester, find.text('Save'));

    expect((await repo.getById(savedId!) as VideoLog).caption, isNull);

    await close(tester);
  });

  testWidgets('a video that cannot be read says so and saves nothing', (
    tester,
  ) async {
    String? savedId;
    await pump(
      tester,
      picker: FakeVideoPicker(galleryResult: sourceVideo()),
      probe: FakeVideoProbe(readable: false),
      onSaved: (id) => savedId = id,
    );

    await tester.tap(find.text('Choose from Library'));
    await tester.pumpAndSettle();
    await tapForReal(tester, find.text('Save'));

    expect(savedId, isNull);
    expect(find.text('This video could not be read.'), findsOneWidget);
    expect(find.text('Choose from Library'), findsOneWidget);
    expect(await db.select(db.logsTable).get(), isEmpty);

    await close(tester);
  });

  testWidgets('Close calls onClose without creating a log', (tester) async {
    var closed = false;
    await pump(tester, picker: FakeVideoPicker(), onClose: () => closed = true);

    await tester.tap(find.bySemanticsLabel('Close without saving'));

    expect(closed, isTrue);
    expect(await db.select(db.logsTable).get(), isEmpty);

    await close(tester);
  });

  group('editing an existing log', () {
    Future<VideoLog> existing() async {
      final id = await repo.createVideo(
        path: p.join(tempDir.path, 'a.mp4'),
        posterPath: p.join(tempDir.path, 'a-poster.jpg'),
        duration: const Duration(seconds: 48),
        caption: 'Original caption',
      );
      return await repo.getById(id) as VideoLog;
    }

    testWidgets('shows the caption and no picker buttons', (tester) async {
      await pump(tester, picker: FakeVideoPicker(), editing: await existing());

      expect(find.text('Record Video'), findsNothing);
      expect(find.text('Original caption'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await close(tester);
    });

    testWidgets('Save updates the caption in place', (tester) async {
      final log = await existing();
      String? savedId;
      await pump(
        tester,
        picker: FakeVideoPicker(),
        editing: log,
        onSaved: (id) => savedId = id,
      );

      await tester.enterText(find.byType(TextField), 'Edited caption');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedId, log.id);
      expect(
        (await repo.getById(log.id) as VideoLog).caption,
        'Edited caption',
      );
      expect(await db.select(db.logsTable).get(), hasLength(1));

      await close(tester);
    });

    testWidgets('clearing the caption removes it', (tester) async {
      final log = await existing();
      await pump(tester, picker: FakeVideoPicker(), editing: log);

      await tester.enterText(find.byType(TextField), '  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect((await repo.getById(log.id) as VideoLog).caption, isNull);

      await close(tester);
    });
  });
}
