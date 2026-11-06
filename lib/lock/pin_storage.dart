import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the PIN's salted hash is persisted. Implemented by
/// [SecurePinStorage] (Keychain on iOS, Keystore on Android) in production,
/// and by a fake in tests.
abstract class PinStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

/// Persists the PIN's salted hash in the platform Keychain or Keystore via
/// `flutter_secure_storage`.
class SecurePinStorage implements PinStorage {
  SecurePinStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'moment.pin_hash';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _storageKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _storageKey, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _storageKey);
}
