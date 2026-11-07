import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/photo/create_photo_screen.dart';
import 'package:moment/photo/photo_picker.dart';
import 'package:path/path.dart' as p;

File _sampleSourcePhoto(String path) {
  final image = img.Image(width: 800, height: 600);
  img.fill(image, color: img.ColorRgb8(180, 140, 100));
  final file = File(path);
  file.writeAsBytesSync(img.encodeJpg(image));
  return file;
}

class _FakePhotoPicker implements PhotoPicker {
  _FakePhotoPicker({this.cameraResult, this.galleryResult});

  File? cameraResult;
  File? galleryResult;

  @override
  Future<File?> pickFromCamera() async => cameraResult;

  @override
  Future<File?> pickFromGallery() async => galleryResult;
}

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;
  late MediaStore mediaStore;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('create_photo_screen_test_');
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
    required _FakePhotoPicker picker,
    ValueChanged<String>? onSaved,
    VoidCallback? onClose,
    PhotoLog? editing,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: CreatePhotoScreen(
          repository: repo,
          mediaStore: mediaStore,
          picker: picker,
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

  testWidgets('offers Take Photo and Choose from Library when nothing is '
      'picked yet', (tester) async {
    await pump(tester, picker: _FakePhotoPicker());

    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Library'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await close(tester);
  });

  testWidgets(
    'choosing from the library shows a preview and the Save button',
    (tester) async {
      final source = _sampleSourcePhoto(p.join(tempDir.path, 'source.jpg'));
      await pump(
        tester,
        picker: _FakePhotoPicker(galleryResult: source),
      );

      await tester.tap(find.text('Choose from Library'));
      await tester.pumpAndSettle();

      expect(find.text('Take Photo'), findsNothing);
      expect(find.byType(Image), findsWidgets);
      expect(find.text('Save'), findsOneWidget);

      await close(tester);
    },
  );

  testWidgets('Save imports the photo and creates a photo log', (
    tester,
  ) async {
    final source = _sampleSourcePhoto(p.join(tempDir.path, 'source.jpg'));
    String? savedId;
    await pump(
      tester,
      picker: _FakePhotoPicker(galleryResult: source),
      onSaved: (id) => savedId = id,
    );

    await tester.tap(find.text('Choose from Library'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'By the lake');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedId, isNotNull);
    final log = await repo.getById(savedId!) as PhotoLog;
    expect(log.caption, 'By the lake');
    expect(File(log.path).existsSync(), isTrue);
    expect(File(log.thumbnailPath).existsSync(), isTrue);

    await close(tester);
  });

  testWidgets('Close calls onClose without creating a log', (tester) async {
    var closed = false;
    await pump(
      tester,
      picker: _FakePhotoPicker(),
      onClose: () => closed = true,
    );

    await tester.tap(find.bySemanticsLabel('Close without saving'));

    expect(closed, isTrue);
    expect(await db.select(db.logsTable).get(), isEmpty);

    await close(tester);
  });

  group('editing an existing log', () {
    testWidgets('shows the existing photo and caption, no picker buttons', (
      tester,
    ) async {
      final source = _sampleSourcePhoto(p.join(tempDir.path, 'source.jpg'));
      final imported = await mediaStore.importPhoto(source);
      final id = await repo.createPhoto(
        path: imported.path,
        thumbnailPath: imported.thumbnailPath,
        caption: 'Original caption',
      );
      final existing = await repo.getById(id) as PhotoLog;

      await pump(
        tester,
        picker: _FakePhotoPicker(),
        editing: existing,
      );

      expect(find.text('Take Photo'), findsNothing);
      expect(find.text('Original caption'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await close(tester);
    });

    testWidgets('Save updates the caption in place', (tester) async {
      final source = _sampleSourcePhoto(p.join(tempDir.path, 'source.jpg'));
      final imported = await mediaStore.importPhoto(source);
      final id = await repo.createPhoto(
        path: imported.path,
        thumbnailPath: imported.thumbnailPath,
        caption: 'Original caption',
      );
      final existing = await repo.getById(id) as PhotoLog;
      String? savedId;

      await pump(
        tester,
        picker: _FakePhotoPicker(),
        editing: existing,
        onSaved: (savedWith) => savedId = savedWith,
      );
      await tester.enterText(find.byType(TextField), 'Edited caption');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedId, id);
      final updated = await repo.getById(id) as PhotoLog;
      expect(updated.caption, 'Edited caption');
      expect(await db.select(db.logsTable).get(), hasLength(1));

      await close(tester);
    });
  });
}
