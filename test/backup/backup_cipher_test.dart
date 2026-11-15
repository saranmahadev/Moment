import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_exceptions.dart';

Future<Uint8List> collect(Stream<List<int>> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Stream<List<int>> inPieces(List<int> bytes, int pieceSize) async* {
  for (var i = 0; i < bytes.length; i += pieceSize) {
    yield bytes.sublist(i, min(bytes.length, i + pieceSize));
  }
}

void main() {
  // Few PBKDF2 iterations and a tiny chunk so tests stay fast and exercise
  // multi-chunk files; the real app uses the defaults.
  final cipher = BackupCipher(
    kdfIterations: 10,
    chunkSize: 64,
    random: Random(42),
  );
  final plaintext = List<int>.generate(1000, (i) => (i * 7) % 256);

  test(
    'a round trip returns the original bytes, however it is chunked',
    () async {
      final file = await collect(
        cipher.encrypt(inPieces(plaintext, 100), passphrase: 'correct horse'),
      );
      final back = await collect(
        cipher.decrypt(inPieces(file, 33), passphrase: 'correct horse'),
      );
      expect(back, plaintext);
    },
  );

  test(
    'an empty library still produces a file that decrypts to nothing',
    () async {
      final file = await collect(
        cipher.encrypt(const Stream.empty(), passphrase: 'pw'),
      );
      expect(file.length, greaterThan(BackupCipher.headerLength));
      final back = await collect(
        cipher.decrypt(Stream.value(file), passphrase: 'pw'),
      );
      expect(back, isEmpty);
    },
  );

  test('the file starts with the magic bytes and format version', () async {
    final file = await collect(
      cipher.encrypt(Stream.value(plaintext), passphrase: 'pw'),
    );
    expect(file.sublist(0, 8), BackupCipher.magic);
  });

  test('two backups of the same bytes differ (fresh salt and nonce)', () async {
    final a = await collect(
      cipher.encrypt(Stream.value(plaintext), passphrase: 'pw'),
    );
    final b = await collect(
      cipher.encrypt(Stream.value(plaintext), passphrase: 'pw'),
    );
    expect(a, isNot(b));
  });

  test(
    'a wrong passphrase fails cleanly before any plaintext is produced',
    () async {
      final file = await collect(
        cipher.encrypt(Stream.value(plaintext), passphrase: 'right'),
      );
      final produced = <int>[];
      await expectLater(() async {
        await for (final chunk in cipher.decrypt(
          Stream.value(file),
          passphrase: 'wrong',
        )) {
          produced.addAll(chunk);
        }
      }(), throwsA(isA<WrongPassphraseException>()));
      expect(produced, isEmpty);
    },
  );

  test('a file that is not a backup is rejected as the wrong format', () async {
    final notABackup = List<int>.filled(200, 0x41);
    await expectLater(
      collect(cipher.decrypt(Stream.value(notABackup), passphrase: 'pw')),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('a flipped byte in the body is detected as corruption', () async {
    final file = await collect(
      cipher.encrypt(Stream.value(plaintext), passphrase: 'pw'),
    );
    // Past the header and the first chunk, so the passphrase check passes
    // and this reads as damage rather than a wrong passphrase.
    final damaged = Uint8List.fromList(file);
    final index = file.length - 10;
    damaged[index] = damaged[index] ^ 0xFF;
    await expectLater(
      collect(cipher.decrypt(Stream.value(damaged), passphrase: 'pw')),
      throwsA(isA<CorruptBackupException>()),
    );
  });

  test('a truncated file is detected as corruption', () async {
    final file = await collect(
      cipher.encrypt(Stream.value(plaintext), passphrase: 'pw'),
    );
    final truncated = file.sublist(0, file.length - 40);
    await expectLater(
      collect(cipher.decrypt(Stream.value(truncated), passphrase: 'pw')),
      throwsA(isA<CorruptBackupException>()),
    );
  });

  test('a tampered header (lowered KDF iterations) is detected', () async {
    final file = await collect(
      cipher.encrypt(Stream.value(plaintext), passphrase: 'pw'),
    );
    final tampered = Uint8List.fromList(file);
    tampered[BackupCipher.headerLength - 1] ^= 0x01;
    await expectLater(
      collect(cipher.decrypt(Stream.value(tampered), passphrase: 'pw')),
      throwsA(isA<BackupException>()),
    );
  });

  test('chunks cannot be reordered or dropped unnoticed', () async {
    final file = await collect(
      cipher.encrypt(Stream.value(plaintext), passphrase: 'pw'),
    );
    final header = file.sublist(0, BackupCipher.headerLength);
    final body = file.sublist(BackupCipher.headerLength);
    // Drop the first chunk (4-byte length, 1-byte flag, then the payload).
    final firstLength = ByteData.sublistView(body, 0, 4).getUint32(0);
    final withoutFirst = body.sublist(5 + firstLength);
    await expectLater(
      collect(
        cipher.decrypt(
          Stream.value([...header, ...withoutFirst]),
          passphrase: 'pw',
        ),
      ),
      throwsA(isA<BackupException>()),
    );
  });
}
