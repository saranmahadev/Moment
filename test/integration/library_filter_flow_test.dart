import 'package:flutter_test/flutter_test.dart';
import 'package:moment/section/section_screen.dart';

import 'shell_harness.dart';

/// The Library's filter, through the real app shell: choose it on a card,
/// see only what matches on that type's page, clear it from there.
void main() {
  // Friday 6 November 2026.
  final now = DateTime.utc(2026, 11, 6, 22);

  testWidgets('filter Emoji by strength from its Library card', (tester) async {
    final shell = await ShellHarness.pump(tester, now: () => now);
    await shell.repo.createEmoji(
      emoji: '😌',
      label: 'Calm',
      strength: 5,
      createdAt: DateTime.utc(2026, 11, 6, 9),
    );
    await shell.repo.createEmoji(
      emoji: '😐',
      label: 'Meh',
      strength: 2,
      createdAt: DateTime.utc(2026, 11, 5, 9),
    );

    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Filter Emoji')));
    await tester.pumpAndSettle();

    expect(find.text('Filter Emoji'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Strength 5'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    // The card says one choice is in force.
    expect(find.bySemanticsLabel('Filter Emoji, 1 active'), findsOneWidget);

    await tester.tap(find.text('Emoji').first);
    await tester.pumpAndSettle();

    expect(find.byType(SectionScreen), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Meh'), findsNothing);
    expect(find.text('Showing 1 of 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Clear filter'));
    await tester.pumpAndSettle();

    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Meh'), findsOneWidget);
    expect(find.textContaining('Showing'), findsNothing);

    await shell.close(tester);
  });

  testWidgets('the filter is remembered per type while the app is open', (
    tester,
  ) async {
    final shell = await ShellHarness.pump(tester, now: () => now);
    await shell.repo.createText(body: 'a note');

    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Filter Text')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Filter Text, 1 active'), findsOneWidget);
    // Another type is not affected.
    expect(find.bySemanticsLabel('Filter Emoji'), findsOneWidget);

    // Away to Home and back: still in force.
    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Filter Text, 1 active'), findsOneWidget);

    await shell.close(tester);
  });

  testWidgets('Reset in the popup clears the card\'s filter', (tester) async {
    final shell = await ShellHarness.pump(tester, now: () => now);

    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Filter Text')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Filter Text, 1 active'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Filter Text, 1 active'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Filter Text'), findsOneWidget);

    await shell.close(tester);
  });
}
