import 'dart:math' as math;
import 'dart:ui';

/// How strongly a day with [count] logs is shaded: 0 for none, then four
/// steps.
int heatLevel(int count) => switch (count) {
  <= 0 => 0,
  1 => 1,
  2 || 3 => 2,
  4 || 5 => 3,
  _ => 4,
};

/// One day of the heatmap.
class HeatmapCell {
  const HeatmapCell({
    required this.day,
    required this.count,
    required this.grace,
  });

  /// A UTC midnight, the form [Log.localDay] uses.
  final DateTime day;

  /// Logs made on the day.
  final int count;

  /// A day with no logs that a streak carried across.
  final bool grace;

  int get level => heatLevel(count);
}

/// A position in the grid: [week] is the column, [row] the weekday from
/// Monday (0) to Sunday (6).
typedef HeatmapSpot = ({int week, int row});

/// The days of the Activity heatmap, a column per week, Monday first, the
/// last column being the week of today. Days after today are null.
class HeatmapGrid {
  HeatmapGrid._(this.columns, this.monthLabels, this._start, this._today);

  final List<List<HeatmapCell?>> columns;

  /// Above a column, the month whose first Monday it holds; otherwise null.
  final List<String?> monthLabels;
  final DateTime _start;
  final DateTime _today;

  HeatmapSpot? positionOf(DateTime day) {
    final days = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(_start).inDays;
    if (days < 0 ||
        DateTime.utc(day.year, day.month, day.day).isAfter(_today)) {
      return null;
    }
    return (week: days ~/ 7, row: days % 7);
  }

  HeatmapCell? cellOn(DateTime day) {
    final spot = positionOf(day);
    return spot == null ? null : columns[spot.week][spot.row];
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Lays [weeks] weeks out, ending with the week of [today]. [counts] gives
/// the logs on each day (days not listed have none); [graceDays] the days a
/// streak carried across.
HeatmapGrid buildHeatmap({
  required Map<DateTime, int> counts,
  required Set<DateTime> graceDays,
  required DateTime today,
  required int weeks,
}) {
  final todayDay = DateTime.utc(today.year, today.month, today.day);
  final start = DateTime.utc(
    todayDay.year,
    todayDay.month,
    todayDay.day - (todayDay.weekday - 1) - 7 * (weeks - 1),
  );
  final columns = <List<HeatmapCell?>>[];
  final labels = <String?>[];
  for (var week = 0; week < weeks; week++) {
    final monday = DateTime.utc(start.year, start.month, start.day + week * 7);
    labels.add(monday.day <= 7 ? _months[monday.month - 1] : null);
    columns.add([
      for (var row = 0; row < 7; row++)
        _cell(
          DateTime.utc(monday.year, monday.month, monday.day + row),
          todayDay,
          counts,
          graceDays,
        ),
    ]);
  }
  return HeatmapGrid._(columns, labels, start, todayDay);
}

HeatmapCell? _cell(
  DateTime day,
  DateTime today,
  Map<DateTime, int> counts,
  Set<DateTime> graceDays,
) {
  if (day.isAfter(today)) return null;
  final count = counts[day] ?? 0;
  return HeatmapCell(
    day: day,
    count: count,
    grace: count == 0 && graceDays.contains(day),
  );
}

/// Where the heatmap's parts sit: weekday labels on the left, month labels
/// above and the square days to the right of those.
class HeatmapLayout {
  const HeatmapLayout({
    required this.weeks,
    required this.cell,
    required this.gap,
  });

  /// Fills [width] when the squares come out at least 6 points wide, as
  /// three and six months do on a phone. A year does not: its squares are
  /// then a fixed 12 points and the heatmap is wider than the screen, to
  /// be scrolled.
  factory HeatmapLayout.forWidth(double width, int weeks) {
    final gap = weeks <= 13 ? 4.0 : 3.0;
    final fit = (width - labelWidth - gap * (weeks - 1)) / weeks;
    if (fit >= 6) return HeatmapLayout(weeks: weeks, cell: fit, gap: gap);
    return HeatmapLayout(weeks: weeks, cell: 12, gap: 3);
  }

  /// Width of the weekday labels, and height of the month labels.
  static const labelWidth = 26.0;
  static const headerHeight = 18.0;

  final int weeks;
  final double cell;
  final double gap;

  double get pitch => cell + gap;

  Size get size => Size(
    labelWidth + weeks * cell + (weeks - 1) * gap,
    headerHeight + 7 * cell + 6 * gap,
  );

  Rect cellRect(int week, int row) => Rect.fromLTWH(
    labelWidth + week * pitch,
    headerHeight + row * pitch,
    cell,
    cell,
  );

  /// The day under [point], counting the gap after a square as part of it
  /// so a finger does not fall between days; null on the labels and
  /// outside.
  HeatmapSpot? cellAt(Offset point) {
    final x = point.dx - labelWidth;
    final y = point.dy - headerHeight;
    if (x < 0 || y < 0) return null;
    final week = math.min((x / pitch).floor(), weeks);
    final row = (y / pitch).floor();
    if (week >= weeks || row >= 7) return null;
    return (week: week, row: row);
  }
}
