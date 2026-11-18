import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/tokens.dart';

import '../domain/log.dart';

/// One month's logs, in the order they were given, under its heading.
class MonthGroup {
  const MonthGroup(this.label, this.logs);

  /// "NOVEMBER 2026".
  final String label;
  final List<Log> logs;
}

final _monthFormat = DateFormat('MMMM yyyy');

/// Splits [logs] into runs of the same month, keeping their order (newest
/// or oldest first, as given). A log's month is the one it was made in,
/// in its own time zone, as [Log.localDay] is.
List<MonthGroup> groupByMonth(List<Log> logs) {
  final groups = <MonthGroup>[];
  DateTime? current;
  for (final log in logs) {
    final day = log.localDay;
    final month = DateTime.utc(day.year, day.month);
    if (month != current) {
      current = month;
      groups.add(MonthGroup(_monthFormat.format(month).toUpperCase(), []));
    }
    groups.last.logs.add(log);
  }
  return groups;
}

/// A month's heading above its part of a grid, as a sliver.
class MonthHeading extends StatelessWidget {
  const MonthHeading(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 4, 20, 10),
      sliver: SliverToBoxAdapter(
        child: Semantics(
          header: true,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.96,
              color: tokens.secondary,
            ),
          ),
        ),
      ),
    );
  }
}
