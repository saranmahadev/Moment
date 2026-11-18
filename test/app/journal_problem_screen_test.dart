import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/app/journal_problem_screen.dart';
import 'package:moment/backup/backup_exceptions.dart';
import 'package:moment/data/journal_opener.dart';
import 'package:moment/design/theme.dart';

void main() {
  late int freshCalls;
  late List<(String, String)> restores;
  late File? picked;
  late Object? restoreError;

  setUp(() {
    freshCalls = 0;
    restores = [];
    picked = File('/backups/library.moment');
    restoreError = null;
  });

  Future<void> pump(WidgetTester tester, JournalProblem problem) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: JournalProblemScreen(
          problem: problem,
          pickBackup: () async => picked,
          restore: (file, passphrase) async {
            restores.add((file.path, passphrase));
            if (restoreError case final e?) throw e;
          },
          startFresh: () async => freshCalls++,
        ),
      ),
    );
  }

  testWidgets('says plainly what happened when the key is missing', (
    tester,
  ) async {
    await pump(tester, JournalProblem.keyMissing);
    expect(find.text('This journal can’t be opened'), findsOneWidget);
    expect(
      find.textContaining('key that unlocks it is missing'),
      findsOneWidget,
    );
    expect(find.text('Restore from a backup'), findsOneWidget);
    expect(find.text('Start an empty journal'), findsOneWidget);
  });

  testWidgets('and when the key does not match', (tester) async {
    await pump(tester, JournalProblem.unreadable);
    expect(find.textContaining('doesn’t open it'), findsOneWidget);
  });

  testWidgets('starting empty needs a second confirmation', (tester) async {
    await pump(tester, JournalProblem.keyMissing);
    await tester.tap(find.text('Start an empty journal'));
    await tester.pumpAndSettle();
    expect(freshCalls, 0);
    expect(find.text('Start an empty journal?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(freshCalls, 0);

    await tester.tap(find.text('Start an empty journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start empty'));
    await tester.pumpAndSettle();
    expect(freshCalls, 1);
  });

  testWidgets('restoring picks a file, asks its passphrase, restores', (
    tester,
  ) async {
    await pump(tester, JournalProblem.keyMissing);
    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'correct horse');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(restores, [('/backups/library.moment', 'correct horse')]);
  });

  testWidgets('a cancelled pick asks nothing more', (tester) async {
    picked = null;
    await pump(tester, JournalProblem.keyMissing);
    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(restores, isEmpty);
  });

  testWidgets('a wrong passphrase is said, and you can try again', (
    tester,
  ) async {
    restoreError = const WrongPassphraseException();
    await pump(tester, JournalProblem.keyMissing);
    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'wrong');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.textContaining('passphrase'), findsWidgets);
    expect(find.text('Restore from a backup'), findsOneWidget);
  });
}
