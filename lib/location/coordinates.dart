import 'dart:math' as math;
import 'dart:ui';

/// "12.97160° N, 77.59456° E": coordinates as shown on screen.
String formatCoordinates(double latitude, double longitude) {
  final ns = latitude < 0 ? 'S' : 'N';
  final ew = longitude < 0 ? 'W' : 'E';
  return '${latitude.abs().toStringAsFixed(5)}° $ns, '
      '${longitude.abs().toStringAsFixed(5)}° $ew';
}

/// "12.971599, -77.594562": signed decimal degrees, the form other apps
/// and [parseCoordinates] accept. Six decimals is about a tenth of a metre.
String coordinatesForCopying(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

/// "±12 m": the radius of a position fix, never shown as less than a metre.
String formatAccuracy(double meters) => '±${math.max(1, meters.round())} m';

final _number = RegExp(r'([+-]?\d+(?:\.\d+)?)\s*°?\s*([NSEWnsew])?');

/// Reads a typed "latitude, longitude" pair, with optional degree signs
/// and hemisphere letters. Returns null unless it is exactly two numbers
/// naming a place on Earth.
(double, double)? parseCoordinates(String text) {
  final matches = _number.allMatches(text).toList();
  if (matches.length != 2) return null;
  if (text
      .replaceAll(_number, '')
      .replaceAll(RegExp(r'[\s,;]'), '')
      .isNotEmpty) {
    return null;
  }

  double? read(
    RegExpMatch match, {
    required String negative,
    required String positive,
  }) {
    var value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    final letter = match.group(2)?.toUpperCase();
    if (letter != null) {
      if (letter != negative && letter != positive) return null;
      if (letter == negative) value = -value.abs();
    }
    return value;
  }

  final latitude = read(matches[0], negative: 'S', positive: 'N');
  final longitude = read(matches[1], negative: 'W', positive: 'E');
  if (latitude == null || longitude == null) return null;
  if (latitude < -90 || latitude > 90) return null;
  if (longitude < -180 || longitude > 180) return null;
  return (latitude, longitude);
}

/// Lays places out on the offline map tile: each (latitude, longitude)
/// becomes a point with x and y from 0 to 1, north up and east right,
/// scaled so the whole set sits inside a margin. The tile is a stylised
/// stand-in for a map, so this shows how places lie relative to each
/// other, not where they are in the world.
List<Offset> projectPins(List<(double, double)> places) {
  if (places.isEmpty) return const [];
  const margin = 0.22;

  final latitudes = places.map((p) => p.$1);
  final longitudes = places.map((p) => p.$2);
  final south = latitudes.reduce(math.min);
  final north = latitudes.reduce(math.max);
  final west = longitudes.reduce(math.min);
  final east = longitudes.reduce(math.max);

  double along(double value, double low, double high) => high == low
      ? 0.5
      : margin + (1 - 2 * margin) * (value - low) / (high - low);

  return [
    for (final (latitude, longitude) in places)
      Offset(along(longitude, west, east), 1 - along(latitude, south, north)),
  ];
}
