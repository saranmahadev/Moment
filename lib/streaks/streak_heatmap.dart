import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/tokens.dart';
import 'heatmap_model.dart';

final _spoken = DateFormat('EEEE d MMMM');

/// What a screen reader says for a day on the heatmap.
String describeHeatmapDay(HeatmapCell cell) {
  final what = cell.count > 0
      ? '${cell.count} ${cell.count == 1 ? 'log' : 'logs'}'
      : cell.grace
      ? 'grace day'
      : 'no logs';
  return '${_spoken.format(cell.day)}, $what';
}

/// The Activity heatmap: a square a day, a column a week, shaded by how
/// many logs the day holds, with forgiven days outlined.
///
/// It is one surface, not a few hundred buttons: a tap or a drag picks the
/// day under the finger, and a screen reader gets a single slider that
/// steps a day at a time.
class StreakHeatmap extends StatelessWidget {
  const StreakHeatmap({
    super.key,
    required this.grid,
    required this.layout,
    required this.selected,
    required this.onSelect,
  });

  final HeatmapGrid grid;
  final HeatmapLayout layout;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  void _pick(Offset at) {
    final spot = layout.cellAt(at);
    final cell = spot == null ? null : grid.columns[spot.week][spot.row];
    if (cell != null && cell.day != selected) onSelect(cell.day);
  }

  void _step(int days) {
    final day = DateTime.utc(
      selected.year,
      selected.month,
      selected.day + days,
    );
    if (grid.cellOn(day) != null) onSelect(day);
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final current = grid.cellOn(selected);
    final before = grid.cellOn(
      DateTime.utc(selected.year, selected.month, selected.day - 1),
    );
    final after = grid.cellOn(
      DateTime.utc(selected.year, selected.month, selected.day + 1),
    );

    return Semantics(
      container: true,
      label: 'Activity',
      value: current == null ? null : describeHeatmapDay(current),
      slider: true,
      increasedValue: after == null ? null : describeHeatmapDay(after),
      decreasedValue: before == null ? null : describeHeatmapDay(before),
      onIncrease: after == null ? null : () => _step(1),
      onDecrease: before == null ? null : () => _step(-1),
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (details) => _pick(details.localPosition),
        onPanUpdate: (details) => _pick(details.localPosition),
        child: SizedBox(
          key: const ValueKey('streaks-heatmap'),
          width: layout.size.width,
          height: layout.size.height,
          child: CustomPaint(
            painter: _HeatmapPainter(
              grid: grid,
              layout: layout,
              tokens: tokens,
              selected: selected,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.grid,
    required this.layout,
    required this.tokens,
    required this.selected,
  });

  final HeatmapGrid grid;
  final HeatmapLayout layout;
  final MomentTokens tokens;
  final DateTime selected;

  void _label(Canvas canvas, String text, Offset at, {bool centred = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10.5,
          color: tokens.secondary,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, centred ? at - Offset(0, painter.height / 2) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var week = 0; week < layout.weeks; week++) {
      final month = grid.monthLabels[week];
      if (month != null) {
        _label(canvas, month, Offset(layout.cellRect(week, 0).left, 1));
      }
    }
    for (final row in [0, 2, 4]) {
      final rect = layout.cellRect(0, row);
      _label(canvas, 'MTWTFSS'[row], Offset(0, rect.center.dy), centred: true);
    }

    final radius = Radius.circular(layout.cell < 10 ? 2 : 3);
    for (var week = 0; week < layout.weeks; week++) {
      for (var row = 0; row < 7; row++) {
        final cell = grid.columns[week][row];
        if (cell == null) continue;
        final rect = RRect.fromRectAndRadius(
          layout.cellRect(week, row),
          radius,
        );
        if (cell.grace) {
          canvas.drawRRect(
            rect.deflate(0.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = tokens.secondary.withValues(alpha: 0.8),
          );
        } else {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = cell.level == 0
                  ? tokens.ink.withValues(alpha: 0.07)
                  : tokens.streakRamp[cell.level - 1],
          );
        }
      }
    }

    final spot = grid.positionOf(selected);
    if (spot != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          layout.cellRect(spot.week, spot.row),
          radius,
        ).inflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = tokens.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.grid != grid ||
      old.layout.cell != layout.cell ||
      old.tokens != tokens ||
      old.selected != selected;
}
