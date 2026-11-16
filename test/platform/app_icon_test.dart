import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Width, height and colour type from a PNG's header.
({int width, int height, bool hasAlpha}) png(String path) {
  final bytes = File(path).readAsBytesSync();
  final header = ByteData.sublistView(bytes, 16, 26);
  final colourType = header.getUint8(9);
  return (
    width: header.getUint32(0),
    height: header.getUint32(4),
    // 4 is grey with alpha, 6 is colour with alpha.
    hasAlpha: colourType == 4 || colourType == 6,
  );
}

/// The launcher icon is Moment's own mark (design/logo/), exported at
/// every size each platform asks for.
void main() {
  const res = 'android/app/src/main/res';
  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  test('the logo sources are in the repository', () {
    for (final name in [
      'mark.svg',
      'mark-dark.svg',
      'lockup.svg',
      'lockup-dark.svg',
      'build_logo.py',
      'export.cjs',
    ]) {
      expect(File('design/logo/$name').existsSync(), isTrue, reason: name);
    }
  });

  group('Android', () {
    for (final MapEntry(key: density, value: scale) in densities.entries) {
      test('$density: the icon and both adaptive layers, at size', () {
        final legacy = png('$res/mipmap-$density/ic_launcher.png');
        expect((legacy.width, legacy.height), (48 * scale, 48 * scale));

        for (final layer in ['foreground', 'background']) {
          final image = png('$res/mipmap-$density/ic_launcher_$layer.png');
          expect(
            (image.width, image.height),
            (108 * scale, 108 * scale),
            reason: layer,
          );
        }
        // The foreground floats over the background; the background is
        // solid.
        expect(
          png('$res/mipmap-$density/ic_launcher_foreground.png').hasAlpha,
          isTrue,
        );
        expect(
          png('$res/mipmap-$density/ic_launcher_background.png').hasAlpha,
          isFalse,
        );
      });
    }

    test('an adaptive icon ties the two layers together', () {
      final xml = File(
        '$res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsStringSync();

      expect(xml, contains('<adaptive-icon'));
      expect(xml, contains('@mipmap/ic_launcher_background'));
      expect(xml, contains('@mipmap/ic_launcher_foreground'));
    });
  });

  group('iOS', () {
    const set = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final images =
        (jsonDecode(File('$set/Contents.json').readAsStringSync())
                as Map<String, Object?>)['images']!
            as List<Object?>;

    test('every icon the asset catalogue lists exists at its size', () {
      for (final image in images.cast<Map<String, Object?>>()) {
        final points = double.parse(
          (image['size']! as String).split('x').first,
        );
        final scale = int.parse(
          (image['scale']! as String).replaceAll('x', ''),
        );
        final file = png('$set/${image['filename']}');

        expect(
          (file.width, file.height),
          ((points * scale).round(), (points * scale).round()),
          reason: '${image['filename']}',
        );
      }
    });

    test('no icon has transparency, which the App Store refuses', () {
      for (final image in images.cast<Map<String, Object?>>()) {
        expect(
          png('$set/${image['filename']}').hasAlpha,
          isFalse,
          reason: '${image['filename']}',
        );
      }
    });
  });
}
