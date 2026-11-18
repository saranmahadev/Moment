import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/streaks/streak_chip.dart';
import 'package:moment/streaks/streak_model.dart';

void main() {
  final today = DateTime.utc(2026, 11, 6);
  Set<DateTime> run(int from, int to) => {
    for (var i = from; i <= to; i++) DateTime.utc(2026, 11, i),
  };

  Future<void> pump(
    WidgetTester tester,
    StreakSummary summary, {
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: momentTheme(),
      home: Scaffold(
        body: Center(
          child: StreakChip(summary: summary, onTap: onTap),
        ),
      ),
    ),
  );

  testWidgets('shows the count and says it is logged today', (tester) async {
    await pump(tester, streakOf(run(1, 6), today));

    expect(find.text('6'), findsOneWidget);
    expect(find.bySemanticsLabel('6-day streak, logged today'), findsOneWidget);
  });

  testWidgets('says nothing is logged yet when today is open', (tester) async {
    await pump(tester, streakOf(run(1, 5), today));

    expect(
      find.bySemanticsLabel('5-day streak, nothing logged yet today'),
      findsOneWidget,
    );
  });

  testWidgets('says a grace day is in use', (tester) async {
    await pump(tester, streakOf(run(1, 4), today, grace: 1));

    expect(
      find.bySemanticsLabel('4-day streak, grace day in use'),
      findsOneWidget,
    );
    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets('is not there when there is no streak', (tester) async {
    await pump(tester, streakOf({}, today));

    expect(find.byType(StreakChip), findsOneWidget);
    expect(find.byKey(const ValueKey('streak-chip')), findsNothing);
  });

  testWidgets('a tap opens the streaks', (tester) async {
    var taps = 0;
    await pump(tester, streakOf(run(1, 6), today), onTap: () => taps++);

    await tester.tap(find.byKey(const ValueKey('streak-chip')));

    expect(taps, 1);
  });

  testWidgets('is a button at least 44 points tall', (tester) async {
    await pump(tester, streakOf(run(1, 6), today), onTap: () {});

    expect(
      tester.getSize(find.byKey(const ValueKey('streak-chip'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('streak-chip'))),
      matchesSemantics(
        label: '6-day streak, logged today',
        isButton: true,
        hasTapAction: true,
      ),
    );
  });
}
