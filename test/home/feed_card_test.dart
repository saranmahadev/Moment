import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/design/tokens.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/home/feed_card.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('feed_card_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

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

    testWidgets('the body is set in the ink colour, not the default', (
      tester,
    ) async {
      await pump(tester, FeedCard(log: log));

      final text = tester.widget<Text>(
        find.text('Quiet evening. Finished the book I started in October.'),
      );
      expect(text.style?.color, MomentTokens.standard.ink);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await pump(tester, FeedCard(log: log, onTap: () => tapped = true));

      await tester.tap(find.byType(FeedCard));
      expect(tapped, isTrue);
    });

    testWidgets('shows the full weekday, date and time when asked to', (
      tester,
    ) async {
      await pump(tester, FeedCard(log: log, showFullDate: true));
      expect(find.text('Fri 6 Nov · 20:12'), findsOneWidget);
      expect(find.text('20:12'), findsNothing);
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

    testWidgets('the mood label is set in the ink colour, not the default', (
      tester,
    ) async {
      await pump(tester, FeedCard(log: log));

      final text = tester.widget<Text>(find.text('Calm'));
      expect(text.style?.color, MomentTokens.standard.ink);
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

  group('PhotoLogCard', () {
    testWidgets('shows the type label, time, thumbnail and caption', (
      tester,
    ) async {
      final thumb = File(p.join(tempDir.path, 'a-thumb.jpg'))
        ..writeAsStringSync('fake');
      final log = PhotoLog(
        id: '4',
        createdAt: DateTime.utc(2026, 11, 6, 20, 12),
        tzOffsetMinutes: 0,
        editedAt: null,
        deletedAt: null,
        path: thumb.path,
        thumbnailPath: thumb.path,
        caption: 'By the lake',
      );

      await pump(tester, FeedCard(log: log));

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('20:12'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('By the lake'), findsOneWidget);
    });

    testWidgets('shows no caption text when there is none', (tester) async {
      final thumb = File(p.join(tempDir.path, 'a-thumb.jpg'))
        ..writeAsStringSync('fake');
      final log = PhotoLog(
        id: '5',
        createdAt: DateTime.utc(2026, 11, 6, 20, 12),
        tzOffsetMinutes: 0,
        editedAt: null,
        deletedAt: null,
        path: thumb.path,
        thumbnailPath: thumb.path,
        caption: null,
      );

      await pump(tester, FeedCard(log: log));

      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('AudioLogCard', () {
    final log = AudioLog(
      id: '6',
      createdAt: DateTime.utc(2026, 11, 6, 18, 5),
      tzOffsetMinutes: 0,
      editedAt: null,
      deletedAt: null,
      path: '/media/2026/11/a.m4a',
      duration: const Duration(seconds: 42),
      peaks: [0.2, 0.5, 0.8, 0.3],
      title: 'Voice note',
      note: null,
    );

    testWidgets('shows the type label, time, title and duration', (
      tester,
    ) async {
      await pump(tester, FeedCard(log: log));

      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('18:05'), findsOneWidget);
      expect(find.text('Voice note'), findsOneWidget);
      expect(find.text('0:42'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('falls back to "Audio" when there is no title', (tester) async {
      final untitled = AudioLog(
        id: '7',
        createdAt: DateTime.utc(2026, 11, 6, 18, 5),
        tzOffsetMinutes: 0,
        editedAt: null,
        deletedAt: null,
        path: '/media/2026/11/b.m4a',
        duration: const Duration(seconds: 5),
        peaks: [0.1],
        title: null,
        note: null,
      );

      await pump(tester, FeedCard(log: untitled));

      expect(find.text('Audio'), findsNWidgets(2));
    });
  });
}
