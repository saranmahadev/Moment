import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/trash/trash_screen.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 21, 50);

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo, {
    VoidCallback? onBack,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: TrashScreen(repository: repo, now: () => now, onBack: onBack),
      ),
    );
  }

  testWidgets('shows the title and the explanatory banner', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('Trash'), findsOneWidget);
    expect(
      find.text(
        'Deleted logs stay here for 30 days, then are removed for '
        'good along with their files.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('matches its approved baseline', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(
      body: 'Rain all day.',
      createdAt: now.subtract(const Duration(days: 10)),
    );
    await repo.softDelete(id);

    await pump(tester, repo);
    await tester.pump();

    await expectLater(
      find.byType(TrashScreen),
      matchesGoldenFile('goldens/trash_screen.png'),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('lists trashed logs with their preview and days since deletion', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(
      body: 'Rain all day.',
      createdAt: now.subtract(const Duration(days: 10)),
    );
    await repo.softDelete(id);

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('Rain all day.'), findsOneWidget);
    expect(find.text('Deleted today'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('does not show logs that are not deleted', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    await repo.createText(body: 'Still around');

    await pump(tester, repo);
    await tester.pump();

    expect(find.text('Still around'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Restore brings a log back', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(body: 'Bring me back');
    await repo.softDelete(id);

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Bring me back'), findsNothing);
    final restored = await repo.getById(id);
    expect(restored!.deletedAt, isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Empty Trash asks for confirmation before deleting everything', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createText(body: 'Gone for good');
    await repo.softDelete(id);

    await pump(tester, repo);
    await tester.pump();
    await tester.tap(find.text('Empty Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(await repo.getById(id), isNotNull);

    await tester.tap(find.text('Empty Trash').last);
    await tester.pumpAndSettle();

    expect(await repo.getById(id), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('the back button calls onBack', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    var backed = false;

    await pump(tester, repo, onBack: () => backed = true);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back'));

    expect(backed, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
