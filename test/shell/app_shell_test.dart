import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/design/orb_field.dart';
import 'package:moment/lock/app_lock_controller.dart';
import 'package:moment/lock/pin_storage.dart';
import 'package:image/image.dart' as img;
import 'package:moment/photo/photo_picker.dart';
import 'package:moment/shell/app_shell.dart';
import 'package:path/path.dart' as p;

File _sampleSourcePhoto(String path) {
  final image = img.Image(width: 800, height: 600);
  img.fill(image, color: img.ColorRgb8(180, 140, 100));
  final file = File(path);
  file.writeAsBytesSync(img.encodeJpg(image));
  return file;
}

class _FakePinStorage implements PinStorage {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String value) async => stored = value;

  @override
  Future<void> clear() async => stored = null;
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
  final now = DateTime.utc(2026, 11, 6, 21, 50);
  late Directory tempDir;
  late MediaStore mediaStore;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('app_shell_test_');
    mediaStore = MediaStore(
      root: Directory(p.join(tempDir.path, 'app_support')),
      clock: () => now,
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo, {
    PhotoPicker? picker,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    return tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: AppShell(
          repository: repo,
          lockController: AppLockController(_FakePinStorage()),
          mediaStore: mediaStore,
          picker: picker ?? _FakePhotoPicker(),
          now: () => now,
        ),
      ),
    );
  }

  testWidgets('shows Home by default', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('Friday'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows the decorative background orbs behind every tab', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();
    expect(find.byType(OrbField), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pump();
    expect(find.byType(OrbField), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pump();
    expect(find.byType(OrbField), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('the dock has all five destinations', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    for (final label in [
      'Home',
      'Library',
      'Add a log',
      'Calendar',
      'Settings',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping Library switches away from Home', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pump();

    expect(find.text('Friday'), findsNothing);
    expect(
      find.text('Everything you have logged, one section per type.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Library content clears the floating dock, down to Trash', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Trash'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    final trashBottom = tester.getBottomLeft(find.text('Trash')).dy;
    final dockTop = tester
        .getTopLeft(find.byKey(const ValueKey('dock-tab-Library')))
        .dy;
    expect(trashBottom, lessThan(dockTop));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping a type tile in Library opens its SectionScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'In the section');

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pump();
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();

    expect(find.text('In the section'), findsOneWidget);
    expect(find.text('1 log'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping Add opens the Add sheet', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Add a log'));
    await tester.pumpAndSettle();

    expect(find.text('Add to your log'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('picking Emoji from the Add sheet opens CreateEmojiScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Add a log'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('add-sheet-type-LogType.emoji')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add to your log'), findsNothing);
    expect(find.text('Log mood'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets(
    'saving a new mood from the Add flow returns to Home with it visible',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LogRepository(db, clock: () => now);

      await pump(tester, repo);
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Add a log'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('add-sheet-type-LogType.emoji')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log mood'));
      await tester.pumpAndSettle();

      expect(find.text('Happy'), findsOneWidget);
      expect(find.text('Log mood'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );

  testWidgets('picking Text from the Add sheet opens CreateTextScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Add a log'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-sheet-type-LogType.text')));
    await tester.pumpAndSettle();

    expect(find.text('Add to your log'), findsNothing);
    expect(find.bySemanticsLabel('Close without saving'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets(
    'saving a new text log from the Add flow returns to Home with it visible',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LogRepository(db, clock: () => now);

      await pump(tester, repo);
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Add a log'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('add-sheet-type-LogType.text')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'From the shell');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('From the shell'), findsOneWidget);
      expect(find.bySemanticsLabel('Close without saving'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );

  testWidgets('picking Photo from the Add sheet opens CreatePhotoScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Add a log'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('add-sheet-type-LogType.photo')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add to your log'), findsNothing);
    expect(find.text('Take Photo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets(
    'saving a new photo from the Add flow returns to Home with it visible',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LogRepository(db, clock: () => now);
      final source = _sampleSourcePhoto(p.join(tempDir.path, 'source.jpg'));

      await pump(tester, repo, picker: _FakePhotoPicker(galleryResult: source));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Add a log'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('add-sheet-type-LogType.photo')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Library'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'From the shell');

      // MediaStore.importPhoto runs in a real isolate (compute()), so the
      // Save tap has to happen inside runAsync for its completion to be
      // observed from flutter_test's fake-clock zone.
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      await tester.pump();

      expect(find.text('Take Photo'), findsNothing);
      expect(find.text('From the shell'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );

  testWidgets('tapping a photo tile in Library opens PhotoSectionScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createPhoto(
      path: (File(
        p.join(tempDir.path, 'a.jpg'),
      )..writeAsStringSync('fake')).path,
      thumbnailPath: (File(
        p.join(tempDir.path, 'a-thumb.jpg'),
      )..writeAsStringSync('fake')).path,
    );

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pump();
    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();

    expect(find.text('1 log'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping a photo card on Home opens PhotoDetailScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createPhoto(
      path: (File(
        p.join(tempDir.path, 'a.jpg'),
      )..writeAsStringSync('fake')).path,
      thumbnailPath: (File(
        p.join(tempDir.path, 'a-thumb.jpg'),
      )..writeAsStringSync('fake')).path,
      caption: 'Tap me',
    );

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping Trash in Library opens TrashScreen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(body: 'In the trash');
    await repo.softDelete(id);

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pump();
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();

    expect(find.text('In the trash'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping a text card on Home opens TextDetailScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'Open me');

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.text('Open me'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping an emoji card on Home opens EmojiDetailScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createEmoji(emoji: '😌', label: 'Calm', strength: 4);

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    expect(find.text('Strong · 4 of 5'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping Settings switches to the Settings hub', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pump();

    expect(find.text('YOUR DATA'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping Privacy and backup in Settings opens PrivacyScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pump();
    await tester.tap(find.text('Privacy and backup'));
    await tester.pumpAndSettle();

    expect(find.text('App lock'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets(
    'Settings content clears the floating dock, down to the last row',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LogRepository(db, clock: () => now);

      await pump(tester, repo);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Version'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      final versionBottom = tester.getBottomLeft(find.text('Version')).dy;
      final dockTop = tester
          .getTopLeft(find.byKey(const ValueKey('dock-tab-Settings')))
          .dy;
      expect(versionBottom, lessThan(dockTop));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );

  testWidgets('tapping Trash in Settings opens TrashScreen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(body: 'From settings');
    await repo.softDelete(id);

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pump();
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();

    expect(find.text('From settings'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
