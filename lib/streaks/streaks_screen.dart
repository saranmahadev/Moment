import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/round_glass_button.dart';
import '../design/text_growth.dart';
import '../design/tokens.dart';
import '../settings/app_settings.dart';
import 'heatmap_model.dart';
import 'streak_heatmap.dart';
import 'streak_model.dart';

final _selectedFormat = DateFormat('EEE d MMM');
final _weekdayFormat = DateFormat('EEEE d MMMM');
final _milestoneDate = DateFormat('d MMM y');
final _spokenDate = DateFormat('d MMMM y');
final _monthName = DateFormat('MMMM');

/// The Streaks page: the running streak and this week, the longest and the
/// totals, an Activity heatmap and the milestones reached. Everything is
/// worked out here from the days with a log; nothing is stored.
class StreaksScreen extends StatefulWidget {
  const StreaksScreen({
    super.key,
    required this.repository,
    required this.settings,
    DateTime Function()? now,
    required this.onBack,
    required this.onOpenSettings,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final AppSettings settings;
  final DateTime Function() now;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> {
  late final Stream<Map<DateTime, int>> _counts = widget.repository
      .watchDayCounts();

  /// How much of the past the heatmap shows, in months.
  int _months = 6;
  DateTime? _selected;

  DateTime get _today {
    final now = widget.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  int get _weeks => switch (_months) {
    3 => 13,
    6 => 26,
    _ => 53,
  };

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.settings,
              builder: (context, _) => StreamBuilder<Map<DateTime, int>>(
                stream: _counts,
                builder: (context, snapshot) {
                  final counts = snapshot.data;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      _header(tokens),
                      if (counts != null) ..._content(tokens, counts),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(MomentTokens tokens) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        RoundGlassButton(
          icon: Icons.chevron_left,
          label: 'Back',
          onTap: widget.onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: Text(
              'Streaks',
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
        ),
        RoundGlassButton(
          icon: Icons.tune,
          label: 'Streak settings',
          onTap: widget.onOpenSettings,
        ),
      ],
    ),
  );

  List<Widget> _content(MomentTokens tokens, Map<DateTime, int> counts) {
    final today = _today;
    final summary = streakOf(
      counts.keys.toSet(),
      today,
      grace: widget.settings.graceDays,
    );
    final selected = _selected ?? today;
    final monthDays = counts.keys
        .where((d) => d.year == today.year && d.month == today.month)
        .length;

    return [
      _Hero(summary: summary, counts: counts, today: today, tokens: tokens),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Stat(
                key: const ValueKey('streaks-longest'),
                value: '${summary.longest}',
                label: 'Longest streak',
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                key: const ValueKey('streaks-days-logged'),
                value: '${summary.daysLogged}',
                label: 'Days logged',
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                key: const ValueKey('streaks-month-days'),
                value: '$monthDays',
                label: 'Days logged in ${_monthName.format(today)}',
                tokens: tokens,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _activity(tokens, counts, summary, today, selected),
      const SizedBox(height: 12),
      _Milestones(summary: summary, tokens: tokens),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        child: Text(
          'Worked out on this phone from your logs. A day runs midnight to '
          'midnight.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: tokens.secondary,
          ),
        ),
      ),
    ];
  }

  Widget _activity(
    MomentTokens tokens,
    Map<DateTime, int> counts,
    StreakSummary summary,
    DateTime today,
    DateTime selected,
  ) {
    final grid = buildHeatmap(
      counts: counts,
      graceDays: summary.graceDays,
      today: today,
      weeks: _weeks,
    );
    final cell = grid.cellOn(selected);

    return GlassSurface(
      variant: GlassVariant.card,
      borderRadius: 26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Activity',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                ),
                for (final (months, label) in const [
                  (3, '3 mo'),
                  (6, '6 mo'),
                  (12, 'Year'),
                ])
                  _RangeButton(
                    key: ValueKey('streaks-range-$months'),
                    label: label,
                    spoken: months == 12 ? 'A year' : '$months months',
                    selected: _months == months,
                    tokens: tokens,
                    onTap: () => setState(() => _months = months),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, box) {
                final layout = HeatmapLayout.forWidth(box.maxWidth, _weeks);
                final heatmap = StreakHeatmap(
                  grid: grid,
                  layout: layout,
                  selected: selected,
                  onSelect: (day) => setState(() => _selected = day),
                );
                if (layout.size.width <= box.maxWidth + 0.5) return heatmap;
                // A year is wider than the card: scroll it, newest in view.
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: heatmap,
                );
              },
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                key: const ValueKey('streaks-selected-day'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedFormat.format(selected),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cell == null
                          ? ''
                          : cell.count > 0
                          ? '· ${cell.count} ${cell.count == 1 ? 'log' : 'logs'}'
                          : cell.grace
                          ? '· Grace day. No logs, streak kept.'
                          : '· No logs',
                      style: TextStyle(fontSize: 13.5, color: tokens.secondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Fewer',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.secondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _Swatch(tokens.ink.withValues(alpha: 0.07)),
                      for (final color in tokens.streakRamp) _Swatch(color),
                      const SizedBox(width: 6),
                      Text(
                        'More',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.secondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: tokens.secondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Grace day',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 3),
    child: Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

/// One of the 3 mo, 6 mo and Year choices. The pill is smaller than the
/// 44-point area that can be tapped.
class _RangeButton extends StatelessWidget {
  const _RangeButton({
    super.key,
    required this.label,
    required this.spoken,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final String spoken;
  final bool selected;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? tokens.ink : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? tokens.onInk : tokens.ink,
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.summary,
    required this.counts,
    required this.today,
    required this.tokens,
  });

  final StreakSummary summary;
  final Map<DateTime, int> counts;
  final DateTime today;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final used = summary.graceDaysUsed;
    final logged = summary.current - used;
    final subtitle = summary.current == 0
        ? 'Log anything today to start one.'
        : '$logged ${logged == 1 ? 'day' : 'days'} logged'
              '${used > 0 ? ' · $used grace ${used == 1 ? 'day' : 'days'} used' : ''}';
    final monday = DateTime.utc(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );

    return GlassSurface(
      variant: GlassVariant.card,
      borderRadius: 26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              children: [
                KeyedSubtree(
                  key: const ValueKey('streaks-count'),
                  child: Text(
                    '${summary.current}',
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontWeight: FontWeight.w500,
                      fontSize: 84,
                      height: 1,
                      color: tokens.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'day streak',
                    style: TextStyle(fontSize: 20, color: tokens.secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13.5, color: tokens.secondary),
            ),
            if (summary.current > 0) ...[
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: summary.loggedToday
                      ? tokens.ink.withValues(alpha: 0.08)
                      : tokens.highlight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (summary.loggedToday) ...[
                        Icon(Icons.check, size: 16, color: tokens.ink),
                        const SizedBox(width: 6),
                      ] else
                        const SizedBox(width: 3),
                      Text(
                        summary.loggedToday
                            ? 'Logged today'
                            : 'Not logged yet today',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _WeekDay(
                      day: DateTime.utc(
                        monday.year,
                        monday.month,
                        monday.day + i,
                      ),
                      today: today,
                      logged: counts.containsKey(
                        DateTime.utc(monday.year, monday.month, monday.day + i),
                      ),
                      grace: summary.graceDays.contains(
                        DateTime.utc(monday.year, monday.month, monday.day + i),
                      ),
                      tokens: tokens,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.day,
    required this.today,
    required this.logged,
    required this.grace,
    required this.tokens,
  });

  final DateTime day;
  final DateTime today;
  final bool logged;
  final bool grace;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final future = day.isAfter(today);
    final isToday = day == today;
    final state = future
        ? 'not yet'
        : logged
        ? 'logged'
        : grace
        ? 'grace day'
        : 'no logs';

    return Semantics(
      container: true,
      label: '${_weekdayFormat.format(day)}, ${isToday ? 'today, ' : ''}$state',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: logged ? tokens.ink : tokens.ink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
              border: grace && !logged
                  ? Border.all(
                      color: tokens.secondary.withValues(alpha: 0.8),
                      width: 1.5,
                    )
                  : isToday
                  ? Border.all(color: tokens.streakAccent, width: 2)
                  : null,
            ),
            child: logged
                ? Icon(Icons.check, size: 17, color: tokens.onInk)
                : null,
          ),
          const SizedBox(height: 5),
          Text(
            'MTWTFSS'[day.weekday - 1],
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tokens.secondary.withValues(alpha: future ? 0.6 : 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.value,
    required this.label,
    required this.tokens,
  });

  final String value;
  final String label;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      variant: GlassVariant.card,
      borderRadius: 22,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontWeight: FontWeight.w500,
                fontSize: 30,
                height: 1.1,
                color: tokens.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                color: tokens.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Milestones extends StatelessWidget {
  const _Milestones({required this.summary, required this.tokens});

  final StreakSummary summary;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final reached = summary.milestones.where((m) => m.reachedOn != null).length;
    final next = summary.milestones.indexWhere((m) => m.reachedOn == null);

    return GlassSurface(
      variant: GlassVariant.card,
      borderRadius: 26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    'Milestones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$reached of ${summary.milestones.length}',
                    style: TextStyle(fontSize: 12.5, color: tokens.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = row * 4; i < row * 4 + 4; i++)
                    Expanded(
                      child: _MilestoneTile(
                        milestone: summary.milestones[i],
                        isNext: i == next,
                        best: summary.longest,
                        tokens: tokens,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.milestone,
    required this.isNext,
    required this.best,
    required this.tokens,
  });

  final StreakMilestone milestone;
  final bool isNext;
  final int best;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    final days = milestone.days;
    final date = milestone.reachedOn;
    final label = date != null
        ? 'Milestone $days days, reached ${_spokenDate.format(date)}'
        : isNext
        ? 'Milestone $days days, not yet, best so far $best'
        : 'Milestone $days days, not yet';
    final size = 58 + extraTextHeight(context, 21);

    final badge = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BadgePainter(
          tokens: tokens,
          reached: date != null,
          progress: isNext ? math.min(1, best / days) : null,
        ),
        child: Center(
          child: Text(
            '$days',
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontWeight: FontWeight.w500,
              fontSize: 21,
              color: date != null
                  ? tokens.ink
                  : tokens.secondary.withValues(alpha: isNext ? 1 : 0.7),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      key: ValueKey('milestone-$days'),
      container: true,
      label: label,
      excludeSemantics: true,
      // Kept for the tests and for the text below: the visible words are
      // not read twice because the node above hides them.
      child: Column(
        children: [
          badge,
          const SizedBox(height: 6),
          Text(
            '$days days',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: date != null ? tokens.ink : tokens.secondary,
            ),
          ),
          Text(
            date != null
                ? _milestoneDate.format(date)
                : isNext
                ? 'Best so far $best'
                : 'Not yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              color: tokens.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter({
    required this.tokens,
    required this.reached,
    required this.progress,
  });

  final MomentTokens tokens;
  final bool reached;

  /// 0 to 1 for the next milestone's ring; null for the others.
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = size.shortestSide / 2;
    if (reached) {
      final orb = tokens.orbs[0];
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: orb,
          ).createShader(rect),
      );
      canvas.drawCircle(
        centre,
        radius - 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = tokens.ink.withValues(alpha: 0.12),
      );
    } else if (progress != null) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = tokens.ink.withValues(alpha: 0.06),
      );
      final ring = Rect.fromCircle(center: centre, radius: radius - 1.5);
      canvas.drawCircle(
        centre,
        radius - 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = tokens.ink.withValues(alpha: 0.1),
      );
      canvas.drawArc(
        ring,
        -math.pi / 2,
        2 * math.pi * progress!,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = tokens.streakAccent,
      );
    } else {
      canvas.drawCircle(
        centre,
        radius - 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = tokens.ink.withValues(alpha: 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.reached != reached ||
      old.progress != progress ||
      old.tokens != tokens;
}
