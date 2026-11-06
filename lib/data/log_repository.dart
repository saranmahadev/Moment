import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/log.dart';
import '../domain/log_type.dart';
import 'database.dart';

/// Returns the current moment. Injected so tests can control time.
typedef Clock = DateTime Function();

/// Returns a new unique id. Injected so tests can control identity.
typedef IdGenerator = String Function();

String _defaultId() => const Uuid().v4();

/// Reads and writes every log type through one local database.
///
/// A [Clock] and an [IdGenerator] are injected instead of depending directly
/// on [DateTime.now] and random UUIDs, so tests can control both.
class LogRepository {
  LogRepository(
    this._db, {
    Clock clock = DateTime.now,
    IdGenerator generateId = _defaultId,
  }) : _clock = clock,
       _generateId = generateId;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _generateId;

  /// Creates a text log and returns its id.
  ///
  /// [body] must not be blank. [createdAt] backdates the log; it defaults
  /// to now.
  Future<String> createText({required String body, DateTime? createdAt}) async {
    if (body.trim().isEmpty) {
      throw ArgumentError.value(body, 'body', 'must not be blank');
    }

    final id = _generateId();
    final at = createdAt ?? _clock();
    await _db.transaction(() async {
      await _db
          .into(_db.logsTable)
          .insert(
            LogsTableCompanion.insert(
              id: id,
              type: LogType.text.name,
              createdAtMs: at.toUtc().millisecondsSinceEpoch,
              tzOffsetMinutes: at.timeZoneOffset.inMinutes,
            ),
          );
      await _db
          .into(_db.textLogsTable)
          .insert(TextLogsTableCompanion.insert(logId: id, body: body));
    });
    return id;
  }

  /// Creates an emoji log and returns its id.
  ///
  /// [emoji] must not be empty and [strength] must be 1 to 5. [createdAt]
  /// backdates the log; it defaults to now.
  Future<String> createEmoji({
    required String emoji,
    String? label,
    required int strength,
    DateTime? createdAt,
  }) async {
    if (emoji.isEmpty) {
      throw ArgumentError.value(emoji, 'emoji', 'must not be empty');
    }
    if (strength < 1 || strength > 5) {
      throw ArgumentError.value(strength, 'strength', 'must be 1 to 5');
    }

    final id = _generateId();
    final at = createdAt ?? _clock();
    await _db.transaction(() async {
      await _db
          .into(_db.logsTable)
          .insert(
            LogsTableCompanion.insert(
              id: id,
              type: LogType.emoji.name,
              createdAtMs: at.toUtc().millisecondsSinceEpoch,
              tzOffsetMinutes: at.timeZoneOffset.inMinutes,
            ),
          );
      await _db
          .into(_db.emojiLogsTable)
          .insert(
            EmojiLogsTableCompanion.insert(
              logId: id,
              emoji: emoji,
              label: Value(label),
              strength: strength,
            ),
          );
    });
    return id;
  }

  /// Returns the log with [id], of whichever type it is, or `null` if no
  /// such log exists. Returns soft-deleted logs too.
  Future<Log?> getById(String id) async {
    final row = await (_db.select(
      _db.logsTable,
    )..where((log) => log.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _hydrate(row);
  }

  Future<Log> _hydrate(LogRow row) async {
    switch (LogType.values.byName(row.type)) {
      case LogType.text:
        final text = await (_db.select(
          _db.textLogsTable,
        )..where((t) => t.logId.equals(row.id))).getSingle();
        return _toTextLog(row, text);
      case LogType.emoji:
        final emoji = await (_db.select(
          _db.emojiLogsTable,
        )..where((e) => e.logId.equals(row.id))).getSingle();
        return _toEmojiLog(row, emoji);
      case LogType.photo:
      case LogType.video:
      case LogType.audio:
      case LogType.location:
        throw UnimplementedError('${row.type} logs are not built yet');
    }
  }

  TextLog _toTextLog(LogRow log, TextLogRow text) => TextLog(
    id: log.id,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      log.createdAtMs,
      isUtc: true,
    ),
    tzOffsetMinutes: log.tzOffsetMinutes,
    editedAt: _msToUtc(log.editedAtMs),
    deletedAt: _msToUtc(log.deletedAtMs),
    body: text.body,
  );

  EmojiLog _toEmojiLog(LogRow log, EmojiLogRow emoji) => EmojiLog(
    id: log.id,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      log.createdAtMs,
      isUtc: true,
    ),
    tzOffsetMinutes: log.tzOffsetMinutes,
    editedAt: _msToUtc(log.editedAtMs),
    deletedAt: _msToUtc(log.deletedAtMs),
    emoji: emoji.emoji,
    label: emoji.label,
    strength: emoji.strength,
  );

  static DateTime? _msToUtc(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
