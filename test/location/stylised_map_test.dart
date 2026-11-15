import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/location/stylised_map.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget map) => tester.pumpWidget(
    MaterialApp(
      theme: momentTheme(),
      home: Scaffold(
        body: Center(child: SizedBox(width: 300, height: 200, child: map)),
      ),
    ),
  );

  testWidgets('draws one pin per place', (tester) async {
    await pump(
      tester,
      const StylisedMap(
        pins: [Offset(0.5, 0.5), Offset(0.25, 0.75), Offset(0.8, 0.3)],
      ),
    );

    expect(find.byIcon(Icons.location_on_outlined), findsNWidgets(3));
  });

  testWidgets('a map with no pins is just the tile', (tester) async {
    await pump(tester, const StylisedMap(pins: []));

    expect(find.byType(StylisedMap), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
  });

  testWidgets('a pin sits where its fraction puts it', (tester) async {
    await pump(tester, const StylisedMap(pins: [Offset(0.25, 0.75)]));

    final map = tester.getRect(find.byType(StylisedMap));
    final pin = tester.getRect(find.byIcon(Icons.location_on_outlined));
    // The pin's tip (bottom centre) marks the spot.
    expect(pin.bottomCenter.dx, closeTo(map.left + 0.25 * map.width, 1));
    expect(pin.bottomCenter.dy, closeTo(map.top + 0.75 * map.height, 1));
  });

  testWidgets('can show the accuracy halo around a single pin', (tester) async {
    await pump(
      tester,
      const StylisedMap(pins: [Offset(0.5, 0.5)], showHalo: true),
    );

    expect(find.byKey(const ValueKey('map-halo')), findsOneWidget);
  });
}
