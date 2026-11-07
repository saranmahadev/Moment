import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/shell/app_shell.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 21, 50);

  Future<void> pump(WidgetTester tester, LogRepository repo) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    return tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: AppShell(repository: repo, now: () => now),
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
    expect(
      find.text('Everything you have logged, one section per type.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping a type tile in Library opens its SectionScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'In the section');

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pump();
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();

    expect(find.text('In the section'), findsOneWidget);
    expect(find.text('1 log'), findsOneWidget);

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

  testWidgets('picking Emoji from the Add sheet opens CreateEmojiScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Add a log'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('add-sheet-type-LogType.emoji')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add to your log'), findsNothing);
    expect(find.text('Log mood'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets(
    'saving a new mood from the Add flow returns to Home with it visible',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LogRepository(db, clock: () => now);

      await pump(tester, repo);
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Add a log'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('add-sheet-type-LogType.emoji')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log mood'));
      await tester.pumpAndSettle();

      expect(find.text('Happy'), findsOneWidget);
      expect(find.text('Log mood'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );

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

  testWidgets('tapping a text card on Home opens TextDetailScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'Open me');

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.text('Open me'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping an emoji card on Home opens EmojiDetailScreen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createEmoji(emoji: '😌', label: 'Calm', strength: 4);

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    expect(find.text('Strong · 4 of 5'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
