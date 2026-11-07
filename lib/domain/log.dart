import 'log_type.dart';

/// A single moment recorded in the journal. One of [TextLog] or [EmojiLog]
/// for now; the remaining four types are added in later phases.
sealed class Log {
  const Log({
    required this.id,
    required this.createdAt,
    required this.tzOffsetMinutes,
    required this.editedAt,
    required this.deletedAt,
  });

  /// Stable identifier, a UUID.
  final String id;

  /// The instant this log was made, in UTC.
  final DateTime createdAt;

  /// The device's time zone offset from UTC, in minutes, at the moment of
  /// creation. Recorded rather than recomputed so the log's day never moves
  /// when the device later changes time zone.
  final int tzOffsetMinutes;

  /// When this log's content was last edited, if ever.
  final DateTime? editedAt;

  /// When this log was moved to Trash, if it has been.
  final DateTime? deletedAt;

  LogType get type;

  /// [createdAt] shifted by the offset recorded at creation: the wall-clock
  /// time the log was made at, wherever that was.
  DateTime get localMoment => createdAt.add(Duration(minutes: tzOffsetMinutes));

  /// The calendar day this log belongs to, in the time zone it was made in.
  /// A log made at 23:50 keeps this day even after the device travels to a
  /// different time zone, because it is derived from the recorded offset,
  /// never the device's current one.
  DateTime get localDay {
    final local = localMoment;
    return DateTime.utc(local.year, local.month, local.day);
  }
}

/// A free-form written entry.
final class TextLog extends Log {
  const TextLog({
    required super.id,
    required super.createdAt,
    required super.tzOffsetMinutes,
    required super.editedAt,
    required super.deletedAt,
    required this.body,
  });

  final String body;

  @override
  LogType get type => LogType.text;
}

/// A photo, stored EXIF-stripped with a thumbnail, and an optional caption.
final class PhotoLog extends Log {
  const PhotoLog({
    required super.id,
    required super.createdAt,
    required super.tzOffsetMinutes,
    required super.editedAt,
    required super.deletedAt,
    required this.path,
    required this.thumbnailPath,
    required this.caption,
  });

  /// Path to the EXIF-stripped photo file, under this app's private media
  /// directory.
  final String path;

  /// Path to the thumbnail generated alongside [path].
  final String thumbnailPath;

  final String? caption;

  @override
  LogType get type => LogType.photo;
}

/// A one-tap mood entry: an emoji, an optional label and a strength from 1
/// to 5.
final class EmojiLog extends Log {
  const EmojiLog({
    required super.id,
    required super.createdAt,
    required super.tzOffsetMinutes,
    required super.editedAt,
    required super.deletedAt,
    required this.emoji,
    required this.label,
    required this.strength,
  });

  final String emoji;
  final String? label;
  final int strength;

  @override
  LogType get type => LogType.emoji;
}
