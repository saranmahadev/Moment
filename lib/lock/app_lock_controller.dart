import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

import 'pin_storage.dart';
import 'screen_privacy.dart';

/// Moment's screen lock: a 4-digit PIN, salted and hashed before it is ever
/// stored, plus the locked/unlocked state the Lock screen gates on.
///
/// The app relocks itself whenever it leaves the foreground; call
/// [handleAppLifecycleState] from an `AppLifecycleListener` or
/// `WidgetsBindingObserver` to wire that up.
class AppLockController extends ChangeNotifier {
  AppLockController(
    this._storage, {
    Random? random,
    ScreenPrivacy? screenPrivacy,
    DateTime Function() clock = DateTime.now,
  }) : _random = random ?? Random.secure(),
       _screenPrivacy = screenPrivacy,
       _clock = clock;

  final PinStorage _storage;
  final Random _random;
  final ScreenPrivacy? _screenPrivacy;
  final DateTime Function() _clock;

  bool _locked = true;
  bool _pinIsSet = false;

  /// Wrong PINs in a row since the last right one.
  int _failures = 0;
  DateTime? _waitUntil;

  /// Wrong tries allowed before each further one costs a wait.
  static const freeTries = 4;
  static const _firstWait = Duration(seconds: 30);
  static const _longestWait = Duration(minutes: 15);

  /// Whether a PIN is set, as of [load] and every change since. The Lock
  /// screen only gates the app while this is true.
  bool get pinIsSet => _pinIsSet;

  /// How long until another PIN may be tried, or null if one may be tried
  /// now. Wrong tries after the first [freeTries] each cost a wait, from
  /// 30 seconds doubling up to 15 minutes. Kept in memory only.
  Duration? get retryAfter {
    final until = _waitUntil;
    if (until == null) return null;
    final left = until.difference(_clock());
    return left > Duration.zero ? left : null;
  }

  /// Reads whether a PIN is set, locks if one is, and hides or shows the
  /// app switcher preview to match. Call once at launch.
  Future<void> load() async {
    _pinIsSet = (await _storage.read()) != null;
    _locked = _pinIsSet;
    notifyListeners();
    await _screenPrivacy?.setHidden(_pinIsSet);
  }

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
    _pinIsSet = true;
    notifyListeners();
    await _screenPrivacy?.setHidden(true);
  }

  /// Checks [pin] against the stored one. Unlocks and returns true on a
  /// match; otherwise returns false and leaves the lock state unchanged.
  /// While [retryAfter] is not null every PIN, even the right one, is
  /// refused without being checked.
  Future<bool> verifyPin(String pin) async {
    if (retryAfter != null) return false;
    final stored = await _storage.read();
    if (stored == null) return false;

    final separator = stored.indexOf(':');
    final salt = stored.substring(0, separator);
    final expected = stored.substring(separator + 1);

    if (!_constantTimeEquals(_hash(pin, salt), expected)) {
      _failures++;
      if (_failures > freeTries) {
        final doublings = min(_failures - freeTries - 1, 10);
        var wait = _firstWait * (1 << doublings);
        if (wait > _longestWait) wait = _longestWait;
        _waitUntil = _clock().add(wait);
        notifyListeners();
      }
      return false;
    }
    _failures = 0;
    _waitUntil = null;
    unlock();
    return true;
  }

  /// Removes the PIN entirely. The Lock screen stops gating the app until
  /// a new one is set.
  Future<void> clearPin() async {
    await _storage.clear();
    _pinIsSet = false;
    _failures = 0;
    _waitUntil = null;
    _locked = false;
    notifyListeners();
    await _screenPrivacy?.setHidden(false);
  }

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
