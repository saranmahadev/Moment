import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "No network call is made to name a place": beyond the behaviour test on
/// the New Location screen, nothing in the app or its dependencies can
/// look a place up, because nothing that could do it is there at all.
void main() {
  test('no geocoding or HTTP package is a dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dependencies = pubspec.substring(
      pubspec.indexOf('\ndependencies:'),
      pubspec.indexOf('\ndev_dependencies:'),
    );

    for (final banned in ['geocoding', 'geocoder', 'http', 'dio', 'chopper']) {
      expect(
        RegExp('^\\s+$banned:', multiLine: true).hasMatch(dependencies),
        isFalse,
        reason: banned,
      );
    }
  });

  test('no source file opens a network connection', () {
    final offenders = <String>[];
    final networking = RegExp(
      r'\bHttpClient\b|\bSocket\.|\bRawSocket\b|\bWebSocket\b|'
      r"package:http/|Uri\.https?\(|'https?://",
    );
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('.g.dart'))
        continue;
      if (networking.hasMatch(file.readAsStringSync()))
        offenders.add(file.path);
    }

    expect(offenders, isEmpty);
  });
}
