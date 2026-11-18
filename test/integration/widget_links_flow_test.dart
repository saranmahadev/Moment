import 'package:flutter_test/flutter_test.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/emoji/create_emoji_screen.dart';
import 'package:moment/streaks/streaks_screen.dart';
import 'package:moment/text/create_text_screen.dart';
import 'package:moment/widgets/deep_links.dart';

import 'shell_harness.dart';

/// What a tap on the home screen widget does inside the real app shell.
void main() {
  final now = DateTime.utc(2026, 11, 6, 22);

  testWidgets('an add link opens that log type\'s New screen', (tester) async {
    final inbox = DeepLinkInbox();
    final shell = await ShellHarness.pump(
      tester,
      now: () => now,
      deepLinks: inbox,
    );

    inbox.post(const AddLink(LogType.text));
    await tester.pumpAndSettle();
    expect(find.byType(CreateTextScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close without saving'));
    await tester.pumpAndSettle();
    inbox.post(const AddLink(LogType.emoji));
    await tester.pumpAndSettle();
    expect(find.byType(CreateEmojiScreen), findsOneWidget);

    await shell.close(tester);
  });

  testWidgets('the streaks link opens the Streaks page', (tester) async {
    final inbox = DeepLinkInbox();
    final shell = await ShellHarness.pump(
      tester,
      now: () => now,
      deepLinks: inbox,
    );

    inbox.post(const StreaksLink());
    await tester.pumpAndSettle();

    expect(find.byType(StreaksScreen), findsOneWidget);
    await shell.close(tester);
  });

  testWidgets('a link waiting before the shell is built is opened on its '
      'first frame (the app was locked or not running)', (tester) async {
    final inbox = DeepLinkInbox()..post(const AddLink(LogType.text));
    final shell = await ShellHarness.pump(
      tester,
      now: () => now,
      deepLinks: inbox,
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreateTextScreen), findsOneWidget);
    await shell.close(tester);
  });

  testWidgets('a link while another screen is open goes back to the shell '
      'first, so screens do not pile up', (tester) async {
    final inbox = DeepLinkInbox();
    final shell = await ShellHarness.pump(
      tester,
      now: () => now,
      deepLinks: inbox,
    );
    inbox.post(const StreaksLink());
    await tester.pumpAndSettle();

    inbox.post(const AddLink(LogType.text));
    await tester.pumpAndSettle();

    expect(find.byType(StreaksScreen), findsNothing);
    expect(find.byType(CreateTextScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Close without saving'));
    await tester.pumpAndSettle();
    // One pop returns to the tabs: nothing is left underneath.
    expect(find.bySemanticsLabel('Add a log'), findsOneWidget);
    await shell.close(tester);
  });

  testWidgets('a link is opened once', (tester) async {
    final inbox = DeepLinkInbox();
    final shell = await ShellHarness.pump(
      tester,
      now: () => now,
      deepLinks: inbox,
    );
    inbox.post(const StreaksLink());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(StreaksScreen), findsNothing);
    await shell.close(tester);
  });
}
