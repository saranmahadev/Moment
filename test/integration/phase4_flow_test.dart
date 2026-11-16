import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/calendar/calendar_screen.dart';
import 'package:moment/search/search_screen.dart';

import 'shell_harness.dart';

/// Phase 4 through the real app shell: the Calendar tab, Search from Home
/// and the Settings that change how the app looks.
void main() {
  // Friday 6 November 2026.
  final now = DateTime.utc(2026, 11, 6, 22);

  testWidgets('calendar: a log shows on its day and opens from there', (
    tester,
  ) async {
    final shell = await ShellHarness.pump(tester, now: () => now);
    await shell.repo.createText(
      body: 'Finished the book',
      createdAt: DateTime.utc(2026, 11, 4, 20, 12),
    );

    await tester.tap(find.bySemanticsLabel('Calendar'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-dot-2026-11-04-text')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-11-04')));
    await tester.pumpAndSettle();
    final row = find.text('Finished the book');
    await tester.scrollUntilVisible(
      row,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    // The text detail screen, with its own controls.
    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    expect(find.text('Finished the book'), findsOneWidget);

    await shell.close(tester);
  });

  testWidgets('search: from Home, find a log and open it', (tester) async {
    final shell = await ShellHarness.pump(tester, now: () => now);
    await shell.repo.createText(
      body: 'Morning light on the balcony',
      createdAt: DateTime.utc(2026, 11, 6, 8, 40),
    );
    await shell.repo.createText(
      body: 'Something else entirely',
      createdAt: DateTime.utc(2026, 11, 6, 9),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'balc');
    await tester.pumpAndSettle();
    expect(find.text('TEXT · 1'), findsOneWidget);

    await tester.tap(find.text('Fri 6 Nov · 08:40'));
    await tester.pumpAndSettle();

    // The detail screen, over the search.
    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    expect(find.text('Morning light on the balcony'), findsOneWidget);

    await shell.close(tester);
  });
}
