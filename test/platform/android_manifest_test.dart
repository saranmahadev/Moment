import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Permissions the app must declare itself, because no plugin merges them
/// in. Without them Android refuses the request without ever asking.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  bool declares(String permission) => RegExp(
    '<uses-permission\\s+android:name="android\\.permission\\.$permission"',
  ).hasMatch(manifest);

  test('location logs can ask for the device position', () {
    expect(declares('ACCESS_FINE_LOCATION'), isTrue);
    expect(declares('ACCESS_COARSE_LOCATION'), isTrue);
  });

  test('the position is never read in the background', () {
    expect(declares('ACCESS_BACKGROUND_LOCATION'), isFalse);
  });

  test('the main manifest does not ask for the internet', () {
    expect(declares('INTERNET'), isFalse);
  });
}
