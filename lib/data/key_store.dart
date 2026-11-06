import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the database encryption key is persisted. Implemented by
/// [SecureKeyStorage] (Keychain on iOS, Keystore on Android) in production,
/// and by a fake in tests.
abstract class KeyStorage {
  Future<String?> read();
  Future<void> write(String key);
}

/// Persists the key in the platform Keychain or Keystore via
/// `flutter_secure_storage`.
class SecureKeyStorage implements KeyStorage {
  SecureKeyStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'moment.database_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _storageKey);

  @override
  Future<void> write(String key) =>
      _storage.write(key: _storageKey, value: key);
}

/// Generates and persists the database's encryption key: 32 random bytes,
/// created once on first launch and held as 64 lowercase hex characters.
class KeyStore {
  KeyStore(this._storage, {Random? random})
    : _random = random ?? Random.secure();

  final KeyStorage _storage;
  final Random _random;

  /// Returns the existing key, or generates, persists and returns a new
  /// one if none has been created yet.
  Future<String> getOrCreateKey() async {
    final existing = await _storage.read();
    if (existing != null) return existing;

    final key = _generateKey();
    await _storage.write(key);
    return key;
  }

  String _generateKey() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
