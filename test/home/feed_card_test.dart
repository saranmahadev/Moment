import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/home/feed_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: Scaffold(body: child),
      ),
    );
  }

  group('TextLogCard', () {
    final log = TextLog(
      id: '1',
      createdAt: DateTime.utc(2026, 11, 6, 20, 12),
      tzOffsetMinutes: 0,
      editedAt: null,
      deletedAt: null,
      body: 'Quiet evening. Finished the book I started in October.',
    );

    testWidgets('shows the type label, time, body and word count', (
      tester,
    ) async {
      await pump(tester, FeedCard(log: log));

      expect(find.text('Text'), findsOneWidget);
      expect(find.text('20:12'), findsOneWidget);
      expect(
        find.text('Quiet evening. Finished the book I started in October.'),
        findsOneWidget,
      );
      expect(find.text('9 words'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await pump(tester, FeedCard(log: log, onTap: () => tapped = true));

      await tester.tap(find.byType(FeedCard));
      expect(tapped, isTrue);
    });
  });

  group('EmojiLogCard', () {
    final log = EmojiLog(
      id: '2',
      createdAt: DateTime.utc(2026, 11, 6, 21, 40),
      tzOffsetMinutes: 0,
      editedAt: null,
      deletedAt: null,
      emoji: '😌',
      label: 'Calm',
      strength: 4,
    );

    testWidgets('shows the type label, time, emoji and mood label', (
      tester,
    ) async {
      await pump(tester, FeedCard(log: log));

      expect(find.text('Emoji'), findsOneWidget);
      expect(find.text('21:40'), findsOneWidget);
      expect(find.text('😌'), findsOneWidget);
      expect(find.text('Calm'), findsOneWidget);
    });

    testWidgets('shows the strength as "Intensity n of 5"', (tester) async {
      await pump(tester, FeedCard(log: log));
      expect(find.bySemanticsLabel('Intensity 4 of 5'), findsOneWidget);
    });

    testWidgets('falls back to the emoji alone when there is no label', (
      tester,
    ) async {
      final unlabelled = EmojiLog(
        id: '3',
        createdAt: DateTime.utc(2026, 11, 6, 21, 40),
        tzOffsetMinutes: 0,
        editedAt: null,
        deletedAt: null,
        emoji: '😊',
        label: null,
        strength: 3,
      );
      await pump(tester, FeedCard(log: unlabelled));
      expect(find.text('😊'), findsOneWidget);
    });
  });
}
