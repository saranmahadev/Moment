import 'dart:io';

import 'package:drift/native.dart';

/// Opens the database file at [path], encrypted with [key] (64 lowercase
/// hex characters, from [KeyStore.getOrCreateKey]) via SQLite3Multiple
/// Ciphers.
///
/// Throws a [StateError] if the opened sqlite3 library does not report an
/// active cipher, so a build without encryption support (for example, a
/// misconfigured `hooks.user_defines.sqlite3.source` in pubspec.yaml) fails
/// loudly instead of silently storing the database as plain text.
NativeDatabase openEncryptedDatabase(String path, String key) {
  return NativeDatabase(
    File(path),
    setup: (rawDb) {
      rawDb.execute("PRAGMA key = '$key'");
      if (rawDb.select('PRAGMA cipher').isEmpty) {
        throw StateError(
          'sqlite3 reports no active cipher: the sqlite3mc build is not in '
          'use, so the database would be stored unencrypted.',
        );
      }
    },
  );
}
