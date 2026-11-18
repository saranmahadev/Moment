/// Streaks, worked out from the days something was logged.
///
/// A streak is derived, never stored: it is a pure function of the set of
/// calendar days that have a log ([Log.localDay], UTC midnights) and of
/// today. Moving a log, restoring a backup or emptying Trash therefore
/// cannot leave a streak out of step with the journal.
library;

/// The streak lengths that are marked on the Streaks page.
const streakMilestones = [3, 7, 14, 30, 60, 100, 200, 365];

/// The most missed days a week the settings can forgive.
const maxGraceDays = 3;

/// A milestone and the day a run first reached it, if one has.
class StreakMilestone {
  const StreakMilestone(this.days, this.reachedOn);

  final int days;
  final DateTime? reachedOn;
}

/// What the logged days add up to.
class StreakSummary {
  const StreakSummary({
    required this.current,
    required this.currentStart,
    required this.currentEnd,
    required this.longest,
    required this.loggedToday,
    required this.inGraceDay,
    required this.graceDaysUsed,
    required this.graceDays,
    required this.daysLogged,
    required this.milestones,
  });

  /// Days in the running streak, forgiven days included; 0 when none.
  final int current;

  /// First and last logged day of the running streak.
  final DateTime? currentStart;
  final DateTime? currentEnd;

  /// The longest streak ever, forgiven days included.
  final int longest;
  final bool loggedToday;

  /// Yesterday was missed and forgiven, and today has no log yet.
  final bool inGraceDay;

  /// Forgiven days inside the running streak.
  final int graceDaysUsed;

  /// Every forgiven day in every streak: days with no log that a streak
  /// carried across.
  final Set<DateTime> graceDays;

  /// Distinct days with at least one log.
  final int daysLogged;

  final List<StreakMilestone> milestones;

  /// A streak is running but today has no log yet.
  bool get atRisk => current > 0 && !loggedToday;
}

/// Works out the streaks in [days] (UTC midnights; duplicates and days
/// after [today] are ignored) as of [today].
///
/// With [grace] days a week, a missed day does not break a streak while no
/// more than [grace] days were missed in any seven days in a row. A streak
/// begins and ends on a logged day, and today is not counted as missed
/// until it is over.
StreakSummary streakOf(Set<DateTime> days, DateTime today, {int grace = 0}) {
  if (grace < 0 || grace > maxGraceDays) {
    throw ArgumentError.value(grace, 'grace', 'must be 0 to $maxGraceDays');
  }
  final todayIndex = _index(today);
  final logged = <int>{
    for (final day in days)
      if (_index(day) <= todayIndex) _index(day),
  };
  final sorted = logged.toList()..sort();

  final runs = <(int, int)>[];
  int? start;
  var last = 0;
  final misses = <int>[];
  var previous = 0;
  for (final day in sorted) {
    if (start != null) {
      // Walk the days nobody logged between the previous log and this one.
      var broken = false;
      for (var gap = previous + 1; gap < day; gap++) {
        misses
          ..add(gap)
          ..removeWhere((m) => m <= gap - 7);
        if (misses.length > grace) {
          broken = true;
          break;
        }
      }
      if (broken) {
        runs.add((start, last));
        start = null;
        misses.clear();
      }
    }
    start ??= day;
    last = day;
    previous = day;
  }
  if (start != null) {
    // The days after the last log, up to yesterday, may end the run too.
    var broken = false;
    for (var gap = previous + 1; gap < todayIndex; gap++) {
      misses
        ..add(gap)
        ..removeWhere((m) => m <= gap - 7);
      if (misses.length > grace) {
        broken = true;
        break;
      }
    }
    runs.add((start, last));
    if (broken) {
      return _summary(runs, logged, todayIndex, running: null);
    }
    return _summary(runs, logged, todayIndex, running: runs.length - 1);
  }
  return _summary(runs, logged, todayIndex, running: null);
}

StreakSummary _summary(
  List<(int, int)> runs,
  Set<int> logged,
  int todayIndex, {
  required int? running,
}) {
  var longest = 0;
  final graceDays = <DateTime>{};
  for (final (from, to) in runs) {
    if (to - from + 1 > longest) longest = to - from + 1;
    for (var day = from; day <= to; day++) {
      if (!logged.contains(day)) graceDays.add(_date(day));
    }
  }
  final current = running == null ? null : runs[running];
  final loggedToday = logged.contains(todayIndex);
  final currentLength = current == null ? 0 : current.$2 - current.$1 + 1;
  var used = 0;
  if (current != null) {
    for (var day = current.$1; day <= current.$2; day++) {
      if (!logged.contains(day)) used++;
    }
  }
  return StreakSummary(
    current: currentLength,
    currentStart: current == null ? null : _date(current.$1),
    currentEnd: current == null ? null : _date(current.$2),
    longest: longest,
    loggedToday: loggedToday,
    inGraceDay: current != null && !loggedToday && current.$2 < todayIndex - 1,
    graceDaysUsed: used,
    graceDays: graceDays,
    daysLogged: logged.length,
    milestones: [
      for (final target in streakMilestones)
        StreakMilestone(target, _reached(runs, target)),
    ],
  );
}

DateTime? _reached(List<(int, int)> runs, int target) {
  int? first;
  for (final (from, to) in runs) {
    if (to - from + 1 >= target) {
      final day = from + target - 1;
      if (first == null || day < first) first = day;
    }
  }
  return first == null ? null : _date(first);
}

/// Whole days since 1970 of a UTC calendar day.
int _index(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

DateTime _date(int index) => DateTime.fromMillisecondsSinceEpoch(
  index * Duration.millisecondsPerDay,
  isUtc: true,
);
