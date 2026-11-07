import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/settings/settings_screen.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    LogRepository repo, {
    VoidCallback? onOpenPrivacy,
    VoidCallback? onOpenTrash,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: SettingsScreen(
          repository: repo,
          onOpenPrivacy: onOpenPrivacy ?? () {},
          onOpenTrash: onOpenTrash ?? () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the title and every section label', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db);

    await pump(tester, repo);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('YOUR DATA'), findsOneWidget);
    expect(find.text('LOGGING'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('tapping Privacy and backup calls onOpenPrivacy', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db);
    var opened = false;

    await pump(tester, repo, onOpenPrivacy: () => opened = true);
    await tester.tap(find.text('Privacy and backup'));

    expect(opened, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Trash shows the current trash count and calls onOpenTrash', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db);
    final id = await repo.createText(body: 'Gone');
    await repo.softDelete(id);
    var opened = false;

    await pump(tester, repo, onOpenTrash: () => opened = true);
    await tester.pump();

    expect(find.text('1 log'), findsOneWidget);

    await tester.tap(find.text('Trash'));
    expect(opened, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows the inert Logging, Appearance and About rows', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LogRepository(db);

    await pump(tester, repo);

    expect(find.text('Quick emoji row'), findsOneWidget);
    expect(find.text('Evening reminder'), findsOneWidget);
    expect(find.text('Video and photo quality'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Reduce transparency'), findsOneWidget);
    expect(find.text('How Moment stays local'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
