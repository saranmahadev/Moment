import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/text/create_text_screen.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 21, 42);

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo, {
    ValueChanged<String>? onSaved,
    VoidCallback? onClose,
    TextLog? editing,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: CreateTextScreen(
          repository: repo,
          now: () => now,
          onSaved: onSaved ?? (_) {},
          onClose: onClose ?? () {},
          editing: editing,
        ),
      ),
    );
  }

  testWidgets('shows the Text badge, the backdated time and a Save button', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);

    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Fri 6 Nov · 21:42'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('matches its approved baseline', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);

    await expectLater(
      find.byType(CreateTextScreen),
      matchesGoldenFile('goldens/create_text_screen.png'),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows a live word count as the user types', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    expect(find.text('0 words'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Quiet evening tonight');
    await tester.pump();
    expect(find.text('3 words'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Save creates a text log and reports its id', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    String? savedId;

    await pump(tester, repo, onSaved: (id) => savedId = id);
    await tester.enterText(find.byType(TextField), 'Walking home.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedId, isNotNull);
    final log = await repo.getById(savedId!) as TextLog;
    expect(log.body, 'Walking home.');
    expect(log.createdAt, now);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Save does nothing while the body is blank', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    var saved = false;

    await pump(tester, repo, onSaved: (_) => saved = true);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Close calls onClose without saving anything', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    var closed = false;

    await pump(tester, repo, onClose: () => closed = true);
    await tester.enterText(find.byType(TextField), 'Abandoned draft');
    await tester.tap(find.bySemanticsLabel('Close without saving'));
    await tester.pump();

    expect(closed, isTrue);
    expect(await db.select(db.logsTable).get(), isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  group('editing an existing log', () {
    testWidgets('prefills the body and the original time', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LogRepository(db, clock: () => now);
      final id = await repo.createText(
        body: 'Original entry',
        createdAt: DateTime.utc(2026, 11, 5, 9, 15),
      );
      final existing = await repo.getById(id) as TextLog;

      await pump(tester, repo, editing: existing);

      expect(find.text('Original entry'), findsOneWidget);
      expect(find.text('Thu 5 Nov · 09:15'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    });

    testWidgets('Save updates the log in place instead of creating one', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LogRepository(db, clock: () => now);
      final id = await repo.createText(body: 'Original entry');
      final existing = await repo.getById(id) as TextLog;
      String? savedId;

      await pump(
        tester,
        repo,
        editing: existing,
        onSaved: (savedWith) => savedId = savedWith,
      );
      await tester.enterText(find.byType(TextField), 'Edited entry');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedId, id);
      final updated = await repo.getById(id) as TextLog;
      expect(updated.body, 'Edited entry');
      expect(updated.editedAt, now);
      expect(await db.select(db.logsTable).get(), hasLength(1));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    });
  });
}
