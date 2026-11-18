import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../domain/log_type.dart';
import 'streak_model.dart';

/// The streak on Home, beside Search: a flame and the day count.
///
/// Logged today it is a solid ink pill. With nothing logged yet it is an
/// outlined pill with a dashed edge and a small amber dot, all day and
/// without any change of tone at night. When yesterday was missed and
/// forgiven it says Grace. With no streak it is not drawn at all, so a
/// broken streak leaves nothing behind.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.summary, this.onTap});

  final StreakSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (summary.current == 0) return const SizedBox.shrink();
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final count = summary.current;
    final done = summary.loggedToday;
    final grace = summary.inGraceDay;
    final label =
        '$count-day streak, '
        '${done
            ? 'logged today'
            : grace
            ? 'grace day in use'
            : 'nothing logged yet today'}';
    final color = done ? tokens.onInk : tokens.ink;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(11, 0, 14, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done
                ? Icons.local_fire_department
                : Icons.local_fire_department_outlined,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (!done && !grace) ...[
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: tokens.colorFor(LogType.emoji),
                shape: BoxShape.circle,
              ),
            ),
          ],
          if (grace) ...[
            const SizedBox(width: 6),
            Text(
              'Grace',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: tokens.secondary,
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('streak-chip'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: done
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.ink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(widthFactor: 1, child: content),
                )
              : CustomPaint(
                  foregroundPainter: _DashedPill(tokens.secondary),
                  child: GlassSurface(
                    variant: GlassVariant.card,
                    borderRadius: 22,
                    child: Center(widthFactor: 1, child: content),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A pill-shaped outline of short dashes.
class _DashedPill extends CustomPainter {
  const _DashedPill(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          Radius.circular(size.height / 2),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    for (final PathMetric metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 7) {
        canvas.drawPath(metric.extractPath(at, at + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPill old) => old.color != color;
}
