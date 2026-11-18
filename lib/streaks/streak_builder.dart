import 'package:flutter/widgets.dart';

import '../data/log_repository.dart';
import '../settings/app_settings.dart';
import 'streak_model.dart';

/// Hands [builder] the streaks as they stand: worked out from the days with
/// a log, and worked out again whenever a log or the grace setting changes.
/// The summary is null while the days load, when there are no [settings]
/// to read, and when the owner has turned streaks off, so a screen only has
/// to draw nothing for null.
class StreakBuilder extends StatefulWidget {
  const StreakBuilder({
    super.key,
    required this.repository,
    required this.settings,
    required this.now,
    required this.builder,
  });

  final LogRepository repository;
  final AppSettings? settings;
  final DateTime Function() now;
  final Widget Function(BuildContext context, StreakSummary? summary) builder;

  @override
  State<StreakBuilder> createState() => _StreakBuilderState();
}

class _StreakBuilderState extends State<StreakBuilder> {
  late final Stream<Set<DateTime>> _days = widget.repository.watchActiveDays();

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    if (settings == null) return widget.builder(context, null);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        if (!settings.showStreaks) return widget.builder(context, null);
        return StreamBuilder<Set<DateTime>>(
          stream: _days,
          builder: (context, snapshot) {
            final days = snapshot.data;
            if (days == null) return widget.builder(context, null);
            final now = widget.now();
            return widget.builder(
              context,
              streakOf(
                days,
                DateTime.utc(now.year, now.month, now.day),
                grace: settings.graceDays,
              ),
            );
          },
        );
      },
    );
  }
}
