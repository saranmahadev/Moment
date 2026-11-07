import 'package:drift/drift.dart';

/// One row per log, of any type. Type-specific content lives in that type's
/// own table (e.g. [TextLogsTable]), joined on [id].
@DataClassName('LogRow')
class LogsTable extends Table {
  @override
  String get tableName => 'log';

  TextColumn get id => text()();

  /// A [LogType.name](../domain/log_type.dart) value.
  TextColumn get type => text()();

  /// UTC epoch milliseconds.
  IntColumn get createdAtMs => integer().named('created_at_ms')();

  /// The device's time zone offset from UTC, in minutes, recorded at
  /// creation so the log's calendar day never moves.
  IntColumn get tzOffsetMinutes => integer().named('tz_offset_minutes')();

  /// UTC epoch milliseconds of the last edit, if any.
  IntColumn get editedAtMs => integer().named('edited_at_ms').nullable()();

  /// UTC epoch milliseconds the log was moved to Trash, if it has been.
  IntColumn get deletedAtMs => integer().named('deleted_at_ms').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The body of a text log. One row per [LogsTable] row of type `text`.
@DataClassName('TextLogRow')
class TextLogsTable extends Table {
  @override
  String get tableName => 'text_log';

  TextColumn get logId => text()
      .named('log_id')
      .references(LogsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get body => text()();

  @override
  Set<Column> get primaryKey => {logId};
}

/// The emoji, optional label and strength of a mood log. One row per
/// [LogsTable] row of type `emoji`.
@DataClassName('EmojiLogRow')
class EmojiLogsTable extends Table {
  @override
  String get tableName => 'emoji_log';

  TextColumn get logId => text()
      .named('log_id')
      .references(LogsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get emoji => text()();
  TextColumn get label => text().nullable()();

  /// 1 (lowest) to 5 (highest).
  IntColumn get strength => integer()();

  @override
  Set<Column> get primaryKey => {logId};
}

/// The stored file paths and caption of a photo log. One row per
/// [LogsTable] row of type `photo`. Added in schema version 2.
@DataClassName('PhotoLogRow')
class PhotoLogsTable extends Table {
  @override
  String get tableName => 'photo_log';

  TextColumn get logId => text()
      .named('log_id')
      .references(LogsTable, #id, onDelete: KeyAction.cascade)();

  /// Path to the EXIF-stripped photo file, under this app's private media
  /// directory.
  TextColumn get path => text()();

  /// Path to the thumbnail generated alongside [path].
  TextColumn get thumbnailPath => text().named('thumbnail_path')();

  TextColumn get caption => text().nullable()();

  @override
  Set<Column> get primaryKey => {logId};
}

/// The stored file, waveform, title and note of an audio log. One row per
/// [LogsTable] row of type `audio`. Added in schema version 3.
@DataClassName('AudioLogRow')
class AudioLogsTable extends Table {
  @override
  String get tableName => 'audio_log';

  TextColumn get logId => text()
      .named('log_id')
      .references(LogsTable, #id, onDelete: KeyAction.cascade)();

  /// Path to the recorded audio file, under this app's private media
  /// directory.
  TextColumn get path => text()();

  IntColumn get durationMs => integer().named('duration_ms')();

  /// Normalized (0.0 to 1.0) amplitude samples, JSON-encoded as a list of
  /// numbers.
  TextColumn get peaks => text()();

  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {logId};
}
