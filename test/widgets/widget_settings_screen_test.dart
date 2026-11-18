import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/widgets/widget_settings_screen.dart';

import '../support/fake_widget_bridge.dart';

void main() {
  late FakeWidgetBridge bridge;

  Future<AppSettings> pump(
    WidgetTester tester, {
    Map<String, Object?>? values,
    VoidCallback? onBack,
  }) async {
    bridge = FakeWidgetBridge();
    final settings = AppSettings.inMemory(values);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: WidgetSettingsScreen(
          settings: settings,
          bridge: bridge,
          onBack: onBack ?? () {},
        ),
      ),
    );
    await tester.pump();
    return settings;
  }

  testWidgets('shows the two choices, with the streak chosen by default', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Widgets'), findsOneWidget);
    expect(find.text('Streak and Quick add'), findsOneWidget);
    expect(find.text('Quick add only'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('widget-option-streak'))),
      matchesSemantics(
        label: 'Streak and Quick add',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        isEnabled: null,
      ),
    );
  });

  testWidgets('choosing Quick add only turns the streak off for the widget', (
    tester,
  ) async {
    final settings = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('widget-option-quick')));
    await tester.pump();
    expect(settings.widgetShowsStreak, isFalse);

    await tester.tap(find.byKey(const ValueKey('widget-option-streak')));
    await tester.pump();
    expect(settings.widgetShowsStreak, isTrue);
  });

  testWidgets('says what the widget shows and that it stays visible when '
      'locked', (tester) async {
    await pump(tester);

    expect(
      find.textContaining('stays visible while Moment is locked'),
      findsOneWidget,
    );
    expect(find.textContaining('PIN or Face ID'), findsOneWidget);
    expect(find.textContaining('No words, photos or places'), findsOneWidget);
  });

  testWidgets('the add button asks the launcher to pin the widget', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('widget-add')));
    await tester.pump();

    expect(bridge.pinRequests, 1);
    expect(find.textContaining('Touch and hold the home screen'), findsNothing);
  });

  testWidgets('when the launcher will not, it explains how to add it', (
    tester,
  ) async {
    await pump(tester);
    bridge.pinAnswer = false;

    await tester.tap(find.byKey(const ValueKey('widget-add')));
    await tester.pump();

    expect(
      find.textContaining('Touch and hold the home screen'),
      findsOneWidget,
    );
  });

  testWidgets('the back button goes back', (tester) async {
    var back = 0;
    await pump(tester, onBack: () => back++);

    await tester.tap(find.bySemanticsLabel('Back'));

    expect(back, 1);
  });
}
