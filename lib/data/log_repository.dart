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

  /// Moves log [id] to Trash by stamping `deletedAt` with the current time.
  Future<void> softDelete(String id) async {
    await (_db.update(_db.logsTable)..where((l) => l.id.equals(id))).write(
      LogsTableCompanion(
        deletedAtMs: Value(_clock().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  /// Takes log [id] out of Trash by clearing `deletedAt`.
  Future<void> restore(String id) async {
    await (_db.update(_db.logsTable)..where((l) => l.id.equals(id))).write(
      const LogsTableCompanion(deletedAtMs: Value(null)),
    );
  }

  /// Every log that is not in Trash, newest first (ties broken by id),
  /// optionally restricted to [types].
  Stream<List<Log>> watchFeed({Set<LogType>? types}) {
    final query = _feedQuery()
      ..where(_db.logsTable.deletedAtMs.isNull())
      ..orderBy([
        OrderingTerm.desc(_db.logsTable.createdAtMs),
        OrderingTerm.desc(_db.logsTable.id),
      ]);
    if (types != null) {
      query.where(_db.logsTable.type.isIn(types.map((t) => t.name)));
    }
    return query.watch().map(
      (rows) => [for (final row in rows) _rowToLog(row)],
    );
  }

  /// Every log in Trash, most recently deleted first.
  Stream<List<Log>> watchTrash() {
    final query = _feedQuery()
      ..where(_db.logsTable.deletedAtMs.isNotNull())
      ..orderBy([
        OrderingTerm.desc(_db.logsTable.deletedAtMs),
        OrderingTerm.desc(_db.logsTable.id),
      ]);
    return query.watch().map(
      (rows) => [for (final row in rows) _rowToLog(row)],
    );
  }

  JoinedSelectStatement<HasResultSet, dynamic> _feedQuery() =>
      _db.select(_db.logsTable).join([
        leftOuterJoin(
          _db.textLogsTable,
          _db.textLogsTable.logId.equalsExp(_db.logsTable.id),
        ),
        leftOuterJoin(
          _db.emojiLogsTable,
          _db.emojiLogsTable.logId.equalsExp(_db.logsTable.id),
        ),
      ]);

  Log _rowToLog(TypedResult row) {
    final log = row.readTable(_db.logsTable);
    switch (LogType.values.byName(log.type)) {
      case LogType.text:
        return _toTextLog(log, row.readTable(_db.textLogsTable));
      case LogType.emoji:
        return _toEmojiLog(log, row.readTable(_db.emojiLogsTable));
      case LogType.photo:
      case LogType.video:
      case LogType.audio:
      case LogType.location:
        throw UnimplementedError('${log.type} logs are not built yet');
    }
  }

  /// Changes a text log's [body] and stamps `editedAt`. Throws if [id] does
  /// not name a text log, or [body] is blank.
  Future<void> updateText(String id, {required String body}) async {
    if (body.trim().isEmpty) {
      throw ArgumentError.value(body, 'body', 'must not be blank');
    }
    if (await getById(id) is! TextLog) {
      throw ArgumentError.value(id, 'id', 'is not a text log');
    }

    await _db.transaction(() async {
      await (_db.update(_db.textLogsTable)..where((t) => t.logId.equals(id)))
          .write(TextLogsTableCompanion(body: Value(body)));
      await _touch(id);
    });
  }

  /// Changes an emoji log's [emoji], [label] and/or [strength], leaving any
  /// field not passed unchanged, and stamps `editedAt`. Throws if [id] does
  /// not name an emoji log, [emoji] is passed empty, or [strength] is
  /// passed outside 1 to 5.
  Future<void> updateEmoji(
    String id, {
    String? emoji,
    String? label,
    int? strength,
  }) async {
    if (emoji != null && emoji.isEmpty) {
      throw ArgumentError.value(emoji, 'emoji', 'must not be empty');
    }
    if (strength != null && (strength < 1 || strength > 5)) {
      throw ArgumentError.value(strength, 'strength', 'must be 1 to 5');
    }
    if (await getById(id) is! EmojiLog) {
      throw ArgumentError.value(id, 'id', 'is not an emoji log');
    }

    await _db.transaction(() async {
      await (_db.update(
        _db.emojiLogsTable,
      )..where((e) => e.logId.equals(id))).write(
        EmojiLogsTableCompanion(
          emoji: emoji == null ? const Value.absent() : Value(emoji),
          label: label == null ? const Value.absent() : Value(label),
          strength: strength == null ? const Value.absent() : Value(strength),
        ),
      );
      await _touch(id);
    });
  }

  /// Stamps `editedAt` on log [id] with the current time.
  Future<void> _touch(String id) async {
    await (_db.update(_db.logsTable)..where((l) => l.id.equals(id))).write(
      LogsTableCompanion(
        editedAtMs: Value(_clock().toUtc().millisecondsSinceEpoch),
      ),
    );
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
