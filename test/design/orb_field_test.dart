import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/orb_field.dart';

void main() {
  Future<void> pump(WidgetTester tester, double height) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 390,
          height: height,
          child: const OrbField(),
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

  testWidgets('does not intercept touches', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const SizedBox(width: 390, height: 844, child: OrbField()),
            Positioned(
              left: -70,
              top: 90,
              child: GestureDetector(
                onTap: () => tapped = true,
                child: const SizedBox(width: 240, height: 240),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tapAt(const Offset(50, 210));
    expect(tapped, isTrue);
  });
}
