import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/home/feed_card.dart';
import 'package:moment/section/emoji_week_strip.dart';
import 'package:moment/section/section_screen.dart';

/// The Emoji section's "This week" strip and the Audio section's rows, as
/// in the mockups.
void main() {
  // Friday 6 November 2026, evening.
  final now = DateTime.utc(2026, 11, 6, 20);

  Future<(AppDatabase, LogRepository)> open() async {
    final db = AppDatabase(NativeDatabase.memory());
    return (db, LogRepository(db, clock: () => now));
  }

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo,
    LogType type, {
    ValueChanged<Log>? onOpenLog,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: SectionScreen(
          type: type,
          repository: repo,
          now: () => now,
          onOpenLog: onOpenLog,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> close(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }

  group('weekOfEmoji', () {
    EmojiLog at(DateTime t, String emoji, [String id = '']) => EmojiLog(
      id: '$id$t',
      createdAt: t,
      tzOffsetMinutes: 0,
      editedAt: null,
      deletedAt: null,
      emoji: emoji,
      label: null,
      strength: 3,
    );

    test('Monday to Sunday, the latest emoji of each day', () {
      final week = weekOfEmoji([
        at(DateTime.utc(2026, 11, 6, 9), '😌'), // newest first
        at(DateTime.utc(2026, 11, 6, 8), '😊'),
        at(DateTime.utc(2026, 11, 4, 9), '😔'),
        at(DateTime.utc(2026, 11, 1, 9), '😴'), // last week's Sunday
      ], today: DateTime.utc(2026, 11, 6));
      expect(week.map((d) => d.day), [
        for (var i = 2; i <= 8; i++) DateTime.utc(2026, 11, i),
      ]);
      expect(week.map((d) => d.emoji), [
        null,
        null,
        '😔',
        null,
        '😌',
        null,
        null,
      ]);
    });

    test('also when the logs come oldest first', () {
      final week = weekOfEmoji([
        at(DateTime.utc(2026, 11, 6, 8), '😊'),
        at(DateTime.utc(2026, 11, 6, 9), '😌'),
      ], today: DateTime.utc(2026, 11, 6));
      expect(week[4].emoji, '😌');
    });
  });

  testWidgets('the Emoji section opens with this week', (tester) async {
    final (db, repo) = await open();
    await repo.createEmoji(emoji: '😌', label: 'Calm', strength: 4);
    await pump(tester, repo, LogType.emoji);

    expect(find.text('THIS WEEK'), findsOneWidget);
    for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(day), findsOneWidget, reason: day);
    }
    expect(
      find.bySemanticsLabel('This week. Friday, today: 😌'),
      findsOneWidget,
    );
    await close(tester, db);
  });

  testWidgets('the other sections have no week strip', (tester) async {
    final (db, repo) = await open();
    await repo.createText(body: 'hello');
    await pump(tester, repo, LogType.text);
    expect(find.text('THIS WEEK'), findsNothing);
    await close(tester, db);
  });

  testWidgets('Audio is a list of rows: title, when, waveform, length', (
    tester,
  ) async {
    final (db, repo) = await open();
    final id = await repo.createAudio(
      path: '/none.m4a',
      duration: const Duration(seconds: 42),
      peaks: const [0.2, 0.9, 0.4, 0.7],
      title: 'Voice note',
    );
    final opened = <Log>[];
    await pump(tester, repo, LogType.audio, onOpenLog: opened.add);

    final row = find.byKey(ValueKey('audio-row-$id'));
    expect(row, findsOneWidget);
    expect(find.byType(FeedCard), findsNothing);
    expect(
      find.descendant(of: row, matching: find.text('Voice note')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Fri 6 Nov · 20:00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('0:42')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Voice note, Fri 6 Nov · 20:00, 0:42'),
      findsOneWidget,
    );

    await tester.tap(row);
    expect(opened.single.id, id);
    await close(tester, db);
  });

  testWidgets('an untitled recording is called Audio', (tester) async {
    final (db, repo) = await open();
    await repo.createAudio(
      path: '/none.m4a',
      duration: const Duration(minutes: 1, seconds: 12),
      peaks: const [0.5],
    );
    await pump(tester, repo, LogType.audio);
    expect(find.text('1:12'), findsOneWidget);
    expect(find.text('Audio'), findsWidgets);
    await close(tester, db);
  });
}
