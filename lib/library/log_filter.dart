import 'package:flutter/foundation.dart';

import '../domain/log.dart';
import '../domain/log_type.dart';

/// How far back a filter reaches. Days are the local days logs were made
/// on, so travel and daylight saving move nothing.
enum FilterWindow {
  allTime('All time'),
  today('Today'),
  last7('Last 7 days'),
  last30('Last 30 days'),
  thisYear('This year');

  const FilterWindow(this.label);

  final String label;
}

/// What the Library's filter popup chooses for one type: when, which order,
/// and the choices that only some types have. It only decides what is
/// shown; nothing is changed or hidden in the journal. Kept in memory, so it
/// resets when the app closes.
@immutable
class LogFilter {
  const LogFilter({
    this.window = FilterWindow.allTime,
    this.oldestFirst = false,
    this.strengths = const {},
    this.onlyNamed = false,
  });

  final FilterWindow window;
  final bool oldestFirst;

  /// Emoji only: which strengths (1 to 5) to keep; empty means any.
  final Set<int> strengths;

  /// Photo and video with a caption, audio with a title, location with a
  /// name. Text and emoji have none, so it leaves them alone.
  final bool onlyNamed;

  /// How many choices differ from the default.
  int get activeCount =>
      (window != FilterWindow.allTime ? 1 : 0) +
      (oldestFirst ? 1 : 0) +
      (strengths.isNotEmpty ? 1 : 0) +
      (onlyNamed ? 1 : 0);

  bool get isActive => activeCount > 0;

  LogFilter copyWith({
    FilterWindow? window,
    bool? oldestFirst,
    Set<int>? strengths,
    bool? onlyNamed,
  }) => LogFilter(
    window: window ?? this.window,
    oldestFirst: oldestFirst ?? this.oldestFirst,
    strengths: strengths ?? this.strengths,
    onlyNamed: onlyNamed ?? this.onlyNamed,
  );

  bool _inWindow(Log log, DateTime today) {
    final day = log.localDay;
    return switch (window) {
      FilterWindow.allTime => true,
      FilterWindow.today => day == today,
      FilterWindow.last7 => !day.isBefore(
        today.subtract(const Duration(days: 6)),
      ),
      FilterWindow.last30 => !day.isBefore(
        today.subtract(const Duration(days: 29)),
      ),
      FilterWindow.thisYear => day.year == today.year,
    };
  }

  bool _named(String? value) => value != null && value.trim().isNotEmpty;

  bool _matches(Log log, DateTime today) {
    if (!_inWindow(log, today)) return false;
    return switch (log) {
      EmojiLog() => strengths.isEmpty || strengths.contains(log.strength),
      PhotoLog() => !onlyNamed || _named(log.caption),
      VideoLog() => !onlyNamed || _named(log.caption),
      AudioLog() => !onlyNamed || _named(log.title),
      LocationLog() => !onlyNamed || _named(log.name),
      TextLog() => true,
    };
  }

  /// [logs] (newest first, as the repository returns them) kept and ordered
  /// by this filter. [today] is the local day now, as UTC midnight.
  List<Log> apply(List<Log> logs, {required DateTime today}) {
    final kept = [
      for (final log in logs)
        if (_matches(log, today)) log,
    ];
    return oldestFirst ? kept.reversed.toList() : kept;
  }

  @override
  bool operator ==(Object other) =>
      other is LogFilter &&
      other.window == window &&
      other.oldestFirst == oldestFirst &&
      other.onlyNamed == onlyNamed &&
      setEquals(other.strengths, strengths);

  @override
  int get hashCode => Object.hash(
    window,
    oldestFirst,
    onlyNamed,
    Object.hashAllUnordered(strengths),
  );
}

/// The filters in force, one per type. In memory: they reset with the app.
class LibraryFilters extends ChangeNotifier {
  final _filters = <LogType, LogFilter>{};

  LogFilter of(LogType type) => _filters[type] ?? const LogFilter();

  Map<LogType, LogFilter> get all => Map.unmodifiable(_filters);

  void set(LogType type, LogFilter filter) {
    if (filter.isActive) {
      _filters[type] = filter;
    } else {
      _filters.remove(type);
    }
    notifyListeners();
  }

  void clear(LogType type) => set(type, const LogFilter());
}
