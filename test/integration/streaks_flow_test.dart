import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/streaks/streak_settings_screen.dart';
import 'package:moment/streaks/streaks_screen.dart';

import 'shell_harness.dart';

/// Streaks through the real app shell: the chip on Home, the card on
/// Calendar, the page they open and the settings behind it.
void main() {
  // Friday 6 November 2026.
  final now = DateTime.utc(2026, 11, 6, 22);

  Future<void> logDays(ShellHarness shell, Iterable<int> days) async {
    for (final day in days) {
      await shell.repo.createText(
        body: 'Day $day',
        createdAt: DateTime.utc(2026, 11, day, 12),
      );
    }
  }

  testWidgets('the chip opens the page, the gear opens its settings', (
    tester,
  ) async {
    final shell = await ShellHarness.pump(tester, now: () => now);
    await logDays(shell, [4, 5, 6]);
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('3-day streak, logged today'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('streak-chip')));
    await tester.pumpAndSettle();
    expect(find.byType(StreaksScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Streak settings'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakSettingsScreen), findsOneWidget);

    await shell.close(tester);
  });

  testWidgets('the Calendar card opens the same page', (tester) async {
    final shell = await ShellHarness.pump(tester, now: () => now);
    await logDays(shell, [5, 6]);

    await tester.tap(find.bySemanticsLabel('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('streak-card')));
    await tester.pumpAndSettle();

    expect(find.byType(StreaksScreen), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    await shell.close(tester);
  });

  testWidgets('turning streaks off hides the chip and the card', (
    tester,
  ) async {
    final shell = await ShellHarness.pump(tester, now: () => now);
    await logDays(shell, [5, 6]);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('streak-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Streak settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('streaks-show-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('streak-chip')), findsNothing);
    await tester.tap(find.bySemanticsLabel('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('streak-card')), findsNothing);

    await shell.close(tester);
  });

  testWidgets('logging today lifts the chip from outline to solid', (
    tester,
  ) async {
    final shell = await ShellHarness.pump(tester, now: () => now);
    await logDays(shell, [4, 5]);
    await tester.pump();
    await tester.pump();
    expect(
      find.bySemanticsLabel('2-day streak, nothing logged yet today'),
      findsOneWidget,
    );

    await logDays(shell, [6]);
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('3-day streak, logged today'), findsOneWidget);
    await shell.close(tester);
  });
}
