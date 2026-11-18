import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/streaks/streak_model.dart';
import 'package:moment/widgets/widget_snapshot.dart';

DateTime d(int day) => DateTime.utc(2026, 11, day);

WidgetSnapshot build(
  Set<DateTime> days, {
  int today = 18,
  int grace = 1,
  bool show = true,
}) =>
    WidgetSnapshot.build(days: days, today: d(today), grace: grace, show: show);

void main() {
  group('WidgetSnapshot', () {
    test('carries the streak, the day it is for and this week', () {
      // Wed 18 Nov 2026: logged Fri 13 to Wed 18, so six days.
      final s = build({for (var i = 13; i <= 18; i++) d(i)});

      expect(s.show, isTrue);
      expect(s.asOf, '2026-11-18');
      expect(s.streak, 6);
      // Mon 16, Tue 17, Wed 18 logged; the rest of the week is ahead.
      expect(s.week, [true, true, true, false, false, false, false]);
    });

    test('a streak with today still to log is kept through yesterday', () {
      final s = build({for (var i = 13; i <= 17; i++) d(i)});

      expect(s.streak, 5);
      expect(s.week, [true, true, false, false, false, false, false]);
    });

    test('says no streak when there is none', () {
      final s = build({d(1)}, grace: 0);

      expect(s.streak, 0);
      expect(s.endsOn, isNull);
    });

    test('with no grace a streak lasts through the day after the last log', () {
      // Last log Tue 17, today Wed 18 not logged yet: still alive today, and
      // gone on Thu 19 once Wed has been missed.
      final s = build({d(16), d(17)}, grace: 0);

      expect(s.endsOn, '2026-11-18');
    });

    test('endsOn is the last day the streak is alive, whatever the grace', () {
      for (var grace = 0; grace <= maxGraceDays; grace++) {
        final days = {for (var i = 10; i <= 17; i++) d(i)};
        final s = build(days, grace: grace);
        final end = DateTime.parse(s.endsOn!);

        expect(
          streakOf(days, end, grace: grace).current,
          greaterThan(0),
          reason: 'alive on its last day (grace $grace)',
        );
        expect(
          streakOf(
            days,
            end.add(const Duration(days: 1)),
            grace: grace,
          ).current,
          0,
          reason: 'gone the day after (grace $grace)',
        );
      }
    });

    test('with the widget switch off it carries no streak at all', () {
      final s = build({for (var i = 13; i <= 18; i++) d(i)}, show: false);

      expect(s.show, isFalse);
      expect(s.streak, 0);
      expect(s.endsOn, isNull);
      expect(s.week, everyElement(isFalse));
    });

    test('the JSON is small, versioned and round-trips', () {
      final s = build({for (var i = 13; i <= 18; i++) d(i)});
      final json = jsonDecode(s.encode()) as Map<String, dynamic>;

      expect(json['v'], 1);
      expect(json.keys.toSet(), {
        'v',
        'show',
        'asOf',
        'streak',
        'endsOn',
        'week',
      });
      expect(WidgetSnapshot.decode(s.encode()), s);
    });

    test('an unknown version or damaged text decodes to nothing', () {
      expect(WidgetSnapshot.decode('{"v":2}'), isNull);
      expect(WidgetSnapshot.decode('not json'), isNull);
    });
  });
}
