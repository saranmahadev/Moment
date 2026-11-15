import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Where the app's settings are kept between launches.
abstract interface class SettingsStore {
  Future<Map<String, Object?>> read();
  Future<void> write(Map<String, Object?> values);
}

/// Keeps the settings in a small JSON file in the app-private directory.
/// A missing or damaged file reads as "no settings", so every value falls
/// back to its default.
class FileSettingsStore implements SettingsStore {
  FileSettingsStore(this._file);

  final File _file;

  @override
  Future<Map<String, Object?>> read() async {
    if (!await _file.exists()) return {};
    try {
      final json = jsonDecode(await _file.readAsString());
      return json is Map<String, Object?> ? json : {};
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> write(Map<String, Object?> values) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(values));
  }
}

/// Settings that last only as long as the object: for tests and previews.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([Map<String, Object?>? values]) : _values = {...?values};

  Map<String, Object?> _values;

  @override
  Future<Map<String, Object?>> read() async => {..._values};

  @override
  Future<void> write(Map<String, Object?> values) async =>
      _values = {...values};
}

/// The app's settings. A change takes effect at once (listeners are told
/// before the write finishes) and is kept across restarts.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._store, this._values);

  /// Reads the stored settings, with defaults for anything missing.
  static Future<AppSettings> load(SettingsStore store) async =>
      AppSettings._(store, await store.read());

  final SettingsStore _store;
  final Map<String, Object?> _values;

  /// Whether a new pin's coordinates may be sent to the place-name service
  /// to suggest a name. The only thing in the app that uses the internet;
  /// off unless the owner turns it on.
  bool get lookUpPlaceNames => _read('lookUpPlaceNames', false);

  Future<void> setLookUpPlaceNames(bool value) =>
      _set('lookUpPlaceNames', value, false);

  T _read<T>(String key, T fallback) {
    final value = _values[key];
    return value is T ? value : fallback;
  }

  Future<void> _set<T>(String key, T value, T fallback) async {
    if (_read(key, fallback) == value) return;
    _values[key] = value;
    notifyListeners();
    await _store.write(_values);
  }
}
