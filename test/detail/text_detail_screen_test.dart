import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/detail/text_detail_screen.dart';
import 'package:moment/domain/log.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 21, 50);

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo,
    TextLog log, {
    VoidCallback? onBack,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: TextDetailScreen(
          log: log,
          repository: repo,
          now: () => now,
          onBack: onBack,
        ),
      ),
    );
  }

  testWidgets('shows the full date, time and body', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(
      body: 'Quiet evening.',
      createdAt: DateTime.utc(2026, 11, 6, 20, 12),
    );
    final log = await repo.getById(id) as TextLog;

    await pump(tester, repo, log);

    expect(find.text('Friday 6 November · 20:12'), findsOneWidget);
    expect(find.text('Quiet evening.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('the back button calls onBack', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(body: 'hi');
    final log = await repo.getById(id) as TextLog;
    var backed = false;

    await pump(tester, repo, log, onBack: () => backed = true);
    await tester.tap(find.bySemanticsLabel('Back'));

    expect(backed, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('delete soft-deletes the log and goes back', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(body: 'gone soon');
    final log = await repo.getById(id) as TextLog;
    var backed = false;

    await pump(tester, repo, log, onBack: () => backed = true);
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pump();

    expect(backed, isTrue);
    final deleted = await repo.getById(id) as TextLog;
    expect(deleted.deletedAt, isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('edit opens CreateTextScreen prefilled, saving goes back', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(body: 'Original');
    final log = await repo.getById(id) as TextLog;
    var backed = false;

    await pump(tester, repo, log, onBack: () => backed = true);
    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Original'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Edited');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(backed, isTrue);
    final updated = await repo.getById(id) as TextLog;
    expect(updated.body, 'Edited');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
