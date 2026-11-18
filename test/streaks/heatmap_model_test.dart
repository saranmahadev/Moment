import 'package:flutter_test/flutter_test.dart';
import 'package:moment/streaks/heatmap_model.dart';

void main() {
  // Friday 6 November 2026.
  final today = DateTime.utc(2026, 11, 6);

  group('heatLevel', () {
    test('steps up with the number of logs', () {
      expect([0, 1, 2, 3, 4, 5, 6, 12].map(heatLevel), [
        0,
        1,
        2,
        2,
        3,
        3,
        4,
        4,
      ]);
    });
  });

  group('buildHeatmap', () {
    final grid = buildHeatmap(
      counts: {DateTime.utc(2026, 11, 6): 3, DateTime.utc(2026, 11, 4): 1},
      graceDays: {DateTime.utc(2026, 11, 5), DateTime.utc(2026, 11, 4)},
      today: today,
      weeks: 26,
    );

    test('has a column per week of seven days, Monday first', () {
      expect(grid.columns, hasLength(26));
      expect(grid.columns.every((c) => c.length == 7), isTrue);
      expect(grid.columns.first.first!.day.weekday, DateTime.monday);
    });

    test('ends with the week of today and stops after today', () {
      final last = grid.columns.last;
      expect(last[0]!.day, DateTime.utc(2026, 11, 2));
      expect(last[4]!.day, today);
      expect(last[5], isNull);
      expect(last[6], isNull);
    });

    test('carries the log count and marks forgiven days', () {
      expect(grid.cellOn(today)!.count, 3);
      expect(grid.cellOn(today)!.level, 2);
      expect(grid.cellOn(DateTime.utc(2026, 11, 5))!.grace, isTrue);
      expect(grid.cellOn(DateTime.utc(2026, 11, 5))!.count, 0);
      // A day with logs is never drawn as forgiven.
      expect(grid.cellOn(DateTime.utc(2026, 11, 4))!.grace, isFalse);
      expect(grid.cellOn(DateTime.utc(2026, 11, 3))!.level, 0);
    });

    test('finds a day, and nothing for a day outside it', () {
      expect(grid.positionOf(today), (week: 25, row: 4));
      expect(grid.cellOn(DateTime.utc(2026, 11, 7)), isNull);
      expect(grid.cellOn(DateTime.utc(2025, 1, 1)), isNull);
      expect(grid.positionOf(DateTime.utc(2025, 1, 1)), isNull);
    });

    test('names a month above the week its first Monday falls in', () {
      expect(grid.monthLabels.last, 'Nov');
      // Monday 5 October is four weeks before Monday 2 November.
      expect(grid.monthLabels[21], 'Oct');
      expect(grid.monthLabels[22], isNull);
      expect(grid.monthLabels[23], isNull);
    });

    test('a Monday today leaves one cell in the last column', () {
      final monday = buildHeatmap(
        counts: {},
        graceDays: {},
        today: DateTime.utc(2026, 11, 2),
        weeks: 13,
      );
      expect(monday.columns.last.where((c) => c != null), hasLength(1));
    });
  });

  group('HeatmapLayout', () {
    test('fills a phone for three and six months', () {
      for (final weeks in [13, 26]) {
        final layout = HeatmapLayout.forWidth(322, weeks);
        expect(layout.size.width, closeTo(322, 0.5));
        expect(layout.cell, greaterThanOrEqualTo(6));
      }
    });

    test('a year is wider than the screen and scrolls', () {
      final layout = HeatmapLayout.forWidth(322, 53);
      expect(layout.size.width, greaterThan(322));
      expect(layout.cell, greaterThanOrEqualTo(10));
    });

    test('a point inside a cell finds it, and the gaps and labels do not', () {
      final layout = HeatmapLayout.forWidth(322, 26);
      final rect = layout.cellRect(3, 2);

      expect(layout.cellAt(rect.center), (week: 3, row: 2));
      expect(layout.cellAt(rect.topLeft + const Offset(0.5, 0.5)), (
        week: 3,
        row: 2,
      ));
      expect(layout.cellAt(const Offset(2, 2)), isNull);
      expect(layout.cellAt(Offset(rect.center.dx, -4)), isNull);
      expect(layout.cellAt(Offset(layout.size.width + 4, 40)), isNull);
    });

    test('cells do not overlap and stay inside the size', () {
      final layout = HeatmapLayout.forWidth(322, 26);
      final first = layout.cellRect(0, 0);
      final next = layout.cellRect(1, 0);
      final below = layout.cellRect(0, 1);

      expect(next.left, greaterThan(first.right));
      expect(below.top, greaterThan(first.bottom));
      final last = layout.cellRect(25, 6);
      expect(last.right, lessThanOrEqualTo(layout.size.width + 0.01));
      expect(last.bottom, lessThanOrEqualTo(layout.size.height + 0.01));
    });
  });
}
