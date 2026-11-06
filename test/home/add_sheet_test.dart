import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/home/add_sheet.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required ValueChanged<LogType> onSelected,
    VoidCallback? onClose,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: Scaffold(
          body: AddSheet(onTypeSelected: onSelected, onClose: onClose ?? () {}),
        ),
      ),
    );
  }

  testWidgets('shows the title and subtitle', (tester) async {
    await pump(tester, onSelected: (_) {});

    expect(find.text('Add to your log'), findsOneWidget);
    expect(find.text('Each type is its own log. Pick one.'), findsOneWidget);
  });

  testWidgets('shows only the types built so far, with their blurb', (
    tester,
  ) async {
    await pump(tester, onSelected: (_) {});

    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Write what is on your mind'), findsOneWidget);
    expect(find.text('Emoji'), findsOneWidget);
    expect(find.text('Log how you feel'), findsOneWidget);
    expect(find.text('Photo'), findsNothing);
    expect(find.text('Video'), findsNothing);
    expect(find.text('Audio'), findsNothing);
    expect(find.text('Location'), findsNothing);
  });

  testWidgets('tapping a type reports it', (tester) async {
    LogType? selected;
    await pump(tester, onSelected: (type) => selected = type);

    await tester.tap(find.text('Emoji'));
    expect(selected, LogType.emoji);
  });

  testWidgets('the close button calls onClose', (tester) async {
    var closed = false;
    await pump(tester, onSelected: (_) {}, onClose: () => closed = true);

    await tester.tap(find.bySemanticsLabel('Close'));
    expect(closed, isTrue);
  });
}
