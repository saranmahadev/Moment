import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/round_glass_button.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import '../home/type_filter_chips.dart';
import 'calendar_model.dart';

final _monthTitle = DateFormat('MMMM y');
final _dayTitle = DateFormat('EEEE d MMMM');
final _time = DateFormat('HH:mm');
const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String _dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// The Calendar tab: a month of days, each with a dot per type logged on
/// it; tap a day to list its logs. Matches
/// design/mockups/png/23-Calendar.png.
///
/// Days are the ones logs were made on in their own time zone
/// ([Log.localDay]), so nothing moves when the phone changes zone.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.repository,
    DateTime Function()? now,
    this.onOpenLog,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final DateTime Function() now;
  final ValueChanged<Log>? onOpenLog;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  late DateTime _selected;
  LogType? _type;

  DateTime get _today {
    final now = widget.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _selected = _today;
    _month = DateTime.utc(_selected.year, _selected.month);
  }

  void _moveMonth(int by) =>
      setState(() => _month = DateTime.utc(_month.year, _month.month + by));

  void _select(DateTime day) => setState(() {
    _selected = day;
    _month = DateTime.utc(day.year, day.month);
  });

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    final today = _today;
    final awayFromToday =
        _selected != today ||
        _month.year != today.year ||
        _month.month != today.month;

    return StreamBuilder<List<Log>>(
      stream: widget.repository.watchFeed(),
      builder: (context, snapshot) {
        final days = logsByDay(snapshot.data ?? const [], type: _type);
        final dayLogs = days[_selected] ?? const <Log>[];

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _monthTitle.format(_month),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontWeight: FontWeight.w500,
                        fontSize: 34,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                  if (awayFromToday) ...[
                    _TodayButton(tokens: tokens, onTap: () => _select(today)),
                    const SizedBox(width: 8),
                  ],
                  RoundGlassButton(
                    icon: Icons.chevron_left,
                    label: 'Previous month',
                    onTap: () => _moveMonth(-1),
                  ),
                  const SizedBox(width: 8),
                  RoundGlassButton(
                    icon: Icons.chevron_right,
                    label: 'Next month',
                    onTap: () => _moveMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GlassSurface(
                variant: GlassVariant.card,
                borderRadius: 28,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final letter in _weekdays)
                            Expanded(
                              child: Center(
                                child: ExcludeSemantics(
                                  child: Text(
                                    letter,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.secondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      for (var week = 0; week < 6; week++)
                        Row(
                          children: [
                            for (final day in monthGrid(
                              _month.year,
                              _month.month,
                            ).skip(week * 7).take(7))
                              Expanded(
                                child: _DayCell(
                                  day: day,
                                  inMonth: day.month == _month.month,
                                  isToday: day == today,
                                  selected: day == _selected,
                                  logs: days[day] ?? const [],
                                  tokens: tokens,
                                  onTap: () => _select(day),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Wrap(
                  key: const ValueKey('calendar-legend'),
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final type in LogType.values)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Dot(color: tokens.colorFor(type), size: 8),
                          const SizedBox(width: 6),
                          Text(
                            momentLabelFor(type),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: tokens.secondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TypeFilterChips(
                availableTypes: builtLogTypes,
                selected: _type,
                onSelected: (type) => setState(() => _type = type),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '${_dayTitle.format(_selected).toUpperCase()} · '
                  '${dayLogs.length} ${dayLogs.length == 1 ? 'LOG' : 'LOGS'}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: tokens.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (dayLogs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: Text(
                    'Nothing logged on this day.',
                    style: TextStyle(fontSize: 15, color: tokens.secondary),
                  ),
                ),
              for (final log in dayLogs) ...[
                _LogRow(
                  log: log,
                  tokens: tokens,
                  onTap: () => widget.onOpenLog?.call(log),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.tokens, required this.onTap});

  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: GlassSurface(
            variant: GlassVariant.card,
            borderRadius: 22,
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.color, this.size = 5});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.selected,
    required this.logs,
    required this.tokens,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool selected;
  final List<Log> logs;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final types = typesOn(logs);
    final count = logs.isEmpty
        ? 'no logs'
        : '${logs.length} ${logs.length == 1 ? 'log' : 'logs'}';
    final key = _dayKey(day);

    return Semantics(
      key: ValueKey('calendar-day-$key'),
      button: true,
      selected: selected,
      label:
          '${_dayTitle.format(day)}${isToday ? ', today' : ''}, $count'
          '${selected ? ', selected' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: selected ? tokens.ink.withValues(alpha: 0.07) : null,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: tokens.ink, width: 1.5)
                : isToday
                ? Border.all(color: tokens.ink.withValues(alpha: 0.3))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: inMonth
                      ? tokens.ink
                      : tokens.secondary.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 3),
              // Two rows of three, as in the mockup, so six types fit.
              SizedBox(
                height: 13,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    for (final type in types)
                      _Dot(
                        key: ValueKey('calendar-dot-$key-${type.name}'),
                        color: tokens.colorFor(type),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log, required this.tokens, required this.onTap});

  final Log log;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = tokens.colorFor(log.type);

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: GlassSurface(
          variant: GlassVariant.card,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tokens.tintFor(log.type),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(momentIconFor(log.type), size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${momentLabelFor(log.type)} · '
                        '${_time.format(log.localMoment)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      Text(
                        summaryOf(log),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, color: tokens.ink),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: tokens.secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
