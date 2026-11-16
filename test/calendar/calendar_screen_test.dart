import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/calendar/calendar_screen.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/home/type_filter_chips.dart';

void main() {
  // Friday 6 November 2026, as in the mockup.
  final now = DateTime.utc(2026, 11, 6, 22);
  late AppDatabase db;
  late LogRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
  });

  Future<void> pump(WidgetTester tester, {ValueChanged<Log>? onOpenLog}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: Scaffold(
          body: CalendarScreen(
            repository: repo,
            now: () => now,
            onOpenLog: onOpenLog,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }

  Finder day(int year, int month, int d) => find.byKey(
    ValueKey(
      'calendar-day-$year-${month.toString().padLeft(2, '0')}-'
      '${d.toString().padLeft(2, '0')}',
    ),
  );

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pump();
  }

  testWidgets('opens on this month with today selected', (tester) async {
    await pump(tester);

    expect(find.text('November 2026'), findsOneWidget);
    for (final letter in ['M', 'W', 'F']) {
      expect(find.text(letter), findsWidgets);
    }
    expect(day(2026, 11, 6), findsOneWidget);
    expect(day(2026, 10, 26), findsOneWidget);
    expect(day(2026, 12, 6), findsOneWidget);
    expect(
      tester.getSemantics(day(2026, 11, 6)).label,
      'Friday 6 November, today, no logs, selected',
    );
    expect(find.text('FRIDAY 6 NOVEMBER · 0 LOGS'), findsOneWidget);
    expect(find.text('Nothing logged on this day.'), findsOneWidget);

    await close(tester);
  });

  testWidgets('a day shows one dot per type logged on it', (tester) async {
    await repo.createText(body: 'One', createdAt: DateTime.utc(2026, 11, 4, 9));
    await repo.createText(
      body: 'Two',
      createdAt: DateTime.utc(2026, 11, 4, 10),
    );
    await repo.createEmoji(
      emoji: '😌',
      strength: 3,
      createdAt: DateTime.utc(2026, 11, 4, 11),
    );
    await pump(tester);

    expect(
      find.byKey(const ValueKey('calendar-dot-2026-11-04-text')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-dot-2026-11-04-emoji')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-dot-2026-11-04-photo')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('calendar-dot-2026-11-05-text')),
      findsNothing,
    );
    expect(
      tester.getSemantics(day(2026, 11, 4)).label,
      'Wednesday 4 November, 3 logs',
    );

    await close(tester);
  });

  testWidgets('tapping a day lists its logs, newest first, and opens one', (
    tester,
  ) async {
    await repo.createText(
      body: 'Quiet evening.',
      createdAt: DateTime.utc(2026, 11, 4, 20, 12),
    );
    await repo.createEmoji(
      emoji: '😌',
      label: 'Calm',
      strength: 4,
      createdAt: DateTime.utc(2026, 11, 4, 21, 40),
    );
    Log? opened;
    await pump(tester, onOpenLog: (log) => opened = log);

    await tester.tap(day(2026, 11, 4));
    await tester.pump();

    expect(find.text('WEDNESDAY 4 NOVEMBER · 2 LOGS'), findsOneWidget);
    await show(tester, find.text('Quiet evening.'));
    expect(find.text('Emoji · 21:40'), findsOneWidget);
    expect(find.text('Calm · strength 4 of 5'), findsOneWidget);
    expect(find.text('Text · 20:12'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Emoji · 21:40')).dy,
      lessThan(tester.getTopLeft(find.text('Text · 20:12')).dy),
    );

    await tester.tap(find.text('Quiet evening.'));
    expect(opened, isA<TextLog>());

    await close(tester);
  });

  testWidgets('one log reads "1 LOG"', (tester) async {
    await repo.createText(
      body: 'Only',
      createdAt: DateTime.utc(2026, 11, 6, 9),
    );
    await pump(tester);

    expect(find.text('FRIDAY 6 NOVEMBER · 1 LOG'), findsOneWidget);

    await close(tester);
  });

  testWidgets('the arrows move a month at a time, across a year end', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pump();
    expect(find.text('December 2026'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pump();
    expect(find.text('January 2027'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pump();
    }
    expect(find.text('October 2026'), findsOneWidget);

    await close(tester);
  });

  testWidgets('Today jumps back to this month and selects today', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Today'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.pump();
    await tester.tap(day(2026, 10, 14));
    await tester.pump();
    expect(find.text('WEDNESDAY 14 OCTOBER · 0 LOGS'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pump();

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('FRIDAY 6 NOVEMBER · 0 LOGS'), findsOneWidget);
    expect(find.text('Today'), findsNothing);

    await close(tester);
  });

  testWidgets('tapping a greyed day of a neighbouring month goes there', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(day(2026, 12, 2));
    await tester.pump();

    expect(find.text('December 2026'), findsOneWidget);
    expect(find.text('WEDNESDAY 2 DECEMBER · 0 LOGS'), findsOneWidget);

    await close(tester);
  });

  testWidgets('a type filter narrows the dots and the day list', (
    tester,
  ) async {
    await repo.createText(
      body: 'Words',
      createdAt: DateTime.utc(2026, 11, 6, 9),
    );
    await repo.createEmoji(
      emoji: '😌',
      label: 'Calm',
      strength: 4,
      createdAt: DateTime.utc(2026, 11, 6, 10),
    );
    await pump(tester);
    expect(find.text('FRIDAY 6 NOVEMBER · 2 LOGS'), findsOneWidget);

    final emojiChip = find.descendant(
      of: find.byType(TypeFilterChips),
      matching: find.text('Emoji'),
    );
    await show(tester, emojiChip);
    await tester.tap(emojiChip);
    await tester.pump();

    expect(find.text('FRIDAY 6 NOVEMBER · 1 LOG'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-dot-2026-11-06-text')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('calendar-dot-2026-11-06-emoji')),
      findsOneWidget,
    );
    await show(tester, find.text('Calm · strength 4 of 5'));
    expect(find.text('Words'), findsNothing);

    await close(tester);
  });

  testWidgets('logs in Trash are not on the calendar', (tester) async {
    final id = await repo.createText(
      body: 'Gone',
      createdAt: DateTime.utc(2026, 11, 6, 9),
    );
    await repo.softDelete(id);
    await pump(tester);

    expect(find.text('FRIDAY 6 NOVEMBER · 0 LOGS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-dot-2026-11-06-text')),
      findsNothing,
    );

    await close(tester);
  });

  testWidgets('a new log appears without reopening the screen', (tester) async {
    await pump(tester);
    expect(find.text('FRIDAY 6 NOVEMBER · 0 LOGS'), findsOneWidget);

    await repo.createText(
      body: 'Late',
      createdAt: DateTime.utc(2026, 11, 6, 21),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('FRIDAY 6 NOVEMBER · 1 LOG'), findsOneWidget);

    await close(tester);
  });

  testWidgets('the legend names all six types', (tester) async {
    await pump(tester);

    for (final name in [
      'Text',
      'Emoji',
      'Photo',
      'Video',
      'Audio',
      'Location',
    ]) {
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-legend')),
          matching: find.text(name),
        ),
        findsOneWidget,
        reason: name,
      );
    }

    await close(tester);
  });
}
