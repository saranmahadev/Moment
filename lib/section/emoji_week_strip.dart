import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/glass_surface.dart';
import '../design/text_growth.dart';
import '../design/tokens.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';

/// One day of the week strip: the day, and the last emoji logged on it.
class WeekDay {
  const WeekDay(this.day, this.emoji);

  /// UTC midnight, as [Log.localDay].
  final DateTime day;
  final String? emoji;
}

/// Monday to Sunday of the week [today] is in, each with the emoji logged
/// last that day (by the time it was logged, whichever order [logs] are
/// in), or none.
List<WeekDay> weekOfEmoji(List<Log> logs, {required DateTime today}) {
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final latest = <DateTime, EmojiLog>{};
  for (final log in logs.whereType<EmojiLog>()) {
    final day = log.localDay;
    final index = day.difference(monday).inDays;
    if (index < 0 || index > 6) continue;
    final kept = latest[day];
    if (kept == null || log.createdAt.isAfter(kept.createdAt)) {
      latest[day] = log;
    }
  }
  return [
    for (var i = 0; i < 7; i++)
      WeekDay(
        monday.add(Duration(days: i)),
        latest[monday.add(Duration(days: i))]?.emoji,
      ),
  ];
}

final _short = DateFormat('EEE');
final _long = DateFormat('EEEE');

/// "This week" above the Emoji section: the week's moods at a glance,
/// today outlined in the Emoji colour. Read by a screen reader as one
/// sentence.
class EmojiWeekStrip extends StatelessWidget {
  const EmojiWeekStrip({super.key, required this.week, required this.today});

  final List<WeekDay> week;
  final DateTime today;

  String get _spoken {
    final days = [
      for (final d in week)
        if (d.emoji != null)
          '${_long.format(d.day)}${d.day == today ? ', today' : ''}: '
              '${d.emoji}',
    ];
    return days.isEmpty
        ? 'This week. Nothing logged yet.'
        : 'This week. ${days.join('. ')}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    return Semantics(
      container: true,
      label: _spoken,
      excludeSemantics: true,
      child: GlassSurface(
        variant: GlassVariant.surface,
        borderRadius: 26,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  'THIS WEEK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.96,
                    color: tokens.secondary,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final d in week)
                    Expanded(
                      child: Container(
                        // Grows with the system text size.
                        height: 74 * textGrowth(context),
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: d.day == today
                              ? tokens.tintFor(LogType.emoji)
                              : null,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            width: 1.5,
                            color: d.day == today
                                ? tokens.colorFor(LogType.emoji)
                                : tokens.ground.withValues(alpha: 0),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _short.format(d.day),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.secondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 26 * textGrowth(context),
                              child: Text(
                                d.emoji ?? '',
                                style: const TextStyle(
                                  fontSize: 24,
                                  height: 1.05,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
