import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/home/mood_row.dart';

void main() {
  Future<void> pump(WidgetTester tester, ValueChanged<String> onTapped) {
    return tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: Scaffold(body: MoodRow(onMoodTapped: onTapped)),
      ),
    );
  }

  testWidgets('shows the "How are you?" prompt', (tester) async {
    await pump(tester, (_) {});
    expect(find.text('How are you?'), findsOneWidget);
  });

  testWidgets('shows all five moods with accessible labels', (tester) async {
    await pump(tester, (_) {});

    for (final label in [
      'Log mood happy',
      'Log mood calm',
      'Log mood neutral',
      'Log mood sad',
      'Log mood frustrated',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
  });

  testWidgets('tapping an emoji reports it', (tester) async {
    String? tapped;
    await pump(tester, (emoji) => tapped = emoji);

    await tester.tap(find.bySemanticsLabel('Log mood calm'));
    expect(tapped, '😌');
  });
}
