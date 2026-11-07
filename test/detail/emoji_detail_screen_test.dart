import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/detail/emoji_detail_screen.dart';
import 'package:moment/domain/log.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 21, 50);

  Future<void> pump(
    WidgetTester tester,
    LogRepository repo,
    EmojiLog log, {
    VoidCallback? onBack,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: EmojiDetailScreen(
          log: log,
          repository: repo,
          now: () => now,
          onBack: onBack,
        ),
      ),
    );
  }

  testWidgets('shows the emoji, label and intensity', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createEmoji(emoji: '😌', label: 'Calm', strength: 4);
    final log = await repo.getById(id) as EmojiLog;

    await pump(tester, repo, log);

    expect(find.text('😌'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Strong · 4 of 5'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('the back button calls onBack', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createEmoji(emoji: '😌', strength: 3);
    final log = await repo.getById(id) as EmojiLog;
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
    final id = await repo.createEmoji(emoji: '😌', strength: 3);
    final log = await repo.getById(id) as EmojiLog;
    var backed = false;

    await pump(tester, repo, log, onBack: () => backed = true);
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pump();

    expect(backed, isTrue);
    final deleted = await repo.getById(id) as EmojiLog;
    expect(deleted.deletedAt, isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Change emoji opens CreateEmojiScreen prefilled', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db, clock: () => now);
    final id = await repo.createEmoji(emoji: '😌', label: 'Calm', strength: 3);
    final log = await repo.getById(id) as EmojiLog;
    var backed = false;

    await pump(tester, repo, log, onBack: () => backed = true);
    await tester.tap(find.text('Change emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Frustrated'));
    await tester.pump();
    await tester.tap(find.text('Log mood'));
    await tester.pumpAndSettle();

    expect(backed, isTrue);
    final updated = await repo.getById(id) as EmojiLog;
    expect(updated.emoji, '😤');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
