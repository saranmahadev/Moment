import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moment/design/round_glass_button.dart';

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
    final numbered = {
      for (final screen in screenCases)
        if (RegExp(r'^\d\d_').hasMatch(screen.name))
          int.parse(screen.name.substring(0, 2)),
    }.toList();

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

  group('with the real typefaces, on a 390 pt phone', () {
    ScreenCase screen(String name) =>
        screenCases.singleWhere((screen) => screen.name == name);

    testWidgets('Home asks "How are you?" in full', (tester) async {
      final fixture = await pumpScreenCase(tester, screen('02_home'));

      final question = tester.renderObject<RenderParagraph>(
        find.text('How are you?'),
      );
      expect(question.didExceedMaxLines, isFalse);
      expect(
        question.size.width,
        greaterThanOrEqualTo(
          question.getMaxIntrinsicWidth(double.infinity).floor(),
        ),
      );

      await closeScreenCase(tester, fixture);
    });

    testWidgets('Privacy\'s Back button is a round 44 pt button', (
      tester,
    ) async {
      final fixture = await pumpScreenCase(tester, screen('26_privacy'));

      expect(
        tester.getSize(
          find.widgetWithIcon(RoundGlassButton, Icons.chevron_left),
        ),
        const Size(44, 44),
      );

      await closeScreenCase(tester, fixture);
    });

    testWidgets('Search shows results for what it was opened with', (
      tester,
    ) async {
      final fixture = await pumpScreenCase(tester, screen('24_search_results'));

      expect(find.text('TEXT · 2'), findsOneWidget);
      expect(find.text('PHOTO · 1'), findsOneWidget);

      await closeScreenCase(tester, fixture);
    });
  });
}
