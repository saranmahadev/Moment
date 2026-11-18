import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/location/map/map_source.dart';
import 'package:moment/location/map/map_window.dart';
import 'package:moment/location/place_map.dart';

import '../support/screen_cases.dart';

/// The proof of concept the owner approved: 12.91227 N, 77.71650 E (the
/// Whitefield side of Bengaluru) at each zoom, drawn from the real bundled
/// Natural Earth tiles, in light and dark.
void main() {
  setUpAll(loadAppFonts);

  for (final brightness in Brightness.values) {
    for (final zoom in MapZoom.values) {
      testWidgets('Bengaluru, ${zoom.label}, ${brightness.name}', (
        tester,
      ) async {
        final source = AssetMapSource();
        await tester.runAsync(() async {
          await source.load(
            MapWindow(
              latitude: 12.91227,
              longitude: 77.7165,
              zoom: zoom,
              aspect: 340 / 260,
            ),
          );
        });
        await tester.binding.setSurfaceSize(const Size(380, 300));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momentTheme(brightness: brightness),
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
                    zoomable: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        await tester.pump();

        await expectLater(
          find.byType(PlaceMap),
          matchesGoldenFile(
            'goldens/place_map_${zoom.name}_${brightness.name}.png',
          ),
        );
      });
    }
  }
}
