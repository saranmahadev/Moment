import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/home/home_screen.dart';

void main() {
  late AppDatabase db;
  late LogRepository repo;
  final now = DateTime.utc(2026, 11, 6, 21, 50);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pump(WidgetTester tester, {ValueChanged<Log>? onOpenLog}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: HomeScreen(
          repository: repo,
          now: () => now,
          onOpenLog: onOpenLog,
        ),
      ),
    );
  }

  testWidgets('shows the weekday and date', (tester) async {
    await pump(tester);
    await tester.pump();

    expect(find.text('Friday'), findsOneWidget);
    expect(find.text('6 November 2026'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no logs', (tester) async {
    await pump(tester);
    await tester.pump();

    expect(find.text('Your day is unwritten.'), findsOneWidget);
  });

  testWidgets('shows logs from the repository, grouped by day', (
    tester,
  ) async {
    await repo.createText(body: 'Quiet evening.');
    await repo.createEmoji(emoji: '😌', label: 'Calm', strength: 4);

    await pump(tester);
    await tester.pump();

    expect(find.text('TODAY · FRI 6 NOV'), findsOneWidget);
    expect(find.text('Quiet evening.'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
  });

  testWidgets('tapping a mood emoji logs it and it appears in the feed', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Log mood calm'));
    await tester.pump();
    await tester.pump();

    expect(find.text('😌'), findsOneWidget);
  });

  testWidgets('filtering to Text hides Emoji cards', (tester) async {
    await repo.createText(body: 'A text log');
    await repo.createEmoji(emoji: '😌', strength: 3);

    await pump(tester);
    await tester.pump();

    await tester.tap(find.text('Text'));
    await tester.pump();

    expect(find.text('A text log'), findsOneWidget);
    expect(find.text('😌'), findsNothing);
  });

  testWidgets('tapping a card reports the log', (tester) async {
    await repo.createText(body: 'Tap me');
    Log? opened;
    await pump(tester, onOpenLog: (log) => opened = log);
    await tester.pump();

    await tester.tap(find.text('Tap me'));
    expect(opened, isA<TextLog>());
    expect((opened! as TextLog).body, 'Tap me');
  });
}
