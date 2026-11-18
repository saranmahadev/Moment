import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/type_icons.dart';
import 'package:moment/domain/log_type.dart';

import '../support/screen_cases.dart';

/// Differences from the mockups found in the Phase 5 fidelity pass.
void main() {
  setUpAll(loadAppFonts);

  ScreenCase screen(String name) =>
      screenCases.singleWhere((screen) => screen.name == name);

  testWidgets('Trash: Back is a round button, not a bar', (tester) async {
    final fixture = await pumpScreenCase(tester, screen('27_trash'));
    final back = tester.getSize(find.bySemanticsLabel('Back').first);
    expect(back.width, lessThanOrEqualTo(48));
    await closeScreenCase(tester, fixture);
  });

  test('sections are named in the plural where the mockups do', () {
    expect(
      {for (final t in LogType.values) t: momentSectionTitleFor(t)},
      {
        LogType.text: 'Text',
        LogType.emoji: 'Emoji',
        LogType.photo: 'Photos',
        LogType.video: 'Videos',
        LogType.audio: 'Audio',
        LogType.location: 'Locations',
      },
    );
  });

  testWidgets('Library: plural names, cards about 150 pt tall', (tester) async {
    final fixture = await pumpScreenCase(tester, screen('04_library'));
    for (final name in ['Photos', 'Videos', 'Locations']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    final card = find.ancestor(
      of: find.text('Photos'),
      matching: find.byType(GestureDetector),
    );
    final height = tester.getSize(card.first).height;
    expect(height, inInclusiveRange(140, 175));
    await closeScreenCase(tester, fixture);
  });

  for (final (name, title) in [
    ('13_photo_section', 'Photos'),
    ('14_video_section', 'Videos'),
    ('16_location_section', 'Locations'),
  ]) {
    testWidgets('$name is titled $title', (tester) async {
      final fixture = await pumpScreenCase(tester, screen(name));
      expect(find.text(title), findsOneWidget);
      await closeScreenCase(tester, fixture);
    });
  }

  testWidgets('Lock says everything stays on this device', (tester) async {
    final fixture = await pumpScreenCase(tester, screen('01_lock'));
    expect(find.text('Everything stays on this device'), findsOneWidget);
    await closeScreenCase(tester, fixture);
  });

  testWidgets('Text detail reads at the mockup size', (tester) async {
    final fixture = await pumpScreenCase(tester, screen('17_text_detail'));
    final body = tester.widget<Text>(
      find
          .byWidgetPredicate(
            (w) =>
                w is Text &&
                w.style?.fontFamily == 'Newsreader' &&
                (w.data ?? '').length > 30,
          )
          .first,
    );
    expect(body.style!.fontSize, 24);
    expect(body.style!.height, 1.4);
    await closeScreenCase(tester, fixture);
  });

  test('the Text icon is a T, as in the mockups', () {
    expect(momentIconFor(LogType.text), Icons.title_rounded);
  });
}
