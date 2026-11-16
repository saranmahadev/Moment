import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/settings/quick_emoji_screen.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AppSettings settings, {
    VoidCallback? onBack,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: momentTheme(),
        home: QuickEmojiScreen(settings: settings, onBack: onBack ?? () {}),
      ),
    );
  }

  Finder slot(int index) => find.byKey(ValueKey('quick-slot-$index'));
  Finder choice(String emoji) => find.byKey(ValueKey('quick-choice-$emoji'));

  testWidgets('shows the five current emoji, the first slot selected', (
    tester,
  ) async {
    await pump(tester, AppSettings.inMemory());

    expect(find.text('Quick emoji row'), findsOneWidget);
    expect(
      find.text('Tap a slot, then the emoji to put there.'),
      findsOneWidget,
    );
    for (var i = 0; i < 5; i++) {
      expect(slot(i), findsOneWidget);
    }
    expect(tester.getSemantics(slot(0)).label, 'Slot 1, Happy, selected');
    expect(tester.getSemantics(slot(1)).label, 'Slot 2, Calm');
  });

  testWidgets('choosing an emoji puts it in the selected slot at once', (
    tester,
  ) async {
    final settings = AppSettings.inMemory();
    await pump(tester, settings);

    await tester.tap(slot(2));
    await tester.pump();
    await tester.tap(choice('🥰'));
    await tester.pumpAndSettle();

    expect(settings.quickEmoji, ['😊', '😌', '🥰', '😔', '😤']);
    expect(tester.getSemantics(slot(2)).label, 'Slot 3, Loved, selected');
  });

  testWidgets('choosing one already in the row swaps the two', (tester) async {
    final settings = AppSettings.inMemory();
    await pump(tester, settings);

    // Slot 1 is selected; 😤 sits in slot 5.
    await tester.tap(choice('😤'));
    await tester.pumpAndSettle();

    expect(settings.quickEmoji, ['😤', '😌', '😐', '😔', '😊']);
  });

  testWidgets('Reset puts the original five back', (tester) async {
    final settings = AppSettings.inMemory({
      'quickEmoji': ['🥰', '😴', '😊', '😢', '🤒'],
    });
    await pump(tester, settings);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(settings.quickEmoji, ['😊', '😌', '😐', '😔', '😤']);
  });

  testWidgets('Back calls onBack', (tester) async {
    var back = false;
    await pump(tester, AppSettings.inMemory(), onBack: () => back = true);

    await tester.tap(find.bySemanticsLabel('Back'));

    expect(back, isTrue);
  });
}
