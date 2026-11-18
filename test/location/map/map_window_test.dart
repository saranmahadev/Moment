import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/location/map/map_window.dart';

void main() {
  // The pin in the proof of concept: the Whitefield side of Bengaluru.
  const lat = 12.91227;
  const lon = 77.71650;

  MapWindow window(MapZoom zoom, {Offset pinAt = const Offset(0.5, 0.5)}) =>
      MapWindow(
        latitude: lat,
        longitude: lon,
        zoom: zoom,
        aspect: 340 / 260,
        pinAt: pinAt,
      );

  group('MapWindow', () {
    test('puts the pin where it was asked to be', () {
      const size = Size(340, 260);
      final centred = window(MapZoom.area).project(lon, lat, size);
      expect(centred.dx, closeTo(170, 1e-6));
      expect(centred.dy, closeTo(130, 1e-6));

      final low = window(
        MapZoom.area,
        pinAt: const Offset(0.5, 0.36),
      ).project(lon, lat, size);
      expect(low.dy, closeTo(260 * 0.36, 1e-6));
    });

    test('north is up and east is right', () {
      const size = Size(340, 260);
      final w = window(MapZoom.area);
      expect(w.project(lon, lat + 0.1, size).dy, lessThan(130));
      expect(w.project(lon + 0.1, lat, size).dx, greaterThan(170));
    });

    test('a degree of longitude is drawn shorter by the cosine of latitude', () {
      const size = Size(340, 260);
      final w = window(MapZoom.area);
      final east = w.project(lon + 0.1, lat, size).dx - 170;
      final north = 130 - w.project(lon, lat + 0.1, size).dy;
      expect(east / north, closeTo(math.cos(lat * math.pi / 180), 1e-3));
    });

    test('each zoom shows about the span the proof of concept did', () {
      expect(window(MapZoom.region).kmAcross, inInclusiveRange(440, 480));
      expect(window(MapZoom.area).kmAcross, inInclusiveRange(165, 180));
      expect(window(MapZoom.city).kmAcross, inInclusiveRange(60, 66));
    });

    test('the City zoom stays at about 50 km or more across the short side', () {
      expect(MapZoom.city.halfLatitude * 2 * 111, greaterThan(45));
    });

    test('names the tiles it needs: one for Bengaluru at every zoom', () {
      for (final zoom in MapZoom.values) {
        expect(window(zoom).tileKeys(), {'10_70'});
      }
    });

    test('near a tile edge it needs the neighbours too', () {
      final w = MapWindow(
        latitude: 9.9,
        longitude: 79.9,
        zoom: MapZoom.area,
        aspect: 1.3,
      );
      expect(w.tileKeys(), {'0_70', '0_80', '10_70', '10_80'});
    });

    test('tile keys floor to ten degrees, also south and west of zero', () {
      expect(tileKeyFor(12.9, 77.7), '10_70');
      expect(tileKeyFor(-0.5, -0.5), '-10_-10');
      expect(tileKeyFor(-33.9, 151.2), '-40_150');
    });
  });
}
