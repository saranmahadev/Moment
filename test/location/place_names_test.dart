import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/location/nominatim_place_names.dart';
import 'package:moment/location/place_name_lookup.dart';

// Plain `test`s on purpose: the widget-test binding replaces HttpClient
// with one that refuses every request, and these talk to a loopback server.
void main() {
  group('placeNameFromNominatim', () {
    test('uses the name of the place when it has one', () {
      expect(
        placeNameFromNominatim({
          'name': 'Cubbon Park',
          'display_name': 'Cubbon Park, Bengaluru, Karnataka, India',
          'address': {'road': 'Kasturba Road', 'city': 'Bengaluru'},
        }),
        'Cubbon Park',
      );
    });

    test('falls back to the road and the locality', () {
      expect(
        placeNameFromNominatim({
          'name': '',
          'address': {
            'road': 'Kasturba Road',
            'suburb': 'Shanthala Nagar',
            'city': 'Bengaluru',
          },
        }),
        'Kasturba Road, Shanthala Nagar',
      );
    });

    test('falls back to the locality alone', () {
      expect(
        placeNameFromNominatim({
          'address': {'village': 'Hampi', 'state': 'Karnataka'},
        }),
        'Hampi',
      );
    });

    test('falls back to the start of the full address', () {
      expect(
        placeNameFromNominatim({
          'display_name': 'Somewhere, Far Away, Country',
          'address': <String, Object?>{},
        }),
        'Somewhere, Far Away',
      );
    });

    test('is null when the service found nothing', () {
      expect(placeNameFromNominatim({'error': 'Unable to geocode'}), isNull);
      expect(placeNameFromNominatim({}), isNull);
    });
  });

  group('NominatimPlaceNameLookup', () {
    late HttpServer server;
    late List<HttpRequest> requests;
    late void Function(HttpRequest request) respond;
    late List<Duration> waits;

    NominatimPlaceNameLookup lookup({Duration? timeout}) =>
        NominatimPlaceNameLookup(
          endpoint: Uri.parse('http://127.0.0.1:${server.port}/reverse'),
          language: 'en-GB',
          timeout: timeout ?? const Duration(seconds: 5),
          wait: (duration) async => waits.add(duration),
        );

    void json(HttpRequest request, Object body, {int status = 200}) {
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body))
        ..close();
    }

    setUp(() async {
      requests = [];
      waits = [];
      respond = (request) => json(request, {'name': 'Cubbon Park'});
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        requests.add(request);
        respond(request);
      });
    });

    tearDown(() => server.close(force: true));

    test(
      'asks for the place at the coordinates and returns its name',
      () async {
        final name = await lookup().nameFor(
          latitude: 12.976347123456,
          longitude: 77.592928987654,
        );

        expect(name, 'Cubbon Park');
        final query = requests.single.uri.queryParameters;
        expect(requests.single.method, 'GET');
        expect(requests.single.uri.path, '/reverse');
        expect(query['format'], 'jsonv2');
        expect(query['addressdetails'], '1');
        // Five decimals, about a metre: enough to name a place.
        expect(query['lat'], '12.97635');
        expect(query['lon'], '77.59293');
      },
    );

    test(
      'says who is asking and in which language, and nothing else',
      () async {
        await lookup().nameFor(latitude: 1, longitude: 2);

        final headers = requests.single.headers;
        expect(headers.value('user-agent'), startsWith('Moment/'));
        expect(headers.value('accept-language'), 'en-GB');
        expect(headers.value('cookie'), isNull);
        expect(headers.value('authorization'), isNull);
      },
    );

    test('is null when nothing is there', () async {
      respond = (request) => json(request, {'error': 'Unable to geocode'});

      expect(await lookup().nameFor(latitude: 0, longitude: 0), isNull);
    });

    test('is null when the service refuses or breaks', () async {
      respond = (request) => json(request, {'name': 'Nope'}, status: 503);
      expect(await lookup().nameFor(latitude: 1, longitude: 2), isNull);

      respond = (request) => request.response
        ..write('<html>not json</html>')
        ..close();
      expect(await lookup().nameFor(latitude: 3, longitude: 4), isNull);
    });

    test('is null when there is no connection', () async {
      final offline = lookup();
      await server.close(force: true);

      expect(await offline.nameFor(latitude: 1, longitude: 2), isNull);
    });

    test('gives up after the timeout', () async {
      respond = (request) {}; // never answers

      expect(
        await lookup(
          timeout: const Duration(milliseconds: 200),
        ).nameFor(latitude: 1, longitude: 2),
        isNull,
      );
    });

    test('does not ask twice for the same spot', () async {
      final names = lookup();

      await names.nameFor(latitude: 1.000001, longitude: 2.000001);
      final again = await names.nameFor(
        latitude: 1.000002,
        longitude: 2.000002,
      );

      expect(again, 'Cubbon Park');
      expect(requests, hasLength(1));
    });

    test('leaves a second between requests, as the service asks', () async {
      final names = lookup();

      await names.nameFor(latitude: 1, longitude: 2);
      expect(waits, isEmpty);
      await names.nameFor(latitude: 3, longitude: 4);

      expect(requests, hasLength(2));
      expect(waits, hasLength(1));
      expect(waits.single, lessThanOrEqualTo(const Duration(seconds: 1)));
      expect(waits.single, greaterThan(Duration.zero));
    });

    test('talks to OpenStreetMap over HTTPS unless told otherwise', () {
      expect(
        nominatimEndpoint,
        Uri.parse('https://nominatim.openstreetmap.org/reverse'),
      );
    });
  });

  test('a lookup can be faked', () async {
    final PlaceNameLookup fake = _Fixed('Home');
    expect(await fake.nameFor(latitude: 1, longitude: 2), 'Home');
  });
}

class _Fixed implements PlaceNameLookup {
  _Fixed(this.name);
  final String name;

  @override
  Future<String?> nameFor({
    required double latitude,
    required double longitude,
  }) async => name;
}
