import 'dart:convert';
import 'dart:io';

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

  static const _trashRetention = Duration(days: 30);

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

  /// Creates a photo log from an already-imported photo (see
  /// `MediaStore.importPhoto`) and returns its id.
  ///
  /// [createdAt] backdates the log; it defaults to now.
  Future<String> createPhoto({
    required String path,
    required String thumbnailPath,
    String? caption,
    DateTime? createdAt,
  }) async {
    final id = _generateId();
    final at = createdAt ?? _clock();
    await _db.transaction(() async {
      await _db
          .into(_db.logsTable)
          .insert(
            LogsTableCompanion.insert(
              id: id,
              type: LogType.photo.name,
              createdAtMs: at.toUtc().millisecondsSinceEpoch,
              tzOffsetMinutes: at.timeZoneOffset.inMinutes,
            ),
          );
      await _db
          .into(_db.photoLogsTable)
          .insert(
            PhotoLogsTableCompanion.insert(
              logId: id,
              path: path,
              thumbnailPath: thumbnailPath,
              caption: Value(caption),
            ),
          );
    });
    return id;
  }

  /// Changes a photo log's [caption] and stamps `editedAt`. Throws if [id]
  /// does not name a photo log.
  Future<void> updateCaption(String id, {String? caption}) async {
    if (await getById(id) is! PhotoLog) {
      throw ArgumentError.value(id, 'id', 'is not a photo log');
    }

    await _db.transaction(() async {
      await (_db.update(_db.photoLogsTable)..where((p) => p.logId.equals(id)))
          .write(PhotoLogsTableCompanion(caption: Value(caption)));
      await _touch(id);
    });
  }

  /// Creates an audio log from an already-recorded clip (see
  /// `MediaStore.importAudio`) and returns its id.
  ///
  /// [createdAt] backdates the log; it defaults to now.
  Future<String> createAudio({
    required String path,
    required Duration duration,
    required List<double> peaks,
    String? title,
    String? note,
    DateTime? createdAt,
  }) async {
    final id = _generateId();
    final at = createdAt ?? _clock();
    await _db.transaction(() async {
      await _db
          .into(_db.logsTable)
          .insert(
            LogsTableCompanion.insert(
              id: id,
              type: LogType.audio.name,
              createdAtMs: at.toUtc().millisecondsSinceEpoch,
              tzOffsetMinutes: at.timeZoneOffset.inMinutes,
            ),
          );
      await _db
          .into(_db.audioLogsTable)
          .insert(
            AudioLogsTableCompanion.insert(
              logId: id,
              path: path,
              durationMs: duration.inMilliseconds,
              peaks: jsonEncode(peaks),
              title: Value(title),
              note: Value(note),
            ),
          );
    });
    return id;
  }

  /// Changes an audio log's [title] and/or [note], leaving any field not
  /// passed unchanged, and stamps `editedAt`. Throws if [id] does not name
  /// an audio log.
  Future<void> updateAudio(String id, {String? title, String? note}) async {
    if (await getById(id) is! AudioLog) {
      throw ArgumentError.value(id, 'id', 'is not an audio log');
    }

    await _db.transaction(() async {
      await (_db.update(
        _db.audioLogsTable,
      )..where((a) => a.logId.equals(id))).write(
        AudioLogsTableCompanion(
          title: title == null ? const Value.absent() : Value(title),
          note: note == null ? const Value.absent() : Value(note),
        ),
      );
      await _touch(id);
    });
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
        leftOuterJoin(
          _db.photoLogsTable,
          _db.photoLogsTable.logId.equalsExp(_db.logsTable.id),
        ),
        leftOuterJoin(
          _db.audioLogsTable,
          _db.audioLogsTable.logId.equalsExp(_db.logsTable.id),
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
        return _toPhotoLog(log, row.readTable(_db.photoLogsTable));
      case LogType.audio:
        return _toAudioLog(log, row.readTable(_db.audioLogsTable));
      case LogType.video:
      case LogType.location:
        throw UnimplementedError('${log.type} logs are not built yet');
    }
  }

  /// Permanently removes log [id] and its type-specific row, deleting its
  /// files from disk first if it has any.
  Future<void> deletePermanently(String id) async {
    final log = await getById(id);
    if (log is PhotoLog) {
      await _deletePhotoFiles(log);
    } else if (log is AudioLog) {
      await _deleteAudioFile(log);
    }
    await (_db.delete(_db.logsTable)..where((l) => l.id.equals(id))).go();
  }

  /// Permanently removes every log currently in Trash, deleting files from
  /// disk first for any that have them.
  Future<void> emptyTrash() async {
    await _deleteFilesForTrashed((_db.logsTable.deletedAtMs.isNotNull()));
    await (_db.delete(
      _db.logsTable,
    )..where((l) => l.deletedAtMs.isNotNull())).go();
  }

  /// Permanently removes every log that has been in Trash for more than 30
  /// days, as measured against [now], deleting files from disk first for
  /// any that have them.
  Future<void> purgeExpired(DateTime now) async {
    final cutoff = now.subtract(_trashRetention).toUtc().millisecondsSinceEpoch;
    await _deleteFilesForTrashed(
      (_db.logsTable.deletedAtMs.isSmallerOrEqualValue(cutoff)),
    );
    await (_db.delete(
      _db.logsTable,
    )..where((l) => l.deletedAtMs.isSmallerOrEqualValue(cutoff))).go();
  }

  /// Deletes the on-disk files of every log matching [predicate] that has
  /// any, ahead of a bulk row delete using the same predicate.
  Future<void> _deleteFilesForTrashed(Expression<bool> predicate) async {
    final rows = await (_db.select(
      _db.logsTable,
    )..where((l) => predicate)).get();
    for (final row in rows) {
      if (row.type == LogType.photo.name) {
        final log = await _hydrate(row);
        if (log is PhotoLog) {
          await _deletePhotoFiles(log);
        }
      } else if (row.type == LogType.audio.name) {
        final log = await _hydrate(row);
        if (log is AudioLog) {
          await _deleteAudioFile(log);
        }
      }
    }
  }

  Future<void> _deletePhotoFiles(PhotoLog log) async {
    for (final path in [log.path, log.thumbnailPath]) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _deleteAudioFile(AudioLog log) async {
    final file = File(log.path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Backdates or postdates log [id] to [createdAt], recomputing the
  /// recorded time zone offset from it. Does not change `editedAt`.
  Future<void> setCreatedAt(String id, DateTime createdAt) async {
    await (_db.update(_db.logsTable)..where((l) => l.id.equals(id))).write(
      LogsTableCompanion(
        createdAtMs: Value(createdAt.toUtc().millisecondsSinceEpoch),
        tzOffsetMinutes: Value(createdAt.timeZoneOffset.inMinutes),
      ),
    );
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
        final photo = await (_db.select(
          _db.photoLogsTable,
        )..where((p) => p.logId.equals(row.id))).getSingle();
        return _toPhotoLog(row, photo);
      case LogType.audio:
        final audio = await (_db.select(
          _db.audioLogsTable,
        )..where((a) => a.logId.equals(row.id))).getSingle();
        return _toAudioLog(row, audio);
      case LogType.video:
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

  PhotoLog _toPhotoLog(LogRow log, PhotoLogRow photo) => PhotoLog(
    id: log.id,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      log.createdAtMs,
      isUtc: true,
    ),
    tzOffsetMinutes: log.tzOffsetMinutes,
    editedAt: _msToUtc(log.editedAtMs),
    deletedAt: _msToUtc(log.deletedAtMs),
    path: photo.path,
    thumbnailPath: photo.thumbnailPath,
    caption: photo.caption,
  );

  AudioLog _toAudioLog(LogRow log, AudioLogRow audio) => AudioLog(
    id: log.id,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      log.createdAtMs,
      isUtc: true,
    ),
    tzOffsetMinutes: log.tzOffsetMinutes,
    editedAt: _msToUtc(log.editedAtMs),
    deletedAt: _msToUtc(log.deletedAtMs),
    path: audio.path,
    duration: Duration(milliseconds: audio.durationMs),
    peaks: (jsonDecode(audio.peaks) as List)
        .cast<num>()
        .map((n) => n.toDouble())
        .toList(),
    title: audio.title,
    note: audio.note,
  );

  static DateTime? _msToUtc(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
