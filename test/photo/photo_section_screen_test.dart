import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/photo/photo_section_screen.dart';
import 'package:path/path.dart' as p;

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('photo_section_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  File fakeThumb(String name) {
    final file = File(p.join(tempDir.path, name));
    file.writeAsStringSync('fake');
    return file;
  }

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo, {
    VoidCallback? onBack,
    ValueChanged<Log>? onOpenLog,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: PhotoSectionScreen(
          repository: repo,
          onBack: onBack,
          onOpenLog: onOpenLog,
        ),
      ),
    );
  }

  testWidgets('shows the type name and log count', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createPhoto(
      path: fakeThumb('a.jpg').path,
      thumbnailPath: fakeThumb('a-thumb.jpg').path,
    );
    await repo.createPhoto(
      path: fakeThumb('b.jpg').path,
      thumbnailPath: fakeThumb('b-thumb.jpg').path,
    );

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('Photo'), findsWidgets);
    expect(find.text('2 logs'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows one grid tile per photo', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final first = await repo.createPhoto(
      path: fakeThumb('a.jpg').path,
      thumbnailPath: fakeThumb('a-thumb.jpg').path,
    );
    final second = await repo.createPhoto(
      path: fakeThumb('b.jpg').path,
      thumbnailPath: fakeThumb('b-thumb.jpg').path,
    );

    await pump(tester, repo);
    await tester.pump();

    expect(find.byKey(ValueKey('photo-tile-$first')), findsOneWidget);
    expect(find.byKey(ValueKey('photo-tile-$second')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping a tile reports its log', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createPhoto(
      path: fakeThumb('a.jpg').path,
      thumbnailPath: fakeThumb('a-thumb.jpg').path,
    );

    Log? opened;
    await pump(tester, repo, onOpenLog: (log) => opened = log);
    await tester.pump();

    await tester.tap(find.byKey(ValueKey('photo-tile-$id')));

    expect(opened, isA<PhotoLog>());
    expect(opened!.id, id);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('the back button calls onBack', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    var backed = false;

    await pump(tester, repo, onBack: () => backed = true);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back to Library'));

    expect(backed, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
