import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/orb_field.dart';

void main() {
  Future<void> pump(WidgetTester tester, double height) async {
    // Align loosens the constraints it gives its child, so the SizedBox
    // below gets to be exactly the size asked for instead of being
    // stretched to fill the whole test surface.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 390, height: height, child: const OrbField()),
        ),
      ),
    );
  }

  testWidgets('places one orb for a short screen', (tester) async {
    await pump(tester, 200);
    expect(find.byType(Container), findsOneWidget);
  });

  testWidgets('places two orbs 380 logical pixels apart on a phone-height '
      'screen, as design/generators/lib.py\'s shell() does', (tester) async {
    await pump(tester, 844);

    final positioned = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .toList();
    expect(positioned, hasLength(2));
    expect(positioned[0].top, 90);
    expect(positioned[1].top, 470);
  });

  testWidgets('alternates left and right sides', (tester) async {
    await pump(tester, 844);

    final positioned = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .toList();
    expect(positioned[0].left, -70);
    expect(positioned[0].right, isNull);
    expect(positioned[1].right, -60);
    expect(positioned[1].left, isNull);
  });

  testWidgets('does not intercept touches: it is wrapped in IgnorePointer', (
    tester,
  ) async {
    await pump(tester, 844);
    expect(find.byType(IgnorePointer), findsOneWidget);
  });

  testWidgets('is drawn once and kept, with no offscreen layer per orb', (
    tester,
  ) async {
    await pump(tester, 844);

    // An Opacity widget paints its child into a separate layer every
    // frame; the orbs carry their transparency in their colours instead.
    expect(find.byType(Opacity), findsNothing);
    // Its own layer, so scrolling over it does not repaint it.
    expect(
      find.descendant(
        of: find.byType(OrbField),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    final gradient =
        (tester.widget<Container>(find.byType(Container).first).decoration!
                as BoxDecoration)
            .gradient!;
    expect(gradient.colors.every((color) => color.a < 1), isTrue);
  });
}
