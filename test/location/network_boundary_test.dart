import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Moment uses the internet for exactly one thing, and only when asked:
/// looking up a place name. These keep it to that.
void main() {
  const theOneFile = 'lib/location/nominatim_place_names.dart';

  Iterable<File> sources() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

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

  test('only the place-name lookup can open a network connection', () {
    final networking = RegExp(
      r'\bHttpClient\b|\bSocket\.|\bRawSocket\b|\bWebSocket\b|'
      r"package:http/|Uri\.https?\(|https?://",
    );
    final offenders = [
      for (final file in sources())
        if (networking.hasMatch(
          // Comments may name a URL; code may not.
          file.readAsStringSync().replaceAll(
            RegExp(r'^\s*//.*$', multiLine: true),
            '',
          ),
        ))
          file.path,
    ];

    expect(offenders, [theOneFile]);
  });

  test('the lookup talks to one host, over HTTPS', () {
    final source = File(theOneFile).readAsStringSync();
    final urls = RegExp(
      r'''https?://[^'"\s)]+''',
    ).allMatches(source).map((m) => m.group(0)).toSet();

    expect(urls, {'https://nominatim.openstreetmap.org/reverse'});
  });

  test('only the app wiring builds the real lookup', () {
    final users = [
      for (final file in sources())
        if (file.path != theOneFile &&
            file.readAsStringSync().contains('NominatimPlaceNameLookup'))
          file.path,
    ];

    expect(users, ['lib/app/moment_app.dart']);
  });
}
