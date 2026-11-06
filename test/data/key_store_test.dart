import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/key_store.dart';

class _FakeKeyStorage implements KeyStorage {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String key) async => stored = key;
}

void main() {
  group('KeyStore', () {
    test('creates a 64-character hex key on first use', () async {
      final store = KeyStore(_FakeKeyStorage());
      final key = await store.getOrCreateKey();

      expect(key.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
    });

    test('persists the key it creates', () async {
      final storage = _FakeKeyStorage();
      final key = await KeyStore(storage).getOrCreateKey();
      expect(storage.stored, key);
    });

    test('the key survives a restart: a fresh KeyStore over the same storage '
        'returns the same key', () async {
      final storage = _FakeKeyStorage();
      final key = await KeyStore(storage).getOrCreateKey();

      final afterRestart = KeyStore(storage);
      expect(await afterRestart.getOrCreateKey(), key);
    });

    test('generated keys are unique across separate storages', () async {
      final key1 = await KeyStore(_FakeKeyStorage()).getOrCreateKey();
      final key2 = await KeyStore(_FakeKeyStorage()).getOrCreateKey();
      expect(key1, isNot(key2));
    });
  });
}
