import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/design/tokens.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/section/section_screen.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 21, 50);

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo,
    LogType type, {
    VoidCallback? onBack,
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
          onBack: onBack,
          onOpenLog: onOpenLog,
        ),
      ),
    );
  }

  testWidgets('shows the type name and log count', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'one');
    await repo.createText(body: 'two');

    await pump(tester, repo, LogType.text);
    await tester.pump();

    expect(find.text('Text'), findsWidgets);
    expect(find.text('2 logs'), findsOneWidget);

    final sortLabel = tester.widget<Text>(find.text('Newest first'));
    expect(sortLabel.style?.color, MomentTokens.standard.ink);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows "1 log" in the singular', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'one');

    await pump(tester, repo, LogType.text);
    await tester.pump();

    expect(find.text('1 log'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('lists only logs of the requested type, newest first', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(
      body: 'older',
      createdAt: now.subtract(const Duration(hours: 1)),
    );
    await repo.createText(body: 'newer');
    await repo.createEmoji(emoji: '😌', strength: 3);

    await pump(tester, repo, LogType.text);
    await tester.pump();

    expect(find.text('newer'), findsOneWidget);
    expect(find.text('older'), findsOneWidget);
    expect(find.text('😌'), findsNothing);

    final newerCenter = tester.getCenter(find.text('newer'));
    final olderCenter = tester.getCenter(find.text('older'));
    expect(newerCenter.dy, lessThan(olderCenter.dy));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('excludes soft-deleted logs', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(body: 'gone');
    await repo.softDelete(id);

    await pump(tester, repo, LogType.text);
    await tester.pump();

    expect(find.text('gone'), findsNothing);
    expect(find.text('0 logs'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping a card reports the log', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'Tap me');
    Log? opened;

    await pump(tester, repo, LogType.text, onOpenLog: (log) => opened = log);
    await tester.pump();
    await tester.tap(find.text('Tap me'));

    expect(opened, isA<TextLog>());

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('the back button calls onBack', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    var backed = false;

    await pump(tester, repo, LogType.text, onBack: () => backed = true);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back to Library'));

    expect(backed, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
