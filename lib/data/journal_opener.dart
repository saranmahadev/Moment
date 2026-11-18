import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'database.dart';
import 'key_store.dart';
import 'secure_database.dart';

/// Why a journal on this phone could not be opened.
enum JournalProblem {
  /// The file is there but its key is not: the phone's secure storage was
  /// wiped, for example after some device restores.
  keyMissing,

  /// There is a key, but it does not open the file.
  unreadable,
}

/// What [JournalOpener.open] found.
sealed class JournalOpening {
  const JournalOpening();
}

/// The journal is open and ready.
final class JournalOpened extends JournalOpening {
  const JournalOpened(this.db);
  final AppDatabase db;
}

/// The journal is there but cannot be opened. Nothing was changed.
final class JournalBlocked extends JournalOpening {
  const JournalBlocked(this.problem);
  final JournalProblem problem;
}

/// Opens the encrypted journal at launch, and never makes a lost key
/// worse: a new key is only made when there is no journal yet, or when the
/// person chooses to start fresh.
class JournalOpener {
  JournalOpener({
    required this.file,
    required KeyStorage keys,
    this.openFile = openEncryptedDatabase,
    DateTime Function() clock = DateTime.now,
  }) : _keys = keys,
       _keyStore = KeyStore(keys),
       _clock = clock;

  final File file;
  final KeyStorage _keys;
  final KeyStore _keyStore;
  final DateTime Function() _clock;

  /// How a file is opened with a key; the real one is encrypted.
  final QueryExecutor Function(String path, String key) openFile;

  Future<JournalOpening> open() async {
    final key = await _keys.read();
    if (key == null) {
      if (file.existsSync()) {
        return const JournalBlocked(JournalProblem.keyMissing);
      }
      return JournalOpened(await _openChecked(await _keyStore.createKey()));
    }
    try {
      return JournalOpened(await _openChecked(key));
    } on SqliteException catch (e) {
      // SQLITE_NOTADB: what a wrong key looks like from the outside.
      if (e.resultCode == 26) {
        return const JournalBlocked(JournalProblem.unreadable);
      }
      rethrow;
    }
  }

  /// Moves the journal that cannot be opened aside, beside it under a
  /// dated name (it is never deleted), makes a new key and opens a new,
  /// empty journal.
  Future<AppDatabase> startFresh() async {
    if (file.existsSync()) {
      final stamp = _stamp(_clock());
      var aside = File(p.join(file.parent.path, 'moment-unopened-$stamp.db'));
      for (var n = 2; aside.existsSync(); n++) {
        aside = File(p.join(file.parent.path, 'moment-unopened-$stamp-$n.db'));
      }
      file.renameSync(aside.path);
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final extra = File('${file.path}$suffix');
        if (extra.existsSync()) extra.renameSync('${aside.path}$suffix');
      }
    }
    return _openChecked(await _keyStore.createKey());
  }

  /// Opens and reads from the file at once, so a wrong key shows up here
  /// rather than in the first screen that asks for logs.
  Future<AppDatabase> _openChecked(String key) async {
    final db = AppDatabase(openFile(file.path, key));
    try {
      await db.customSelect('SELECT count(*) FROM sqlite_master').get();
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  static String _stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
