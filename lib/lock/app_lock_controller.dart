import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

import 'pin_storage.dart';

/// Moment's screen lock: a 4-digit PIN, salted and hashed before it is ever
/// stored, plus the locked/unlocked state the Lock screen gates on.
///
/// The app relocks itself whenever it leaves the foreground; call
/// [handleAppLifecycleState] from an `AppLifecycleListener` or
/// `WidgetsBindingObserver` to wire that up.
class AppLockController extends ChangeNotifier {
  AppLockController(this._storage, {Random? random})
    : _random = random ?? Random.secure();

  final PinStorage _storage;
  final Random _random;

  bool _locked = true;

  /// Whether the Lock screen should currently be shown.
  bool get isLocked => _locked;

  /// Whether a PIN has ever been set. The Lock screen only gates the app
  /// when this is true.
  Future<bool> hasPin() async => (await _storage.read()) != null;

  /// Sets (or replaces) the PIN. Must be exactly 4 digits.
  Future<void> setPin(String pin) async {
    _validate(pin);
    final salt = _generateSalt();
    await _storage.write('$salt:${_hash(pin, salt)}');
  }

  /// Checks [pin] against the stored one. Unlocks and returns true on a
  /// match; otherwise returns false and leaves the lock state unchanged.
  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read();
    if (stored == null) return false;

    final separator = stored.indexOf(':');
    final salt = stored.substring(0, separator);
    final expected = stored.substring(separator + 1);

    if (!_constantTimeEquals(_hash(pin, salt), expected)) return false;
    unlock();
    return true;
  }

  /// Removes the PIN entirely. The Lock screen stops gating the app until
  /// a new one is set.
  Future<void> clearPin() => _storage.clear();

  /// Shows the Lock screen.
  void lock() {
    if (_locked) return;
    _locked = true;
    notifyListeners();
  }

  /// Dismisses the Lock screen.
  void unlock() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  /// Relocks when the app leaves the foreground.
  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        lock();
      case AppLifecycleState.resumed:
        break;
    }
  }

  void _validate(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must be exactly 4 digits');
    }
  }

  String _generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _hash(String pin, String saltHex) {
    return sha256.convert(utf8.encode('$saltHex:$pin')).toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }
}
