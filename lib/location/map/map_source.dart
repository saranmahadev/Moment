import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'map_tile.dart';
import 'map_window.dart';

/// Where map tiles come from. The app's own is [AssetMapSource], which reads
/// files bundled in the app; tests supply a fake. Nothing here may use the
/// network.
abstract interface class MapSource {
  Future<MapScene> load(MapWindow window);
}

/// Reads the Natural Earth tiles bundled under `assets/map/`. A tile that is
/// not there is open sea, so it is simply empty. Tiles are kept after the
/// first read.
class AssetMapSource implements MapSource {
  AssetMapSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final _tiles = <String, Future<MapTile>>{};

  Future<MapTile> _tile(String key) => _tiles.putIfAbsent(key, () async {
    try {
      final text = await _bundle.loadString('assets/map/$key.json');
      return MapTile.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on FlutterError {
      return MapTile();
    }
  });

  @override
  Future<MapScene> load(MapWindow window) async {
    final tiles = await Future.wait(window.tileKeys().map(_tile));
    return MapScene(tiles);
  }
}
