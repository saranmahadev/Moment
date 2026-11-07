import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/photo/photo_detail_screen.dart';
import 'package:moment/photo/photo_picker.dart';
import 'package:path/path.dart' as p;

class _FakePhotoPicker implements PhotoPicker {
  @override
  Future<File?> pickFromCamera() async => null;

  @override
  Future<File?> pickFromGallery() async => null;
}

void main() {
  final now = DateTime.utc(2026, 11, 6, 20, 12);
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;
  late MediaStore mediaStore;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('photo_detail_test_');
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

  File fakeFile(String name) {
    final file = File(p.join(tempDir.path, name));
    file.writeAsStringSync('fake');
    return file;
  }

  Future<void> pump(
    WidgetTester tester,
    PhotoLog log, {
    VoidCallback? onBack,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: PhotoDetailScreen(
          log: log,
          repository: repo,
          mediaStore: mediaStore,
          picker: _FakePhotoPicker(),
          now: () => now,
          onBack: onBack,
        ),
      ),
    );
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets('shows the date, time and caption', (tester) async {
    final id = await repo.createPhoto(
      path: fakeFile('a.jpg').path,
      thumbnailPath: fakeFile('a-thumb.jpg').path,
      caption: 'Morning light on the balcony.',
    );
    final log = await repo.getById(id) as PhotoLog;

    await pump(tester, log);

    expect(find.text('Friday 6 November · 20:12'), findsOneWidget);
    expect(find.text('Morning light on the balcony.'), findsOneWidget);

    await close(tester);
  });

  testWidgets('the back button calls onBack', (tester) async {
    final id = await repo.createPhoto(
      path: fakeFile('a.jpg').path,
      thumbnailPath: fakeFile('a-thumb.jpg').path,
    );
    final log = await repo.getById(id) as PhotoLog;
    var backed = false;

    await pump(tester, log, onBack: () => backed = true);
    await tester.tap(find.bySemanticsLabel('Back'));

    expect(backed, isTrue);

    await close(tester);
  });

  testWidgets('delete soft-deletes the log and goes back', (tester) async {
    final id = await repo.createPhoto(
      path: fakeFile('a.jpg').path,
      thumbnailPath: fakeFile('a-thumb.jpg').path,
    );
    final log = await repo.getById(id) as PhotoLog;
    var backed = false;

    await pump(tester, log, onBack: () => backed = true);
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pump();

    expect(backed, isTrue);
    final deleted = await repo.getById(id);
    expect(deleted!.deletedAt, isNotNull);

    await close(tester);
  });

  testWidgets('edit opens CreatePhotoScreen prefilled, saving goes back', (
    tester,
  ) async {
    final id = await repo.createPhoto(
      path: fakeFile('a.jpg').path,
      thumbnailPath: fakeFile('a-thumb.jpg').path,
      caption: 'Original caption',
    );
    final log = await repo.getById(id) as PhotoLog;
    var backed = false;

    await pump(tester, log, onBack: () => backed = true);
    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Original caption'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Edited caption');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(backed, isTrue);
    final updated = await repo.getById(id) as PhotoLog;
    expect(updated.caption, 'Edited caption');

    await close(tester);
  });
}
