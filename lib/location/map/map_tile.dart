import 'dart:ui';

/// A closed outline, or a ring with holes: the first ring is the outside.
class MapPolygon {
  MapPolygon(this.rings) : bounds = _boundsOf(rings.expand((r) => r));

  final List<List<Offset>> rings;
  final Rect bounds;
}

class MapLine {
  MapLine(this.points) : bounds = _boundsOf(points);

  final List<Offset> points;
  final Rect bounds;
}

class MapRoad extends MapLine {
  MapRoad(super.points, {required this.major});

  final bool major;
}

class MapPlace {
  const MapPlace(this.name, this.longitude, this.latitude, this.rank);

  final String name;
  final double longitude;
  final double latitude;

  /// 0 is the most important place, 10 the least.
  final int rank;
}

Rect _boundsOf(Iterable<Offset> points) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Whole thousandths of a degree, delta-encoded as x, y, dx, dy, ...
List<Offset> _decode(List<dynamic> flat) {
  final points = <Offset>[];
  var x = 0, y = 0;
  for (var i = 0; i + 1 < flat.length; i += 2) {
    x += (flat[i] as num).toInt();
    y += (flat[i + 1] as num).toInt();
    points.add(Offset(x / 1000, y / 1000));
  }
  return points;
}

/// One 10 x 10 degree piece of the bundled Natural Earth map, as built by
/// tool/build_map_data.py.
class MapTile {
  MapTile({
    this.land = const [],
    this.lakes = const [],
    this.urban = const [],
    this.states = const [],
    this.rivers = const [],
    this.rail = const [],
    this.roads = const [],
    this.places = const [],
  });

  factory MapTile.fromJson(Map<String, dynamic> json) {
    List<MapPolygon> polys(String key) => [
      for (final p in (json[key] as List<dynamic>? ?? const []))
        MapPolygon([for (final r in p as List<dynamic>) _decode(r as List)]),
    ];
    List<MapLine> lines(String key) => [
      for (final l in (json[key] as List<dynamic>? ?? const []))
        MapLine(_decode(l as List)),
    ];
    return MapTile(
      land: polys('land'),
      lakes: polys('lakes'),
      urban: polys('urban'),
      states: lines('states'),
      rivers: lines('rivers'),
      rail: lines('rail'),
      roads: [
        for (final r in (json['roads'] as List<dynamic>? ?? const []))
          MapRoad(_decode((r as List)[1] as List), major: (r[0] as num) == 1),
      ],
      places: [
        for (final p in (json['places'] as List<dynamic>? ?? const []))
          MapPlace(
            (p as List)[0] as String,
            (p[1] as num) / 1000,
            (p[2] as num) / 1000,
            (p[3] as num).toInt(),
          ),
      ],
    );
  }

  final List<MapPolygon> land;
  final List<MapPolygon> lakes;
  final List<MapPolygon> urban;
  final List<MapLine> states;
  final List<MapLine> rivers;
  final List<MapLine> rail;
  final List<MapRoad> roads;
  final List<MapPlace> places;
}

/// Everything to draw for one picture: the tiles it overlaps, put together.
class MapScene {
  MapScene(List<MapTile> tiles)
    : land = [for (final t in tiles) ...t.land],
      lakes = [for (final t in tiles) ...t.lakes],
      urban = [for (final t in tiles) ...t.urban],
      states = [for (final t in tiles) ...t.states],
      rivers = [for (final t in tiles) ...t.rivers],
      rail = [for (final t in tiles) ...t.rail],
      roads = [for (final t in tiles) ...t.roads],
      places = [for (final t in tiles) ...t.places];

  static final MapScene empty = MapScene(const []);

  final List<MapPolygon> land;
  final List<MapPolygon> lakes;
  final List<MapPolygon> urban;
  final List<MapLine> states;
  final List<MapLine> rivers;
  final List<MapLine> rail;
  final List<MapRoad> roads;
  final List<MapPlace> places;

  /// Only what touches [area] (longitude across, latitude down), so a
  /// picture does not walk every point of a 10 degree tile.
  MapScene within(Rect area) {
    // Inclusive, so a flat feature (a road running due east) still counts.
    bool hits(Rect b) =>
        b.left <= area.right &&
        b.right >= area.left &&
        b.top <= area.bottom &&
        b.bottom >= area.top;
    return MapScene([
      MapTile(
        land: land.where((f) => hits(f.bounds)).toList(),
        lakes: lakes.where((f) => hits(f.bounds)).toList(),
        urban: urban.where((f) => hits(f.bounds)).toList(),
        states: states.where((f) => hits(f.bounds)).toList(),
        rivers: rivers.where((f) => hits(f.bounds)).toList(),
        rail: rail.where((f) => hits(f.bounds)).toList(),
        roads: roads.where((f) => hits(f.bounds)).toList(),
        places: places
            .where((p) => area.contains(Offset(p.longitude, p.latitude)))
            .toList(),
      ),
    ]);
  }
}
