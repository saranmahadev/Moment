import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/app/app_info.dart';

void main() {
  test('the version the app shows is the version in pubspec.yaml', () {
    final declared = RegExp(
      r'^version:\s*([^\s+]+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);

    expect(appVersion, declared);
  });
}
