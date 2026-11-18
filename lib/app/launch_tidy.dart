import '../data/log_repository.dart';

/// Housekeeping run once each launch, after the journal opens: logs that
/// have been in Trash for more than 30 days are deleted, with their files.
Future<void> tidyAtLaunch(LogRepository repository, {required DateTime now}) =>
    repository.purgeExpired(now);
