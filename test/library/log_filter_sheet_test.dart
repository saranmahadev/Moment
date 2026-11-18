import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/library/log_filter.dart';
import 'package:moment/library/log_filter_sheet.dart';

void main() {
  LogFilter? applied;

  Future<void> pump(
    WidgetTester tester,
    LogType type, {
    LogFilter initial = const LogFilter(),
  }) async {
    applied = null;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: Scaffold(
          body: LogFilterSheet(
            type: type,
            initial: initial,
            onApply: (f) => applied = f,
          ),
        ),
      ),
    );
  }

  testWidgets('always offers when and order', (tester) async {
    await pump(tester, LogType.text);

    for (final label in [
      'All time',
      'Today',
      'Last 7 days',
      'Last 30 days',
      'This year',
      'Newest first',
      'Oldest first',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('Text has nothing extra to choose', (tester) async {
    await pump(tester, LogType.text);
    expect(find.text('Strength'), findsNothing);
    expect(find.textContaining('Only with'), findsNothing);
  });

  testWidgets('Emoji offers strengths 1 to 5', (tester) async {
    await pump(tester, LogType.emoji);
    expect(find.text('Strength'), findsOneWidget);
    for (var i = 1; i <= 5; i++) {
      expect(find.bySemanticsLabel('Strength $i'), findsOneWidget);
    }
  });

  testWidgets('each type names what it can be filtered by', (tester) async {
    for (final entry in {
      LogType.photo: 'Only with a caption',
      LogType.video: 'Only with a caption',
      LogType.audio: 'Only with a title',
      LogType.location: 'Only with a name',
    }.entries) {
      await pump(tester, entry.key);
      expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
    }
  });

  testWidgets('Apply hands back exactly what was chosen', (tester) async {
    await pump(tester, LogType.emoji);

    await tester.tap(find.text('Last 7 days'));
    await tester.tap(find.text('Oldest first'));
    await tester.tap(find.bySemanticsLabel('Strength 5'));
    await tester.tap(find.bySemanticsLabel('Strength 4'));
    await tester.pump();
    await tester.tap(find.text('Apply'));

    expect(
      applied,
      const LogFilter(
        window: FilterWindow.last7,
        oldestFirst: true,
        strengths: {4, 5},
      ),
    );
  });

  testWidgets('it opens showing the filter already in force', (tester) async {
    await pump(
      tester,
      LogType.photo,
      initial: const LogFilter(window: FilterWindow.today, onlyNamed: true),
    );
    await tester.tap(find.text('Apply'));

    expect(
      applied,
      const LogFilter(window: FilterWindow.today, onlyNamed: true),
    );
  });

  testWidgets('tapping a chosen strength again takes it off', (tester) async {
    await pump(tester, LogType.emoji, initial: const LogFilter(strengths: {5}));
    await tester.tap(find.bySemanticsLabel('Strength 5'));
    await tester.pump();
    await tester.tap(find.text('Apply'));

    expect(applied, const LogFilter());
  });

  testWidgets('Reset clears every choice and applies at once', (tester) async {
    await pump(
      tester,
      LogType.photo,
      initial: const LogFilter(window: FilterWindow.today, oldestFirst: true),
    );
    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(applied, const LogFilter());
  });

  testWidgets('every choice is a labelled button of at least 44 pt', (
    tester,
  ) async {
    await pump(tester, LogType.emoji);

    for (final label in ['Today', 'Oldest first', 'Apply', 'Reset']) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
    for (var i = 1; i <= 5; i++) {
      final size = tester.getSize(find.bySemanticsLabel('Strength $i'));
      expect(size.shortestSide, greaterThanOrEqualTo(44));
    }
  });
}
