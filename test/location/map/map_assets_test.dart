import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/location/map/map_tile.dart';

/// The bundled Natural Earth tiles (built by tool/build_map_data.py).
void main() {
  final dir = Directory('assets/map');
  final files = dir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.json'),
  );

  test('the tiles are in the repository and named by their south-west corner', () {
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(
        RegExp(r'^-?\d+_-?\d+\.json$').hasMatch(f.uri.pathSegments.last),
        isTrue,
        reason: f.path,
      );
    }
  });

  test('the whole map stays small enough to ship', () {
    final bytes = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(bytes, lessThan(20 * 1024 * 1024));
  });

  test('every tile parses', () {
    for (final f in files) {
      MapTile.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
    }
  });

  test('Bengaluru tile: the city, its place name, a highway and a river', () {
    final tile = MapTile.fromJson(
      jsonDecode(File('assets/map/10_70.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(tile.places.map((p) => p.name), contains('Bengaluru'));
    expect(
      tile.urban.any((u) => u.bounds.contains(const Offset(77.56, 12.97))),
      isTrue,
    );
    expect(tile.roads.any((r) => r.major), isTrue);
    expect(tile.land, isNotEmpty);
    expect(tile.rivers, isNotEmpty);
  });

  test('the data is public domain Natural Earth and the tool says so', () {
    expect(
      File('tool/build_map_data.py').readAsStringSync(),
      contains('public domain'),
    );
  });
}
