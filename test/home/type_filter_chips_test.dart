import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/home/type_filter_chips.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required LogType? selected,
    required ValueChanged<LogType?> onSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: Scaffold(
          body: TypeFilterChips(
            availableTypes: const [LogType.text, LogType.emoji],
            selected: selected,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('shows All plus one chip per available type, in order', (
    tester,
  ) async {
    await pump(tester, selected: null, onSelected: (_) {});

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Emoji'), findsOneWidget);
    expect(find.text('Photo'), findsNothing);
  });

  testWidgets('tapping a chip reports its type', (tester) async {
    LogType? reported = LogType.text;
    await pump(
      tester,
      selected: null,
      onSelected: (type) => reported = type,
    );

    await tester.tap(find.text('Emoji'));
    expect(reported, LogType.emoji);
  });

  testWidgets('tapping All reports null', (tester) async {
    LogType? reported = LogType.text;
    await pump(
      tester,
      selected: LogType.text,
      onSelected: (type) => reported = type,
    );

    await tester.tap(find.text('All'));
    expect(reported, isNull);
  });

  testWidgets('marks the selected chip for assistive technology', (
    tester,
  ) async {
    await pump(tester, selected: LogType.emoji, onSelected: (_) {});

    final emojiChip = tester.widget<Semantics>(
      find
          .ancestor(of: find.text('Emoji'), matching: find.byType(Semantics))
          .first,
    );
    expect(emojiChip.properties.selected, isTrue);

    final allChip = tester.widget<Semantics>(
      find.ancestor(of: find.text('All'), matching: find.byType(Semantics)).first,
    );
    expect(allChip.properties.selected, isFalse);
  });
}
