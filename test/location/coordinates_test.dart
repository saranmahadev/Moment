import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/location/coordinates.dart';

void main() {
  group('formatCoordinates', () {
    test('shows five decimals with hemisphere letters', () {
      expect(
        formatCoordinates(12.971598765, 77.594562345),
        '12.97160° N, 77.59456° E',
      );
      expect(
        formatCoordinates(-33.868819, -151.209295),
        '33.86882° S, 151.20930° W',
      );
    });

    test('the equator and prime meridian read as N and E', () {
      expect(formatCoordinates(0, 0), '0.00000° N, 0.00000° E');
    });
  });

  group('coordinatesForCopying', () {
    test('is plain signed decimal degrees that parse back', () {
      const text = '12.971599, -77.594562';
      expect(coordinatesForCopying(12.9715987654, -77.5945623456), text);
      expect(parseCoordinates(text), (12.971599, -77.594562));
    });
  });

  group('formatAccuracy', () {
    test('rounds to whole metres', () {
      expect(formatAccuracy(12), '±12 m');
      expect(formatAccuracy(7.6), '±8 m');
      expect(formatAccuracy(0.2), '±1 m');
    });
  });

  group('parseCoordinates', () {
    test('reads "latitude, longitude" with or without spaces', () {
      expect(parseCoordinates('12.9716, 77.5946'), (12.9716, 77.5946));
      expect(parseCoordinates('12.9716,77.5946'), (12.9716, 77.5946));
      expect(parseCoordinates('  -33.8688   151.2093 '), (-33.8688, 151.2093));
    });

    test('reads hemisphere letters and degree signs', () {
      expect(parseCoordinates('12.9716° N, 77.5946° E'), (12.9716, 77.5946));
      expect(parseCoordinates('33.8688 S 151.2093 W'), (-33.8688, -151.2093));
    });

    test('keeps every digit that was typed', () {
      expect(parseCoordinates('12.971598765432101, -77.59456234567891'), (
        12.971598765432101,
        -77.59456234567891,
      ));
    });

    test('rejects text that is not a pair of numbers', () {
      expect(parseCoordinates(''), isNull);
      expect(parseCoordinates('here'), isNull);
      expect(parseCoordinates('12.9716'), isNull);
      expect(parseCoordinates('12.9716, 77.5946, 3'), isNull);
    });

    test('rejects places that are not on Earth', () {
      expect(parseCoordinates('91, 0'), isNull);
      expect(parseCoordinates('0, 181'), isNull);
      expect(parseCoordinates('-90.5, 10'), isNull);
    });
  });

  group('projectPins', () {
    test('a single place sits in the middle', () {
      expect(projectPins([(12.0, 77.0)]), [const Offset(0.5, 0.5)]);
    });

    test('no places gives no pins', () {
      expect(projectPins([]), isEmpty);
    });

    test('north is up and east is right, inside the margin', () {
      final pins = projectPins([
        (10.0, 70.0), // south-west
        (20.0, 80.0), // north-east
      ]);

      expect(pins[0].dx, lessThan(pins[1].dx));
      expect(pins[0].dy, greaterThan(pins[1].dy));
      for (final pin in pins) {
        expect(pin.dx, inInclusiveRange(0.15, 0.85));
        expect(pin.dy, inInclusiveRange(0.15, 0.85));
      }
    });

    test('places on the same line still spread along the other axis', () {
      final pins = projectPins([(10.0, 70.0), (10.0, 80.0)]);
      expect(pins[0].dy, pins[1].dy);
      expect(pins[0].dx, isNot(pins[1].dx));
    });
  });
}
