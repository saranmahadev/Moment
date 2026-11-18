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

/// How many logs of one type are outside Trash, and when the newest was
/// made (see [LogRepository.watchTypeSummaries]).
class TypeSummary {
  const TypeSummary({
    required this.count,
    required this.newestAt,
    required this.newestOffsetMinutes,
  });

  final int count;
  final DateTime newestAt;
  final int newestOffsetMinutes;

  /// The newest log's wall-clock time where it was made, as [Log.localMoment].
  DateTime get newestMoment =>
      newestAt.add(Duration(minutes: newestOffsetMinutes));

  /// The newest log's own day, as [Log.localDay].
  DateTime get newestDay {
    final m = newestMoment;
    return DateTime.utc(m.year, m.month, m.day);
  }
}

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

  /// Creates a video log from an already-imported video (see
  /// `MediaStore.importVideo`) and returns its id.
  ///
  /// [createdAt] backdates the log; it defaults to now.
  Future<String> createVideo({
    required String path,
    required String posterPath,
    required Duration duration,
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
              type: LogType.video.name,
              createdAtMs: at.toUtc().millisecondsSinceEpoch,
              tzOffsetMinutes: at.timeZoneOffset.inMinutes,
            ),
          );
      await _db
          .into(_db.videoLogsTable)
          .insert(
            VideoLogsTableCompanion.insert(
              logId: id,
              path: path,
              posterPath: posterPath,
              durationMs: duration.inMilliseconds,
              caption: Value(caption),
            ),
          );
    });
    return id;
  }

  /// Sets a video log's [caption] (null clears it) and stamps `editedAt`.
  /// Throws if [id] does not name a video log.
  Future<void> updateVideo(String id, {required String? caption}) async {
    if (await getById(id) is! VideoLog) {
      throw ArgumentError.value(id, 'id', 'is not a video log');
    }

    await _db.transaction(() async {
      await (_db.update(_db.videoLogsTable)..where((v) => v.logId.equals(id)))
          .write(VideoLogsTableCompanion(caption: Value(caption)));
      await _touch(id);
    });
  }

  /// Creates a location log and returns its id. [latitude] must be within
  /// -90 to 90 and [longitude] within -180 to 180. [accuracyMeters] is
  /// left null when the coordinates were typed in rather than measured.
  ///
  /// [createdAt] backdates the log; it defaults to now.
  Future<String> createLocation({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    String? name,
    String? note,
    DateTime? createdAt,
  }) async {
    _checkCoordinates(latitude, longitude);

    final id = _generateId();
    final at = createdAt ?? _clock();
    await _db.transaction(() async {
      await _db
          .into(_db.logsTable)
          .insert(
            LogsTableCompanion.insert(
              id: id,
              type: LogType.location.name,
              createdAtMs: at.toUtc().millisecondsSinceEpoch,
              tzOffsetMinutes: at.timeZoneOffset.inMinutes,
            ),
          );
      await _db
          .into(_db.locationLogsTable)
          .insert(
            LocationLogsTableCompanion.insert(
              logId: id,
              latitude: latitude,
              longitude: longitude,
              accuracyM: Value(accuracyMeters),
              name: Value(name),
              note: Value(note),
            ),
          );
    });
    return id;
  }

  /// Moves a location log's pin, replacing its accuracy with
  /// [accuracyMeters] (null when the new spot was typed in), and stamps
  /// `editedAt`. Throws if [id] does not name a location log or the
  /// coordinates are out of range.
  Future<void> moveLocation(
    String id, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    _checkCoordinates(latitude, longitude);
    if (await getById(id) is! LocationLog) {
      throw ArgumentError.value(id, 'id', 'is not a location log');
    }

    await _db.transaction(() async {
      await (_db.update(
        _db.locationLogsTable,
      )..where((l) => l.logId.equals(id))).write(
        LocationLogsTableCompanion(
          latitude: Value(latitude),
          longitude: Value(longitude),
          accuracyM: Value(accuracyMeters),
        ),
      );
      await _touch(id);
    });
  }

  /// Sets a location log's [name] and [note] (null clears either) and
  /// stamps `editedAt`. Throws if [id] does not name a location log.
  Future<void> updateLocation(
    String id, {
    required String? name,
    required String? note,
  }) async {
    if (await getById(id) is! LocationLog) {
      throw ArgumentError.value(id, 'id', 'is not a location log');
    }

    await _db.transaction(() async {
      await (_db.update(
        _db.locationLogsTable,
      )..where((l) => l.logId.equals(id))).write(
        LocationLogsTableCompanion(name: Value(name), note: Value(note)),
      );
      await _touch(id);
    });
  }

  static void _checkCoordinates(double latitude, double longitude) {
    if (!(latitude >= -90 && latitude <= 90)) {
      throw ArgumentError.value(latitude, 'latitude', 'must be -90 to 90');
    }
    if (!(longitude >= -180 && longitude <= 180)) {
      throw ArgumentError.value(longitude, 'longitude', 'must be -180 to 180');
    }
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

  /// Every log, Trash included, read once rather than watched. For work
  /// that needs a snapshot (storage totals) instead of a live feed.
  Future<List<Log>> getAll() async {
    final rows = await _feedQuery().get();
    return [for (final row in rows) _rowToLog(row)];
  }

  /// Turns what was typed into an FTS5 query: every word must be there,
  /// each matched from its start (so results narrow as you type). Null
  /// when there is no word to look for.
  static String? searchQuery(String typed) {
    final words = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(typed).map((match) => match.group(0)!).toList();
    if (words.isEmpty) return null;
    return words.map((word) => '"$word"*').join(' ');
  }

  /// Logs whose words match [typed], newest first. Searches text, emoji
  /// names, captions, titles, notes and place names with SQLite's
  /// full-text index; logs in Trash are never returned. With [type], only
  /// logs of that type.
  Future<List<Log>> search(
    String typed, {
    LogType? type,
    int limit = 200,
  }) async {
    final query = searchQuery(typed);
    if (query == null) return const [];

    final matches = await _db
        .customSelect(
          'SELECT l.id AS id FROM log_search '
          'JOIN log l ON l.id = log_search.log_id '
          'WHERE log_search MATCH ? AND l.deleted_at_ms IS NULL '
          '${type == null ? '' : 'AND l.type = ? '}'
          'ORDER BY l.created_at_ms DESC, l.id DESC LIMIT ?',
          variables: [
            Variable.withString(query),
            if (type != null) Variable.withString(type.name),
            Variable.withInt(limit),
          ],
        )
        .get();
    final ids = [for (final row in matches) row.read<String>('id')];
    if (ids.isEmpty) return const [];

    final rows = await (_feedQuery()..where(_db.logsTable.id.isIn(ids))).get();
    final found = {
      for (final row in rows) row.readTable(_db.logsTable).id: _rowToLog(row),
    };
    return [for (final id in ids) ?found[id]];
  }

  /// Every log that is not in Trash, newest first (ties broken by id),
  /// optionally restricted to [types]. With [limit], only the newest that
  /// many: a page of the feed, read straight off its index. A larger limit
  /// gives the same list, longer.
  Stream<List<Log>> watchFeed({Set<LogType>? types, int? limit}) {
    final query = _feedQuery()
      ..where(_db.logsTable.deletedAtMs.isNull())
      ..orderBy([
        OrderingTerm.desc(_db.logsTable.createdAtMs),
        OrderingTerm.desc(_db.logsTable.id),
      ]);
    if (types != null) {
      query.where(_db.logsTable.type.isIn(types.map((t) => t.name)));
    }
    if (limit != null) query.limit(limit);
    return query.watch().map(
      (rows) => [for (final row in rows) _rowToLog(row)],
    );
  }

  /// The largest time zone offsets there are (UTC-12 to UTC+14).
  static const _widestOffset = Duration(hours: 14);

  /// Logs outside Trash that may belong to a day from [from] up to (not
  /// including) [to], both UTC midnights in the [Log.localDay] sense,
  /// newest first. The window is widened by the largest time zone offsets,
  /// so every log whose own day is inside is there; a few from just
  /// outside can be too, and callers group by [Log.localDay] anyway.
  Stream<List<Log>> watchFeedBetween(DateTime from, DateTime to) {
    final start = from.subtract(_widestOffset).millisecondsSinceEpoch;
    final end = to.add(_widestOffset).millisecondsSinceEpoch;
    final query = _feedQuery()
      ..where(
        _db.logsTable.deletedAtMs.isNull() &
            _db.logsTable.createdAtMs.isBiggerOrEqualValue(start) &
            _db.logsTable.createdAtMs.isSmallerThanValue(end),
      )
      ..orderBy([
        OrderingTerm.desc(_db.logsTable.createdAtMs),
        OrderingTerm.desc(_db.logsTable.id),
      ]);
    return query.watch().map(
      (rows) => [for (final row in rows) _rowToLog(row)],
    );
  }

  /// For each type with logs outside Trash: how many, and when the newest
  /// was made. One small query, instead of reading every log to count it.
  Stream<Map<LogType, TypeSummary>> watchTypeSummaries() => _db
      .customSelect(
        // SQLite takes the bare tz_offset_minutes from the row MAX() chose.
        'SELECT type, COUNT(*) AS n, MAX(created_at_ms) AS newest, '
        'tz_offset_minutes FROM log WHERE deleted_at_ms IS NULL '
        'GROUP BY type',
        readsFrom: {_db.logsTable},
      )
      .watch()
      .map(
        (rows) => {
          for (final row in rows)
            if (LogType.values.asNameMap()[row.read<String>('type')]
                case final type?)
              type: TypeSummary(
                count: row.read<int>('n'),
                newestAt: DateTime.fromMillisecondsSinceEpoch(
                  row.read<int>('newest'),
                  isUtc: true,
                ),
                newestOffsetMinutes: row.read<int>('tz_offset_minutes'),
              ),
        },
      );

  /// The calendar days that have at least one log outside Trash, each once.
  /// A day is the one the log was made on in its own time zone (the offset
  /// stored with it), as UTC midnights, the form [Log.localDay] uses. Reads
  /// one number per log instead of whole logs, so it stays cheap for the
  /// streaks that are worked out from it.
  Stream<Set<DateTime>> watchActiveDays() =>
      watchDayCounts().map((counts) => counts.keys.toSet());

  /// How many logs outside Trash each calendar day has (see
  /// [watchActiveDays] for what a day is); days with none are left out.
  Stream<Map<DateTime, int>> watchDayCounts() {
    const dayMs = Duration.millisecondsPerDay;
    // Floor division, so a moment before 1970 lands on the right day.
    const localMs = '(created_at_ms + tz_offset_minutes * 60000)';
    return _db
        .customSelect(
          'SELECT ($localMs - (($localMs % $dayMs) + $dayMs) % $dayMs)'
          ' / $dayMs AS day, COUNT(*) AS n FROM log '
          'WHERE deleted_at_ms IS NULL GROUP BY day',
          readsFrom: {_db.logsTable},
        )
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              DateTime.fromMillisecondsSinceEpoch(
                row.read<int>('day') * dayMs,
                isUtc: true,
              ): row.read<int>(
                'n',
              ),
          },
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
        leftOuterJoin(
          _db.videoLogsTable,
          _db.videoLogsTable.logId.equalsExp(_db.logsTable.id),
        ),
        leftOuterJoin(
          _db.locationLogsTable,
          _db.locationLogsTable.logId.equalsExp(_db.logsTable.id),
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
        return _toVideoLog(log, row.readTable(_db.videoLogsTable));
      case LogType.location:
        return _toLocationLog(log, row.readTable(_db.locationLogsTable));
    }
  }

  /// Permanently removes log [id] and its type-specific row, deleting its
  /// files from disk first if it has any.
  Future<void> deletePermanently(String id) async {
    final log = await getById(id);
    if (log != null) await _deleteFiles(log);
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
      await _deleteFiles(await _hydrate(row));
    }
  }

  /// The files a log owns on disk; empty for types that are rows only.
  static List<String> filesOf(Log log) => switch (log) {
    PhotoLog() => [log.path, log.thumbnailPath],
    AudioLog() => [log.path],
    VideoLog() => [log.path, log.posterPath],
    TextLog() || EmojiLog() || LocationLog() => const [],
  };

  Future<void> _deleteFiles(Log log) async {
    for (final path in filesOf(log)) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
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
        final video = await (_db.select(
          _db.videoLogsTable,
        )..where((v) => v.logId.equals(row.id))).getSingle();
        return _toVideoLog(row, video);
      case LogType.location:
        final location = await (_db.select(
          _db.locationLogsTable,
        )..where((l) => l.logId.equals(row.id))).getSingle();
        return _toLocationLog(row, location);
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

  VideoLog _toVideoLog(LogRow log, VideoLogRow video) => VideoLog(
    id: log.id,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      log.createdAtMs,
      isUtc: true,
    ),
    tzOffsetMinutes: log.tzOffsetMinutes,
    editedAt: _msToUtc(log.editedAtMs),
    deletedAt: _msToUtc(log.deletedAtMs),
    path: video.path,
    posterPath: video.posterPath,
    duration: Duration(milliseconds: video.durationMs),
    caption: video.caption,
  );

  LocationLog _toLocationLog(LogRow log, LocationLogRow location) =>
      LocationLog(
        id: log.id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          log.createdAtMs,
          isUtc: true,
        ),
        tzOffsetMinutes: log.tzOffsetMinutes,
        editedAt: _msToUtc(log.editedAtMs),
        deletedAt: _msToUtc(log.deletedAtMs),
        latitude: location.latitude,
        longitude: location.longitude,
        accuracyMeters: location.accuracyM,
        name: location.name,
        note: location.note,
      );

  static DateTime? _msToUtc(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
