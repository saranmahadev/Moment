@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/location/nominatim_place_names.dart';

/// Talks to the real OpenStreetMap service, so it is skipped everywhere
/// except the "Live check" workflow (see dart_test.yaml). It proves the
/// request the app sends is one the service accepts and answers in the
/// shape the app reads. Two requests, a second apart, per run.
void main() {
  test('a well-known place gets a name', () async {
    final names = NominatimPlaceNameLookup(language: 'en');

    final name = await names.nameFor(latitude: 48.85837, longitude: 2.29448);

    printOnFailure('answer: $name');
    expect(name, isNotNull);
    expect(name, contains('Eiffel'));
  });

  test('the middle of the ocean has none', () async {
    final names = NominatimPlaceNameLookup(language: 'en');
    // Do not ride on the first test's spacing: wait a second ourselves.
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(await names.nameFor(latitude: -48.87, longitude: -123.39), isNull);
  });
}
