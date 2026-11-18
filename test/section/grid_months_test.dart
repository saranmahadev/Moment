import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/library/log_filter.dart';
import 'package:moment/photo/photo_section_screen.dart';
import 'package:moment/section/month_groups.dart';
import 'package:moment/video/video_section_screen.dart';

/// Month headings in the photo and video grids, as in the mockups. (The
/// mockups' "Newest first" pill was replaced by the order in each Library
/// card's filter.)
void main() {
  final now = DateTime.utc(2026, 11, 7, 10);

  group('groupByMonth', () {
    TextLog at(DateTime t, [int offset = 0]) => TextLog(
      id: '$t',
      createdAt: t,
      tzOffsetMinutes: offset,
      editedAt: null,
      deletedAt: null,
      body: 'x',
    );

    test('keeps the order it is given, one group per month', () {
      final groups = groupByMonth([
        at(DateTime.utc(2026, 11, 6)),
        at(DateTime.utc(2026, 11, 1)),
        at(DateTime.utc(2026, 10, 30)),
        at(DateTime.utc(2025, 10, 2)),
      ]);
      expect(groups.map((g) => (g.label, g.logs.length)), [
        ('NOVEMBER 2026', 2),
        ('OCTOBER 2026', 1),
        ('OCTOBER 2025', 1),
      ]);
    });

    test('a month is the one the log was made in, in its own zone', () {
      // 23:30 on 31 October at +05:30 is 18:00 UTC: October.
      final groups = groupByMonth([at(DateTime.utc(2026, 10, 31, 18), 330)]);
      expect(groups.single.label, 'OCTOBER 2026');
      // 00:30 on 1 November at +05:30 is still 31 October in UTC.
      final next = groupByMonth([at(DateTime.utc(2026, 10, 31, 19), 330)]);
      expect(next.single.label, 'NOVEMBER 2026');
    });
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(theme: momentTheme(), home: screen));
    await tester.pump();
  }

  for (final type in [LogType.photo, LogType.video]) {
    testWidgets('the ${type.name} grid is headed by month', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      var t = now;
      final repo = LogRepository(db, clock: () => t);
      for (final day in [
        DateTime.utc(2026, 11, 6),
        DateTime.utc(2026, 10, 30),
      ]) {
        t = day;
        if (type == LogType.photo) {
          await repo.createPhoto(path: '/none.jpg', thumbnailPath: '/none.jpg');
        } else {
          await repo.createVideo(
            path: '/none.mp4',
            posterPath: '/none.jpg',
            duration: const Duration(seconds: 3),
          );
        }
      }
      await pumpScreen(
        tester,
        type == LogType.photo
            ? PhotoSectionScreen(repository: repo, now: () => now)
            : VideoSectionScreen(repository: repo, now: () => now),
      );
      final november = tester.getTopLeft(find.text('NOVEMBER 2026'));
      final october = tester.getTopLeft(find.text('OCTOBER 2026'));
      expect(october.dy, greaterThan(november.dy));

      // Oldest first: October comes first.
      await tester.pumpWidget(
        MaterialApp(
          theme: momentTheme(),
          home: type == LogType.photo
              ? PhotoSectionScreen(
                  repository: repo,
                  now: () => now,
                  filter: const LogFilter(oldestFirst: true),
                )
              : VideoSectionScreen(
                  repository: repo,
                  now: () => now,
                  filter: const LogFilter(oldestFirst: true),
                ),
        ),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('OCTOBER 2026')).dy,
        lessThan(tester.getTopLeft(find.text('NOVEMBER 2026')).dy),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    });
  }
}
