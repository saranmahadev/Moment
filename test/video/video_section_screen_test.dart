import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/video/video_section_screen.dart';
import 'package:path/path.dart' as p;

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);
  late Directory tempDir;
  late AppDatabase db;
  late LogRepository repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('video_section_test_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<String> video(String name, Duration duration, DateTime at) {
    return repo.createVideo(
      path: p.join(tempDir.path, '$name.mp4'),
      posterPath: (File(
        p.join(tempDir.path, '$name.jpg'),
      )..writeAsStringSync('fake')).path,
      duration: duration,
      createdAt: at,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onBack,
    ValueChanged<Log>? onOpenLog,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: VideoSectionScreen(
          repository: repo,
          onBack: onBack,
          onOpenLog: onOpenLog,
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

  testWidgets('shows the type name and log count', (tester) async {
    await video('a', const Duration(seconds: 48), DateTime.utc(2026, 11, 6));
    await video('b', const Duration(seconds: 21), DateTime.utc(2026, 11, 5));

    await pump(tester);

    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('2 logs'), findsOneWidget);

    await close(tester);
  });

  testWidgets('each tile shows its duration and the day it was made', (
    tester,
  ) async {
    final first = await video(
      'a',
      const Duration(seconds: 48),
      DateTime.utc(2026, 11, 6, 12, 20),
    );
    final second = await video(
      'b',
      const Duration(minutes: 1, seconds: 5),
      DateTime.utc(2026, 11, 3, 9),
    );

    await pump(tester);

    expect(find.byKey(ValueKey('video-tile-$first')), findsOneWidget);
    expect(find.byKey(ValueKey('video-tile-$second')), findsOneWidget);
    expect(find.text('0:48'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    expect(find.text('Fri 6 Nov'), findsOneWidget);
    expect(find.text('Tue 3 Nov'), findsOneWidget);

    await close(tester);
  });

  testWidgets('tapping a tile reports the log', (tester) async {
    final id = await video('a', const Duration(seconds: 48), now);
    Log? opened;

    await pump(tester, onOpenLog: (log) => opened = log);
    await tester.tap(find.byKey(ValueKey('video-tile-$id')));

    expect(opened, isA<VideoLog>());
    expect(opened!.id, id);

    await close(tester);
  });

  testWidgets('trashed videos are not shown', (tester) async {
    final id = await video('a', const Duration(seconds: 48), now);
    await repo.softDelete(id);

    await pump(tester);

    expect(find.byKey(ValueKey('video-tile-$id')), findsNothing);
    expect(find.text('0 logs'), findsOneWidget);

    await close(tester);
  });

  testWidgets('the back button calls onBack', (tester) async {
    var backed = false;
    await pump(tester, onBack: () => backed = true);

    await tester.tap(find.byKey(const ValueKey('video-section-back')));

    expect(backed, isTrue);

    await close(tester);
  });
}
