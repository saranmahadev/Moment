import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/home/home_screen.dart';
import 'package:moment/settings/app_settings.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 21, 50);

  // Drift caches stream queries and only tears down their internal Timer
  // after Database.close() is awaited; flutter_test asserts no Timer is
  // left pending when a test ends, so every test below closes its own
  // database as its last step instead of relying on a shared tearDown
  // (which runs too late to satisfy that check).

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo, {
    ValueChanged<Log>? onOpenLog,
    AppSettings? settings,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: HomeScreen(
          repository: repo,
          settings: settings,
          now: () => now,
          onOpenLog: onOpenLog,
        ),
      ),
    );
  }

  testWidgets('shows the weekday and date', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('Friday'), findsOneWidget);
    expect(find.text('6 November 2026'), findsOneWidget);

    await db.close();
  });

  testWidgets('shows an empty state when there are no logs', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('Your day is unwritten.'), findsOneWidget);

    await db.close();
  });

  testWidgets('shows logs from the repository, grouped by day', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'Quiet evening.');
    await repo.createEmoji(emoji: '😌', label: 'Calm', strength: 4);

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('TODAY · FRI 6 NOV'), findsOneWidget);
    expect(find.text('Quiet evening.'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Older logs live in Library.'), findsNothing);

    await db.close();
  });

  testWidgets('tapping a mood emoji logs it and it appears in the feed', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Log mood calm'));
    await tester.pumpAndSettle();

    // One in the mood row itself, one in the new feed card it created.
    expect(find.text('😌'), findsNWidgets(2));

    // A quick tap logs the emoji at full strength.
    final logged = (await tester.runAsync(
      () => repo.watchFeed().first,
    ))!.whereType<EmojiLog>().single;
    expect(logged.strength, 5);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('the mood row shows the five emoji chosen in Settings', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final settings = AppSettings.inMemory({
      'quickEmoji': ['🥰', '😴', '😊', '😢', '🤒'],
    });

    await pump(tester, repo, settings: settings);
    await tester.pump();

    expect(find.bySemanticsLabel('Log mood loved'), findsOneWidget);
    expect(find.bySemanticsLabel('Log mood calm'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Log mood tired'));
    await tester.pumpAndSettle();
    final logged = (await repo.getAll()).single as EmojiLog;
    expect(logged.emoji, '😴');
    expect(logged.label, 'Tired');

    // A change in Settings shows without leaving Home.
    await settings.setQuickEmoji(['😤', '😴', '😊', '😢', '🤒']);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Log mood frustrated'), findsOneWidget);
    expect(find.bySemanticsLabel('Log mood loved'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('filtering to Text hides Emoji cards', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'A text log');
    final emojiId = await repo.createEmoji(emoji: '😌', strength: 3);

    await pump(tester, repo);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('type-chip-Text')));
    await tester.pumpAndSettle();

    expect(find.text('A text log'), findsOneWidget);
    expect(find.byKey(ValueKey('feed-card-$emojiId')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('matches its approved baseline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createEmoji(
      emoji: '😌',
      label: 'Calm',
      strength: 4,
      createdAt: now.subtract(const Duration(minutes: 5)),
    );
    await repo.createText(body: 'Quiet evening.', createdAt: now);

    await pump(tester, repo);
    await tester.pump();

    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_screen.png'),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping a card reports the log', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'Tap me');

    Log? opened;
    await pump(tester, repo, onOpenLog: (log) => opened = log);
    await tester.pump();

    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();
    expect(opened, isA<TextLog>());
    expect((opened! as TextLog).body, 'Tap me');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
