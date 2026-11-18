import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/location/map/map_tile.dart';

void main() {
  // Two thousandths of a degree east and north of 77.000, 12.000, then a
  // step back: coordinates are whole thousandths, delta-encoded.
  const json = '''
{
 "land":[[[77000,12000,10,0,0,10,-10,0]]],
 "urban":[[[77100,12100,20,0,0,20,-20,0]]],
 "rivers":[[77000,12000,5,5,5,5]],
 "roads":[[1,[77000,12000,100,0]],[0,[77000,12050,100,0]]],
 "places":[["Bengaluru",77560,12970,3]]
}''';

  test('decodes thousandths of a degree from deltas', () {
    final tile = MapTile.fromJson(jsonDecode(json) as Map<String, dynamic>);

    final ring = tile.land.single.rings.single;
    expect(ring, [
      const Offset(77.000, 12.000),
      const Offset(77.010, 12.000),
      const Offset(77.010, 12.010),
      const Offset(77.000, 12.010),
    ]);
    expect(tile.rivers.single.points.last.dx, closeTo(77.010, 1e-9));
    expect(tile.roads.map((r) => r.major), [true, false]);
    expect(tile.places.single.name, 'Bengaluru');
    expect(tile.places.single.longitude, closeTo(77.560, 1e-9));
    expect(tile.places.single.rank, 3);
  });

  test('a tile with only some layers leaves the others empty', () {
    final tile = MapTile.fromJson({'rivers': <dynamic>[]});
    expect(tile.land, isEmpty);
    expect(tile.roads, isEmpty);
    expect(tile.places, isEmpty);
  });

  test('every feature knows its bounds', () {
    final tile = MapTile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    expect(tile.urban.single.bounds, const Rect.fromLTRB(77.100, 12.100, 77.120, 12.120));
  });

  group('MapScene.within', () {
    final tile = MapTile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    final scene = MapScene([tile]);

    test('keeps features that touch the area and drops the rest', () {
      final near = scene.within(const Rect.fromLTRB(77.0, 12.0, 77.05, 12.05));
      expect(near.land, hasLength(1));
      expect(near.urban, isEmpty);
      expect(near.roads, hasLength(2));

      final far = scene.within(const Rect.fromLTRB(80, 20, 81, 21));
      expect(far.land, isEmpty);
      expect(far.roads, isEmpty);
      expect(far.places, isEmpty);
    });

    test('puts the tiles together', () {
      final both = MapScene([tile, tile]);
      expect(both.within(const Rect.fromLTRB(76, 11, 78, 13)).land, hasLength(2));
    });

    test('an empty scene has nothing, which is how open sea looks', () {
      expect(MapScene.empty.within(const Rect.fromLTRB(0, 0, 1, 1)).land, isEmpty);
    });
  });
}
