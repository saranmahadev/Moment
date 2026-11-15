import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:cryptography/cryptography.dart';

import 'backup_exceptions.dart';

/// The `.moment` container: a passphrase-protected, streamed, authenticated
/// byte stream.
///
/// Layout (all integers big-endian):
///
/// ```
/// header, 48 bytes
///   magic          8   "MOMENT" 0x00 0x01 (format version 1)
///   salt          16   random; PBKDF2 salt
///   iterations     4   uint32; PBKDF2-HMAC-SHA256 iteration count
///   nonce prefix  20   random; first 20 bytes of every chunk nonce
/// chunks, repeated until one carries the final flag
///   length         4   uint32; bytes of ciphertext including the 16-byte tag
///   flag           1   0x00 = more chunks follow, 0x01 = final chunk
///   ciphertext   length
/// ```
///
/// Each chunk is XChaCha20-Poly1305 with nonce = prefix ‖ uint32 chunk
/// index, and the header ‖ flag ‖ index as associated data. Binding the
/// index and flag means a chunk cannot be dropped, reordered or replayed
/// from another position, and the header cannot be altered (for example
/// to lower the iteration count) without every chunk failing to open.
/// Truncation is caught because the last chunk must carry the final flag.
///
/// The key is derived from the passphrase with PBKDF2-HMAC-SHA256. A wrong
/// passphrase is reported from the first chunk, before any plaintext leaves
/// [decrypt]; a later authentication failure is reported as corruption.
class BackupCipher {
  BackupCipher({
    this.kdfIterations = defaultKdfIterations,
    this.chunkSize = defaultChunkSize,
    Random? random,
  }) : _random = random ?? Random.secure();

  static const magic = [0x4D, 0x4F, 0x4D, 0x45, 0x4E, 0x54, 0x00, 0x01];
  static const headerLength = 48;
  static const defaultKdfIterations = 150000;
  static const defaultChunkSize = 256 * 1024;

  static const _saltLength = 16;
  static const _noncePrefixLength = 20;
  static const _macLength = 16;
  static const _flagMore = 0x00;
  static const _flagFinal = 0x01;

  final int kdfIterations;
  final int chunkSize;
  final Random _random;
  final _cipher = Xchacha20.poly1305Aead();

  Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt,
    int iterations,
  ) {
    return Pbkdf2.hmacSha256(
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  static Uint8List _nonceFor(Uint8List prefix, int index) {
    final nonce = Uint8List(_noncePrefixLength + 4)..setAll(0, prefix);
    ByteData.sublistView(nonce).setUint32(_noncePrefixLength, index);
    return nonce;
  }

  static Uint8List _aadFor(Uint8List header, int flag, int index) {
    final aad = Uint8List(headerLength + 1 + 4)..setAll(0, header);
    aad[headerLength] = flag;
    ByteData.sublistView(aad).setUint32(headerLength + 1, index);
    return aad;
  }

  /// Encrypts [plaintext] under [passphrase], yielding the complete file.
  Stream<List<int>> encrypt(
    Stream<List<int>> plaintext, {
    required String passphrase,
  }) async* {
    final salt = _randomBytes(_saltLength);
    final noncePrefix = _randomBytes(_noncePrefixLength);
    final header = Uint8List(headerLength)
      ..setAll(0, magic)
      ..setAll(magic.length, salt)
      ..setAll(magic.length + _saltLength + 4, noncePrefix);
    ByteData.sublistView(
      header,
    ).setUint32(magic.length + _saltLength, kdfIterations);
    yield header;

    final key = await _deriveKey(passphrase, salt, kdfIterations);
    var index = 0;

    Future<Uint8List> seal(List<int> clear, int flag) async {
      final box = await _cipher.encrypt(
        clear,
        secretKey: key,
        nonce: _nonceFor(noncePrefix, index),
        aad: _aadFor(header, flag, index),
      );
      index++;
      final body = box.cipherText.length + box.mac.bytes.length;
      final framed = Uint8List(5 + body);
      ByteData.sublistView(framed).setUint32(0, body);
      framed[4] = flag;
      framed.setAll(5, box.cipherText);
      framed.setAll(5 + box.cipherText.length, box.mac.bytes);
      return framed;
    }

    // Every chunk but the last is exactly chunkSize bytes, and the last is
    // emitted only once the input has ended so it alone carries the flag.
    final buffer = BytesBuilder(copy: false);
    await for (final piece in plaintext) {
      buffer.add(piece);
      while (buffer.length >= chunkSize) {
        final all = buffer.takeBytes();
        yield await seal(Uint8List.sublistView(all, 0, chunkSize), _flagMore);
        buffer.add(Uint8List.sublistView(all, chunkSize));
      }
    }
    yield await seal(buffer.takeBytes(), _flagFinal);
  }

  /// Decrypts a file produced by [encrypt], yielding the plaintext.
  ///
  /// Throws [BackupFormatException], [WrongPassphraseException] or
  /// [CorruptBackupException]; nothing is yielded past the point of failure.
  Stream<List<int>> decrypt(
    Stream<List<int>> file, {
    required String passphrase,
  }) async* {
    final reader = ChunkedStreamReader(file);
    try {
      final header = await reader.readBytes(headerLength);
      if (header.length < headerLength ||
          !_listEquals(header.sublist(0, magic.length), magic)) {
        throw const BackupFormatException('This is not a Moment backup file.');
      }
      final salt = header.sublist(magic.length, magic.length + _saltLength);
      final iterations = ByteData.sublistView(
        header,
      ).getUint32(magic.length + _saltLength);
      final noncePrefix = header.sublist(
        magic.length + _saltLength + 4,
        headerLength,
      );
      final key = await _deriveKey(passphrase, salt, iterations);

      var index = 0;
      while (true) {
        final frame = await reader.readBytes(5);
        if (frame.length < 5) {
          throw const CorruptBackupException(
            'The backup ends before its final chunk.',
          );
        }
        final length = ByteData.sublistView(frame).getUint32(0);
        final flag = frame[4];
        if ((flag != _flagMore && flag != _flagFinal) || length < _macLength) {
          throw const CorruptBackupException('A chunk header is damaged.');
        }
        final body = await reader.readBytes(length);
        if (body.length < length) {
          throw const CorruptBackupException(
            'The backup ends in the middle of a chunk.',
          );
        }
        final box = SecretBox(
          Uint8List.sublistView(body, 0, length - _macLength),
          nonce: _nonceFor(noncePrefix, index),
          mac: Mac(Uint8List.sublistView(body, length - _macLength)),
        );
        final List<int> clear;
        try {
          clear = await _cipher.decrypt(
            box,
            secretKey: key,
            aad: _aadFor(header, flag, index),
          );
        } on SecretBoxAuthenticationError {
          if (index == 0) throw const WrongPassphraseException();
          throw const CorruptBackupException('A chunk failed to authenticate.');
        }
        index++;
        if (clear.isNotEmpty) yield clear;
        if (flag == _flagFinal) break;
      }
      if ((await reader.readBytes(1)).isNotEmpty) {
        throw const CorruptBackupException(
          'There is data after the final chunk.',
        );
      }
    } finally {
      await reader.cancel();
    }
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
