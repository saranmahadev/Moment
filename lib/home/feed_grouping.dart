import 'package:intl/intl.dart';

import '../domain/log.dart';

/// One day's worth of consecutive feed entries, with the header Home shows
/// above them.
class FeedSection {
  const FeedSection({required this.label, required this.logs});

  final String label;
  final List<Log> logs;
}

final _dayFormat = DateFormat('EEE d MMM');

/// Groups [logs] (assumed already sorted newest first, as
/// `LogRepository.watchFeed` returns them) into one [FeedSection] per
/// calendar day, using each log's recorded [Log.localDay] rather than the
/// device's current time zone. [now] is the current moment, used only to
/// recognise today and yesterday.
List<FeedSection> groupFeedByDay(List<Log> logs, {required DateTime now}) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final sections = <FeedSection>[];
  DateTime? currentDay;
  List<Log>? currentLogs;

  for (final log in logs) {
    final day = log.localDay;
    if (currentDay == day) {
      currentLogs!.add(log);
      continue;
    }
    currentDay = day;
    currentLogs = [log];
    sections.add(
      FeedSection(label: _labelFor(day, today, yesterday), logs: currentLogs),
    );
  }
  return sections;
}

String _labelFor(DateTime day, DateTime today, DateTime yesterday) {
  final date = _dayFormat.format(day).toUpperCase();
  if (day == today) return 'TODAY · $date';
  if (day == yesterday) return 'YESTERDAY · $date';
  return date;
}
