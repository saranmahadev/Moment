import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app/app_info.dart';
import 'place_name_lookup.dart';

/// OpenStreetMap's reverse-geocoding service. This file is the only place
/// in the app that opens a network connection; a test keeps it that way.
final nominatimEndpoint = Uri.parse(
  'https://nominatim.openstreetmap.org/reverse',
);

/// Picks a short name out of a Nominatim reverse-geocoding answer: the
/// place's own name, else its road and locality, else the start of the
/// full address. Null when the service found nothing.
String? placeNameFromNominatim(Map<String, Object?> json) {
  String? text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  final name = text(json['name']);
  if (name != null) return name;

  final address = json['address'];
  if (address is Map) {
    String? first(List<String> keys) {
      for (final key in keys) {
        final value = text(address[key]);
        if (value != null) return value;
      }
      return null;
    }

    final road = first(const ['road', 'pedestrian', 'footway', 'path']);
    final locality = first(const [
      'neighbourhood',
      'suburb',
      'village',
      'town',
      'city',
      'municipality',
      'county',
    ]);
    if (road != null && locality != null) return '$road, $locality';
    if (road != null) return road;
    if (locality != null) return locality;
  }

  final display = text(json['display_name']);
  if (display != null) {
    return display.split(',').map((part) => part.trim()).take(2).join(', ');
  }
  return null;
}

/// Looks a place name up on OpenStreetMap's Nominatim service.
///
/// What leaves the device: the coordinates rounded to five decimals, the
/// preferred language and the app's name and version. No cookies, no
/// account, no identifier. The service's usage policy is respected: at
/// most one request a second, and the same spot is never asked for twice.
class NominatimPlaceNameLookup implements PlaceNameLookup {
  NominatimPlaceNameLookup({
    Uri? endpoint,
    String? language,
    this.timeout = const Duration(seconds: 8),
    Future<void> Function(Duration)? wait,
  }) : _endpoint = endpoint ?? nominatimEndpoint,
       _language = language ?? Platform.localeName.replaceAll('_', '-'),
       _wait = wait ?? Future<void>.delayed;

  static const _spacing = Duration(seconds: 1);

  final Uri _endpoint;
  final String _language;
  final Duration timeout;
  final Future<void> Function(Duration) _wait;

  final _found = <String, String?>{};
  DateTime? _lastRequest;

  @override
  Future<String?> nameFor({
    required double latitude,
    required double longitude,
  }) async {
    final lat = latitude.toStringAsFixed(5);
    final lon = longitude.toStringAsFixed(5);
    final spot = '$lat,$lon';
    if (_found.containsKey(spot)) return _found[spot];

    final last = _lastRequest;
    if (last != null) {
      final since = DateTime.now().difference(last);
      if (since < _spacing) await _wait(_spacing - since);
    }
    _lastRequest = DateTime.now();

    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final name = await _ask(client, lat, lon).timeout(timeout);
      _found[spot] = name;
      return name;
    } on Object {
      // Offline, too slow, refused or unreadable: there is simply no
      // suggestion, and the next try may do better, so nothing is kept.
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> _ask(HttpClient client, String lat, String lon) async {
    final uri = _endpoint.replace(
      queryParameters: {
        'format': 'jsonv2',
        'lat': lat,
        'lon': lon,
        'zoom': '18',
        'addressdetails': '1',
      },
    );
    final request = await client.getUrl(uri);
    request.headers
      ..set(HttpHeaders.userAgentHeader, 'Moment/$appVersion (journal app)')
      ..set(HttpHeaders.acceptLanguageHeader, _language)
      ..set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('status ${response.statusCode}', uri: uri);
    }
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    if (json is! Map<String, Object?>) throw const FormatException();
    return placeNameFromNominatim(json);
  }
}
