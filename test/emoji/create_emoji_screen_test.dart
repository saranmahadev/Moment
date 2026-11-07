import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/orb_field.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/design/tokens.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/emoji/create_emoji_screen.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 21, 42);

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo, {
    ValueChanged<String>? onSaved,
    VoidCallback? onClose,
    EmojiLog? editing,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: CreateEmojiScreen(
          repository: repo,
          now: () => now,
          onSaved: onSaved ?? (_) {},
          onClose: onClose ?? () {},
          editing: editing,
        ),
      ),
    );
  }

  testWidgets('matches its approved baseline', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);

    await expectLater(
      find.byType(CreateEmojiScreen),
      matchesGoldenFile('goldens/create_emoji_screen.png'),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('defaults to the first emoji, Happy, strength 3', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);

    expect(find.text('Emoji'), findsOneWidget);
    expect(find.text('Happy'), findsOneWidget);

    final badge = tester.widget<Text>(find.text('Emoji'));
    expect(badge.style?.color, MomentTokens.standard.ink);
    expect(find.byType(OrbField), findsOneWidget);
    expect(find.bySemanticsLabel('Intensity 3 of 5, selected'), findsOneWidget);
    expect(find.text('Log mood'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping an emoji selects it and updates the label', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.tap(find.bySemanticsLabel('Calm'));
    await tester.pump();

    expect(find.text('Calm'), findsOneWidget); // the big label
    expect(find.bySemanticsLabel('Calm, selected'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping a strength selects it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);

    await pump(tester, repo);
    await tester.tap(find.bySemanticsLabel('Intensity 5 of 5'));
    await tester.pump();

    expect(find.bySemanticsLabel('Intensity 5 of 5, selected'), findsOneWidget);
    expect(find.bySemanticsLabel('Intensity 3 of 5, selected'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Log mood creates an emoji log and reports its id', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    String? savedId;

    await pump(tester, repo, onSaved: (id) => savedId = id);
    await tester.tap(find.bySemanticsLabel('Calm'));
    await tester.tap(find.bySemanticsLabel('Intensity 5 of 5'));
    await tester.pump();
    await tester.tap(find.text('Log mood'));
    await tester.pumpAndSettle();

    expect(savedId, isNotNull);
    final log = await repo.getById(savedId!) as EmojiLog;
    expect(log.emoji, '😌');
    expect(log.label, 'Calm');
    expect(log.strength, 5);
    expect(log.createdAt, now);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Close calls onClose without saving anything', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    var closed = false;

    await pump(tester, repo, onClose: () => closed = true);
    await tester.tap(find.bySemanticsLabel('Close without saving'));
    await tester.pump();

    expect(closed, isTrue);
    expect(await db.select(db.logsTable).get(), isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  group('editing an existing log', () {
    testWidgets('prefills the emoji, label and strength', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LogRepository(db, clock: () => now);
      final id = await repo.createEmoji(
        emoji: '😤',
        label: 'Frustrated',
        strength: 2,
      );
      final existing = await repo.getById(id) as EmojiLog;

      await pump(tester, repo, editing: existing);

      expect(find.text('Frustrated'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Intensity 2 of 5, selected'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    });

    testWidgets('Log mood updates the log in place instead of creating one', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LogRepository(db, clock: () => now);
      final id = await repo.createEmoji(
        emoji: '😤',
        label: 'Frustrated',
        strength: 2,
      );
      final existing = await repo.getById(id) as EmojiLog;
      String? savedId;

      await pump(
        tester,
        repo,
        editing: existing,
        onSaved: (savedWith) => savedId = savedWith,
      );
      await tester.tap(find.bySemanticsLabel('Intensity 5 of 5'));
      await tester.pump();
      await tester.tap(find.text('Log mood'));
      await tester.pumpAndSettle();

      expect(savedId, id);
      final updated = await repo.getById(id) as EmojiLog;
      expect(updated.emoji, '😤');
      expect(updated.strength, 5);
      expect(updated.editedAt, now);
      expect(await db.select(db.logsTable).get(), hasLength(1));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    });
  });
}
