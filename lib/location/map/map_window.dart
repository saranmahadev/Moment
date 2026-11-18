import 'dart:math' as math;
import 'dart:ui';

/// How far the map is zoomed. The span is the height of the picture; the
/// bundled data (Natural Earth, 1:10 million) has outlines of cities,
/// main highways, rivers and state lines but no streets, so City is the
/// closest step offered.
enum MapZoom {
  region(1.6, 'Region'),
  area(0.6, 'Area'),
  city(0.22, 'City');

  const MapZoom(this.halfLatitude, this.label);

  /// Half the picture's height, in degrees of latitude.
  final double halfLatitude;
  final String label;
}

const _kmPerDegree = 111.2;

/// The 10 x 10 degree tile a place falls in, named by its south-west
/// corner: `10_70` is latitude 10 to 20 north, longitude 70 to 80 east.
String tileKeyFor(double latitude, double longitude) =>
    '${(latitude / 10).floor() * 10}_${(longitude / 10).floor() * 10}';

/// The part of the world a map picture shows: [zoom] sets its height, and
/// [aspect] (width over height) its width. Longitude is scaled by the cosine
/// of the latitude so shapes keep their proportions. [pinAt] is where the
/// pin sits in the picture, as fractions across and down.
class MapWindow {
  MapWindow({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.aspect,
    this.pinAt = const Offset(0.5, 0.5),
  });

  final double latitude;
  final double longitude;
  final MapZoom zoom;
  final double aspect;
  final Offset pinAt;

  double get _height => zoom.halfLatitude * 2;
  double get _width => _height * aspect / math.cos(latitude * math.pi / 180);

  double get north => latitude + _height * pinAt.dy;
  double get south => north - _height;
  double get west => longitude - _width * pinAt.dx;
  double get east => west + _width;

  /// The picture's width, rounded to a whole number of kilometres.
  int get kmAcross => (_height * aspect * _kmPerDegree).round();

  /// The window as longitude and latitude, for choosing what to draw.
  Rect get bounds => Rect.fromLTRB(west, south, east, north);

  /// Where a place falls in a picture of [size], in pixels.
  Offset project(double lon, double lat, Size size) => Offset(
    (lon - west) / (east - west) * size.width,
    (north - lat) / (north - south) * size.height,
  );

  /// The tiles this window overlaps.
  Set<String> tileKeys() {
    final keys = <String>{};
    for (var lat = (south / 10).floor(); lat <= (north / 10).floor(); lat++) {
      for (var lon = (west / 10).floor(); lon <= (east / 10).floor(); lon++) {
        keys.add('${lat * 10}_${lon * 10}');
      }
    }
    return keys;
  }
}
