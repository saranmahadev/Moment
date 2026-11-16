import '../domain/log.dart';
import '../domain/log_type.dart';
import '../location/coordinates.dart';
import '../video/video_poster.dart';

/// The 42 days a month view shows: six weeks starting on the Monday on or
/// before the 1st. Days are UTC midnights, the same form as
/// [Log.localDay], so the two compare directly and no daylight-saving
/// change can make a day 23 or 25 hours long.
List<DateTime> monthGrid(int year, int month) {
  final first = DateTime.utc(year, month);
  final start = first.subtract(Duration(days: first.weekday - 1));
  return [for (var i = 0; i < 42; i++) start.add(Duration(days: i))];
}

/// Groups [logs] by the calendar day each was made on, in the time zone it
/// was made in ([Log.localDay]): the device's current zone plays no part,
/// so a log made at 23:50 stays on its day after travelling. Order within
/// a day is kept as given. With [type], only logs of that type.
Map<DateTime, List<Log>> logsByDay(Iterable<Log> logs, {LogType? type}) {
  final days = <DateTime, List<Log>>{};
  for (final log in logs) {
    if (type != null && log.type != type) continue;
    days.putIfAbsent(log.localDay, () => []).add(log);
  }
  return days;
}

/// The types present in [logs], once each, in the app's type order.
List<LogType> typesOn(Iterable<Log> logs) {
  final present = {for (final log in logs) log.type};
  return [
    for (final type in LogType.values)
      if (present.contains(type)) type,
  ];
}

/// One line saying what a log holds, for compact lists.
String summaryOf(Log log) => switch (log) {
  TextLog(:final body) => body.replaceAll(RegExp(r'\s+'), ' ').trim(),
  EmojiLog(:final emoji, :final label, :final strength) =>
    '${label ?? emoji} · strength $strength of 5',
  PhotoLog(:final caption) => _or(caption, 'Photo'),
  AudioLog(:final title, :final duration) =>
    '${_or(title, 'Voice note')} · ${formatClipLength(duration)}',
  VideoLog(:final caption, :final duration) =>
    '${_or(caption, 'Video')} · ${formatClipLength(duration)}',
  LocationLog(:final name, :final latitude, :final longitude) => _or(
    name,
    formatCoordinates(latitude, longitude),
  ),
};

String _or(String? text, String fallback) =>
    text == null || text.trim().isEmpty ? fallback : text.trim();
