import 'dart:convert';
import 'dart:io';

/// Remembers when the last backup was made, for "Last backup: …" on the
/// Privacy screen.
abstract interface class LastBackupStore {
  Future<DateTime?> read();
  Future<void> write(DateTime at);
}

/// Keeps the time in a small JSON file in the app-private directory.
class FileLastBackupStore implements LastBackupStore {
  FileLastBackupStore(this._file);

  final File _file;

  @override
  Future<DateTime?> read() async {
    if (!await _file.exists()) return null;
    try {
      final json = jsonDecode(await _file.readAsString());
      final ms = (json as Map)['lastBackupMs'];
      return ms is int
          ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
          : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(DateTime at) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode({'lastBackupMs': at.toUtc().millisecondsSinceEpoch}),
    );
  }
}
