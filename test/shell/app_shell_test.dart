import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/shell/app_shell.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 21, 50);

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo, {
    ValueChanged<LogType>? onAddType,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    return tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: AppShell(repository: repo, now: () => now, onAddType: onAddType),
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
    expect(find.text('Library'), findsWidgets);

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

  testWidgets('picking a type not built yet falls back to onAddType', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    LogType? picked;

    await pump(tester, repo, onAddType: (type) => picked = type);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Add a log'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('add-sheet-type-LogType.emoji')),
    );
    await tester.pumpAndSettle();

    expect(picked, LogType.emoji);
    expect(find.text('Add to your log'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

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
}
