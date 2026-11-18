import 'package:flutter_test/flutter_test.dart';
import 'package:moment/streaks/streak_model.dart';

DateTime d(int month, int day, [int year = 2026]) =>
    DateTime.utc(year, month, day);

Set<DateTime> days(Iterable<(int, int)> md) => {
  for (final (m, day) in md) d(m, day),
};

Set<DateTime> run(int month, int from, int to) => {
  for (var i = from; i <= to; i++) d(month, i),
};

void main() {
  final today = d(11, 6);

  group('current streak', () {
    test('no logs means no streak', () {
      final s = streakOf({}, today);
      expect(s.current, 0);
      expect(s.longest, 0);
      expect(s.loggedToday, isFalse);
      expect(s.currentStart, isNull);
    });

    test('a log today is a streak of one', () {
      final s = streakOf({today}, today);
      expect(s.current, 1);
      expect(s.loggedToday, isTrue);
      expect(s.currentStart, today);
      expect(s.currentEnd, today);
    });

    test('consecutive days up to today', () {
      final s = streakOf(run(11, 1, 6), today);
      expect(s.current, 6);
      expect(s.longest, 6);
      expect(s.currentStart, d(11, 1));
    });

    test('today not logged yet still counts the run to yesterday', () {
      final s = streakOf(run(11, 1, 5), today);
      expect(s.current, 5);
      expect(s.loggedToday, isFalse);
      expect(s.atRisk, isTrue);
    });

    test('a streak logged today is not at risk', () {
      expect(streakOf(run(11, 1, 6), today).atRisk, isFalse);
    });

    test('nothing for a day and no grace ends the streak', () {
      final s = streakOf(run(11, 1, 4), today);
      expect(s.current, 0);
      expect(s.longest, 4);
      expect(s.atRisk, isFalse);
    });

    test('a gap in the middle starts a new streak', () {
      final s = streakOf({...run(11, 1, 3), ...run(11, 5, 6)}, today);
      expect(s.current, 2);
      expect(s.longest, 3);
    });

    test('several logs on one day count once', () {
      // The model takes days, so the same day listed twice is one day.
      final s = streakOf({d(11, 5), d(11, 5), d(11, 6)}, today);
      expect(s.current, 2);
    });

    test('runs cross month and year ends', () {
      final s = streakOf({
        d(12, 30, 2025),
        d(12, 31, 2025),
        d(1, 1),
        d(1, 2),
      }, d(1, 2));
      expect(s.current, 4);
    });

    test('days are calendar days, so daylight saving changes nothing', () {
      // UTC midnights: 29 and 30 March 2026 span a clock change in Europe.
      final s = streakOf({d(3, 28), d(3, 29), d(3, 30)}, d(3, 30));
      expect(s.current, 3);
    });

    test('logs dated after today are ignored', () {
      final s = streakOf({today, d(11, 7)}, today);
      expect(s.current, 1);
    });
  });

  group('grace days', () {
    final gap = {...run(10, 26, 28), ...run(10, 30, 31), ...run(11, 1, 6)};

    test('without grace the missed day ends the run before it', () {
      final s = streakOf(gap, today);
      expect(s.current, 8); // 30 Oct to 6 Nov
      expect(s.longest, 8);
      expect(s.graceDaysUsed, 0);
    });

    test('one grace day keeps the streak across one missed day', () {
      final s = streakOf(gap, today, grace: 1);
      expect(s.current, 12); // 26 Oct to 6 Nov, the missed day counts
      expect(s.currentStart, d(10, 26));
      expect(s.graceDaysUsed, 1);
      expect(s.graceDays, contains(d(10, 29)));
    });

    test('two missed days in a row need two grace days in a week', () {
      final two = {...run(11, 1, 2), ...run(11, 5, 6)}; // 3 and 4 missed
      expect(streakOf(two, today, grace: 1).current, 2);
      expect(streakOf(two, today, grace: 2).current, 6);
    });

    test('grace is per rolling seven days: a second miss in a week breaks', () {
      // Misses on 2 and 4 Nov are inside one week.
      final logs = {d(11, 1), d(11, 3), d(11, 5), d(11, 6)};
      expect(streakOf(logs, today, grace: 1).current, 2);
      expect(streakOf(logs, today, grace: 2).current, 6);
    });

    test('misses more than a week apart each use a fresh grace day', () {
      final logs = {...run(10, 20, 21), ...run(10, 23, 31), ...run(11, 2, 6)};
      // Misses on 22 Oct and 1 Nov are ten days apart.
      expect(streakOf(logs, today, grace: 1).current, 18);
    });

    test(
      'missing yesterday with grace keeps the streak; today can save it',
      () {
        final logs = run(11, 1, 4); // 5 missed, today (6) not logged yet
        final s = streakOf(logs, today, grace: 1);
        expect(s.current, 4);
        expect(s.atRisk, isTrue);
        expect(s.inGraceDay, isTrue);
      },
    );

    test('too many days missed ends it even with grace', () {
      final logs = run(11, 1, 3); // 4, 5 missed
      expect(streakOf(logs, today, grace: 1).current, 0);
    });

    test('a streak never ends or starts on a forgiven day', () {
      final s = streakOf({d(11, 2), d(11, 4)}, d(11, 4), grace: 1);
      expect(s.currentStart, d(11, 2));
      expect(s.currentEnd, d(11, 4));
      final trailing = streakOf({d(11, 2), d(11, 4)}, d(11, 6), grace: 3);
      expect(trailing.currentEnd, d(11, 4));
    });

    test('longest streak uses grace too', () {
      final old = {...run(8, 2, 18), ...run(8, 20, 31), d(9, 1), d(9, 2)};
      // 19 Aug missed: 2 Aug to 2 Sep is 32 days with one grace day.
      expect(streakOf(old, today, grace: 1).longest, 32);
      expect(streakOf(old, today).longest, 17);
    });

    test('grace days can be 0 to 3 only', () {
      expect(() => streakOf({}, today, grace: -1), throwsArgumentError);
      expect(() => streakOf({}, today, grace: 4), throwsArgumentError);
    });
  });

  group('counts', () {
    test('days logged counts distinct days', () {
      expect(streakOf(run(11, 1, 3), today).daysLogged, 3);
    });

    test(
      'graceDays lists forgiven days of every run, not only the current',
      () {
        final logs = {d(8, 1), d(8, 3), d(11, 5), d(11, 6)};
        final s = streakOf(logs, today, grace: 1);
        expect(s.graceDays, {d(8, 2)});
      },
    );
  });

  group('milestones', () {
    test('the list is 3, 7, 14, 30, 60, 100, 200, 365', () {
      expect(streakMilestones, [3, 7, 14, 30, 60, 100, 200, 365]);
    });

    test('a milestone is dated the day the run first reached it', () {
      final s = streakOf(run(11, 1, 6), today);
      final three = s.milestones.firstWhere((m) => m.days == 3);
      expect(three.reachedOn, d(11, 3));
      final seven = s.milestones.firstWhere((m) => m.days == 7);
      expect(seven.reachedOn, isNull);
    });

    test('an old run still counts as reached', () {
      final old = run(8, 1, 14);
      final s = streakOf(old, today);
      expect(s.milestones.firstWhere((m) => m.days == 14).reachedOn, d(8, 14));
      expect(s.longest, 14);
    });

    test('the earliest run to reach a milestone gives its date', () {
      final logs = {...run(5, 1, 3), ...run(8, 1, 5)};
      final s = streakOf(logs, today);
      expect(s.milestones.first.reachedOn, d(5, 3));
    });

    test('grace days count toward a milestone', () {
      final s = streakOf({d(11, 1), d(11, 3), d(11, 4)}, today, grace: 1);
      expect(s.milestones.first.reachedOn, d(11, 3));
    });
  });

  test('a year of logs is analysed quickly', () {
    final many = {
      for (var i = 0; i < 20000; i++) d(1, 1, 1970).add(Duration(days: i)),
    };
    final end = d(1, 1, 1970).add(const Duration(days: 19999));
    final watch = Stopwatch()..start();
    final s = streakOf(many, end, grace: 2);
    watch.stop();
    expect(s.current, 20000);
    expect(watch.elapsedMilliseconds, lessThan(500));
  });
}
