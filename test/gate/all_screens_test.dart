import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen_cases.dart';

/// docs/ROADMAP.md, Phase 4: checks that hold on every screen of the app,
/// not screen by screen. The list of screens is in
/// test/support/screen_cases.dart; a new screen joins all of these by
/// being added there.
void main() {
  // Real typefaces: large-text checks measure real words, and the goldens
  // show what a phone shows.
  setUpAll(loadAppFonts);

  test('all 27 screens of the mockups are covered', () {
    final numbered = [
      for (final screen in screenCases)
        if (RegExp(r'^\d\d_').hasMatch(screen.name))
          int.parse(screen.name.substring(0, 2)),
    ];

    expect(numbered, [for (var i = 1; i <= 27; i++) i]);
  });

  group('Reduce Transparency swaps blur for solid surfaces', () {
    for (final screen in screenCases) {
      for (final brightness in Brightness.values) {
        testWidgets('${screen.name}, ${brightness.name}', (tester) async {
          final fixture = await pumpScreenCase(
            tester,
            screen,
            brightness: brightness,
            reduceTransparency: true,
          );

          expect(find.byType(BackdropFilter), findsNothing);

          await closeScreenCase(tester, fixture);
        });
      }
    }
  });

  group('accessibility', () {
    for (final screen in screenCases) {
      testWidgets('${screen.name}: every control has a label', (tester) async {
        final handle = tester.ensureSemantics();
        final fixture = await pumpScreenCase(tester, screen);

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        await closeScreenCase(tester, fixture);
        handle.dispose();
      });

      testWidgets('${screen.name}: tap targets are at least 44 by 44', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final fixture = await pumpScreenCase(tester, screen);

        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        await closeScreenCase(tester, fixture);
        handle.dispose();
      });

      testWidgets('${screen.name}: text still fits at the largest size', (
        tester,
      ) async {
        // 200% is the largest font size Android offers; a layout that
        // overflows throws, which fails the test.
        final fixture = await pumpScreenCase(tester, screen, textScale: 2);

        expect(tester.takeException(), isNull);

        await closeScreenCase(tester, fixture);
      });
    }
  });

  group('goldens, light and dark', () {
    for (final screen in screenCases) {
      for (final brightness in Brightness.values) {
        testWidgets('${screen.name}, ${brightness.name}', (tester) async {
          final fixture = await pumpScreenCase(
            tester,
            screen,
            brightness: brightness,
          );

          await expectLater(
            find.byKey(screenBoundaryKey),
            matchesGoldenFile('goldens/${screen.name}_${brightness.name}.png'),
          );

          await closeScreenCase(tester, fixture);
        });
      }
    }
  });
}
