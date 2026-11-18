import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/diagnostics/diagnostics_log.dart';
import 'package:moment/diagnostics/diagnostics_screen.dart';

void main() {
  late DiagnosticsLog log;
  late List<String> shared;
  var now = DateTime.utc(2026, 11, 18, 9);

  setUp(() {
    now = DateTime.utc(2026, 11, 18, 9);
    log = DiagnosticsLog(MemoryDiagnosticsStore(), clock: () => now);
    shared = [];
  });

  Future<void> pump(WidgetTester tester, {String? intro}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: DiagnosticsScreen(
          log: log,
          intro: intro,
          share: (text) async => shared.add(text),
          onBack: () {},
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('says when nothing has been recorded', (tester) async {
    await pump(tester);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Nothing has been recorded.'), findsOneWidget);
    expect(find.textContaining('never what you wrote'), findsOneWidget);
  });

  testWidgets('lists entries, newest first', (tester) async {
    await tester.runAsync(() async {
      await log.event('launch', '1.0.0');
      now = now.add(const Duration(minutes: 5));
      await log.event('backup.made');
    });
    await pump(tester);
    final launch = tester.getTopLeft(find.text('launch'));
    final backup = tester.getTopLeft(find.text('backup.made'));
    expect(backup.dy, lessThan(launch.dy));
  });

  testWidgets('Share hands over the report; you choose where it goes', (
    tester,
  ) async {
    await tester.runAsync(() => log.event('launch', '1.0.0'));
    await pump(tester);
    await tester.tap(find.text('Share'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(shared.single, contains('event  launch  1.0.0'));
  });

  testWidgets('Copy puts the report on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.runAsync(() => log.event('launch', '1.0.0'));
    await pump(tester);
    await tester.tap(find.text('Copy'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(copied, contains('launch'));
  });

  testWidgets('Clear asks first, then empties it', (tester) async {
    await tester.runAsync(() => log.event('launch'));
    await pump(tester);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear diagnostics'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Nothing has been recorded.'), findsOneWidget);
    expect(await tester.runAsync(log.entries), isEmpty);
  });

  testWidgets('can open with an explanation, as when launch failed', (
    tester,
  ) async {
    await pump(tester, intro: 'Moment couldn’t start.');
    expect(find.text('Moment couldn’t start.'), findsOneWidget);
  });
}
