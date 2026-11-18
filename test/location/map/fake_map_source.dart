import 'package:moment/location/map/map_source.dart';
import 'package:moment/location/map/map_tile.dart';
import 'package:moment/location/map/map_window.dart';

/// A small hand-made map around 12.91 N, 77.72 E: land, one city outline, a
/// highway, a river and a place name.
class FakeMapSource implements MapSource {
  FakeMapSource([MapScene? scene]) : scene = scene ?? _scene;

  final MapScene scene;
  final List<MapWindow> asked = [];

  @override
  Future<MapScene> load(MapWindow window) async {
    asked.add(window);
    return scene;
  }

  static final _scene = MapScene([
    MapTile.fromJson({
      'land': [
        [
          [70000, 5000, 20000, 0, 0, 20000, -20000, 0],
        ],
      ],
      'urban': [
        [
          [77400, 12800, 400, 0, 0, 300, -400, 0],
        ],
      ],
      'roads': [
        [
          1,
          [77000, 12500, 1500, 600],
        ],
      ],
      'rivers': [
        [77500, 12000, 300, 600, 100, 700],
      ],
      'places': [
        ['Bengaluru', 77560, 12970, 1],
      ],
    }),
  ]);
}
