import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/location/map/map_window.dart';
import 'package:moment/location/place_map.dart';

import 'fake_map_source.dart';

void main() {
  Future<FakeMapSource> pump(
    WidgetTester tester, {
    bool zoomable = true,
    MapZoom zoom = MapZoom.area,
    Offset pinAt = const Offset(0.5, 0.5),
    ThemeData? theme,
  }) async {
    final source = FakeMapSource();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? momentTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              height: 260,
              child: PlaceMap(
                source: source,
                latitude: 12.91227,
                longitude: 77.7165,
                zoom: zoom,
                zoomable: zoomable,
                pinAt: pinAt,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return source;
  }

  testWidgets('asks the source for the area around the pin', (tester) async {
    final source = await pump(tester);

    expect(source.asked, isNotEmpty);
    expect(source.asked.last.latitude, 12.91227);
    expect(source.asked.last.longitude, 77.7165);
    expect(source.asked.last.zoom, MapZoom.area);
    expect(source.asked.last.aspect, closeTo(340 / 260, 1e-6));
  });

  testWidgets('says how wide the picture is', (tester) async {
    await pump(tester);
    expect(find.textContaining('km across'), findsOneWidget);
  });

  testWidgets('has no blur: only the dock and sheets blur', (tester) async {
    await pump(tester);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('three zoom steps, Area chosen, each a labelled button', (
    tester,
  ) async {
    await pump(tester);
    for (final label in ['Region', 'Area', 'City']) {
      expect(find.bySemanticsLabel('Zoom to $label'), findsOneWidget);
    }
    final size = tester.getSize(find.bySemanticsLabel('Zoom to City'));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('choosing City redraws the map closer and updates the span', (
    tester,
  ) async {
    final source = await pump(tester);
    final before = tester.widget<Text>(find.textContaining('km across')).data;

    await tester.tap(find.bySemanticsLabel('Zoom to City'));
    await tester.pump();
    await tester.pump();

    expect(source.asked.last.zoom, MapZoom.city);
    final after = tester.widget<Text>(find.textContaining('km across')).data;
    expect(after, isNot(before));
  });

  testWidgets('a fixed map has no zoom buttons', (tester) async {
    await pump(tester, zoomable: false);
    expect(find.bySemanticsLabel('Zoom to City'), findsNothing);
  });

  testWidgets('describes the map for screen readers, not the drawing', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.bySemanticsLabel(RegExp(r'Map of the area around 12\.912, 77\.717')),
      findsOneWidget,
    );
  });

  testWidgets('draws in the dark theme too', (tester) async {
    await pump(tester, theme: momentTheme(brightness: Brightness.dark));
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
