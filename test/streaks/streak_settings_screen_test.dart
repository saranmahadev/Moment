import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/streaks/streak_settings_screen.dart';

void main() {
  Future<AppSettings> pump(
    WidgetTester tester, {
    Map<String, Object?>? values,
    VoidCallback? onBack,
  }) async {
    final settings = AppSettings.inMemory(values);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: StreakSettingsScreen(settings: settings, onBack: onBack ?? () {}),
      ),
    );
    await tester.pump();
    return settings;
  }

  testWidgets('shows the title, the switch and the grace choices', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Streaks'), findsOneWidget);
    expect(find.text('Show streaks'), findsOneWidget);
    expect(find.text('Missed days forgiven each week'), findsOneWidget);
    for (final n in [0, 1, 2, 3]) {
      expect(find.byKey(ValueKey('grace-$n')), findsOneWidget);
    }
  });

  testWidgets('the switch turns streaks off and on', (tester) async {
    final settings = await pump(tester);
    final toggle = find.byKey(const ValueKey('streaks-show-switch'));
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(settings.showStreaks, isFalse);
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pump();
    expect(settings.showStreaks, isTrue);
  });

  testWidgets('choosing grace days saves them and marks the choice', (
    tester,
  ) async {
    final settings = await pump(tester);
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('grace-1'))),
      matchesSemantics(
        label: '1 grace day a week',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('grace-3')));
    await tester.pump();

    expect(settings.graceDays, 3);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('grace-3'))).label,
      '3 grace days a week',
    );
    handle.dispose();
  });

  testWidgets('the explanation follows the choice', (tester) async {
    await pump(tester, values: {'graceDays': 0});
    expect(
      find.text('With no grace days, one missed day ends the streak.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('grace-1')));
    await tester.pump();
    expect(
      find.text(
        'A streak survives 1 missed day in any 7 days. Forgiven days show as '
        'dashed squares and count in the total.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('grace-2')));
    await tester.pump();
    expect(find.textContaining('survives 2 missed days'), findsOneWidget);
  });

  testWidgets('a preview shows how a missed day is treated', (tester) async {
    await pump(tester, values: {'graceDays': 0});
    final broken = find.byKey(const ValueKey('grace-preview'));
    expect(broken, findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Preview')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('grace-2')));
    await tester.pump();
    expect(broken, findsOneWidget);
  });

  testWidgets('says how a day is counted and that the reminder is quiet', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('How a day is counted'), findsOneWidget);
    expect(find.textContaining('midnight to midnight'), findsOneWidget);
    expect(find.textContaining('never mentions streaks'), findsOneWidget);
    expect(find.textContaining('Nothing is stored or sent'), findsOneWidget);
  });

  testWidgets('Back calls onBack', (tester) async {
    var back = 0;
    await pump(tester, onBack: () => back++);

    await tester.tap(find.bySemanticsLabel('Back'));

    expect(back, 1);
  });
}
