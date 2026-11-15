import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS ends the app the moment it touches a protected resource without a
/// usage description, and no widget test can see that. This keeps the
/// list in step with the features that need one.
void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  String? descriptionFor(String key) {
    final match = RegExp(
      '<key>$key</key>\\s*<string>([^<]*)</string>',
    ).firstMatch(plist);
    return match?.group(1);
  }

  const required = {
    'NSFaceIDUsageDescription': 'app lock',
    'NSMicrophoneUsageDescription': 'audio logs and video sound',
    'NSCameraUsageDescription': 'photo and video logs',
    'NSPhotoLibraryUsageDescription': 'choosing photos and videos',
    'NSLocationWhenInUseUsageDescription': 'location logs',
  };

  for (final entry in required.entries) {
    test('${entry.key} is declared (${entry.value})', () {
      final description = descriptionFor(entry.key);
      expect(description, isNotNull, reason: 'missing ${entry.key}');
      expect(description!.trim(), isNotEmpty);
    });
  }

  test('every description says the data stays on the device', () {
    for (final key in required.keys.where(
      (k) => k != 'NSFaceIDUsageDescription',
    )) {
      expect(descriptionFor(key), contains('on this device'), reason: key);
    }
  });
}
