import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/library/library_screen.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 21, 50);

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo, {
    ValueChanged<LogType>? onOpenType,
    VoidCallback? onOpenTrash,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: LibraryScreen(
          repository: repo,
          now: () => now,
          onOpenType: onOpenType,
          onOpenTrash: onOpenTrash,
        ),
      ),
    );
  }

  testWidgets('shows the title and subtitle', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('Library'), findsOneWidget);
    expect(
      find.text('Everything you have logged, one section per type.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows a tile per built type with its count and last date', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'one');
    await repo.createText(body: 'two');
    await repo.createEmoji(emoji: '😌', strength: 3);

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('Text'), findsOneWidget);
    expect(find.text('2 logs · Last: Today'), findsOneWidget);
    expect(find.text('Emoji'), findsOneWidget);
    expect(find.text('1 log · Last: Today'), findsOneWidget);
    expect(find.text('Photo'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows the last log\'s date when it is not today', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(
      body: 'yesterday',
      createdAt: now.subtract(const Duration(days: 1)),
    );

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('1 log · Last: 5 Nov'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping a type tile reports it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'one');
    LogType? opened;

    await pump(tester, repo, onOpenType: (type) => opened = type);
    await tester.pump();
    await tester.tap(find.text('Text'));

    expect(opened, LogType.text);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows the Trash row with its count', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(body: 'gone');
    await repo.softDelete(id);

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('1 log'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping Trash calls onOpenTrash', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    var opened = false;

    await pump(tester, repo, onOpenTrash: () => opened = true);
    await tester.pump();
    await tester.tap(find.text('Trash'));

    expect(opened, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
