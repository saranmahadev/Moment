import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../emoji/moods.dart';
import 'media_quality.dart';

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

  /// Settings that are not kept anywhere: for tests and previews.
  factory AppSettings.inMemory([Map<String, Object?>? values]) =>
      AppSettings._(MemorySettingsStore(values), {...?values});

  final SettingsStore _store;
  final Map<String, Object?> _values;

  /// Whether a new pin's coordinates may be sent to the place-name service
  /// to suggest a name. The only thing in the app that uses the internet;
  /// off unless the owner turns it on.
  bool get lookUpPlaceNames => _read('lookUpPlaceNames', false);

  Future<void> setLookUpPlaceNames(bool value) =>
      _set('lookUpPlaceNames', value, false);

  /// Light, dark, or whatever the system is set to.
  ThemeMode get themeMode {
    final name = _read<String?>('themeMode', null);
    return ThemeMode.values.where((mode) => mode.name == name).firstOrNull ??
        ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _set('themeMode', mode.name, ThemeMode.system.name);

  /// Swaps glass for solid surfaces on every screen.
  bool get reduceTransparency => _read('reduceTransparency', false);

  Future<void> setReduceTransparency(bool value) =>
      _set('reduceTransparency', value, false);

  /// The five emoji on Home's quick row.
  List<String> get quickEmoji {
    final stored = _values['quickEmoji'];
    if (stored is List &&
        stored.length == 5 &&
        stored.every((e) => e is String && e.isNotEmpty)) {
      return List<String>.from(stored);
    }
    return List<String>.of(defaultQuickEmoji);
  }

  Future<void> setQuickEmoji(List<String> emoji) {
    if (emoji.length != 5 || emoji.any((e) => e.isEmpty)) {
      throw ArgumentError.value(emoji, 'emoji', 'must be five emoji');
    }
    return _setList('quickEmoji', List<String>.of(emoji), quickEmoji);
  }

  /// Whether the daily reminder is on, and when it rings.
  bool get reminderOn => _read('reminderOn', false);

  Future<void> setReminderOn(bool value) => _set('reminderOn', value, false);

  TimeOfDay get reminderTime {
    final minutes = _read('reminderMinutes', _defaultReminderMinutes);
    final valid = minutes >= 0 && minutes < 24 * 60
        ? minutes
        : _defaultReminderMinutes;
    return TimeOfDay(hour: valid ~/ 60, minute: valid % 60);
  }

  Future<void> setReminderTime(TimeOfDay time) => _set(
    'reminderMinutes',
    time.hour * 60 + time.minute,
    reminderTime.hour * 60 + reminderTime.minute,
  );

  static const _defaultReminderMinutes = 21 * 60;

  /// How much of a new photo is kept.
  MediaQuality get mediaQuality {
    final name = _read<String?>('mediaQuality', null);
    return MediaQuality.values.where((q) => q.name == name).firstOrNull ??
        MediaQuality.original;
  }

  Future<void> setMediaQuality(MediaQuality quality) =>
      _set('mediaQuality', quality.name, mediaQuality.name);

  /// What was searched for lately, newest first, at most [_maxRecent].
  List<String> get recentSearches {
    final stored = _values['recentSearches'];
    return stored is List ? stored.whereType<String>().toList() : [];
  }

  static const _maxRecent = 8;

  /// Remembers [query] as the newest search. One searched before moves to
  /// the front instead of appearing twice.
  Future<void> addRecentSearch(String query) {
    final trimmed = query.trim();
    final current = recentSearches;
    if (trimmed.isEmpty) return Future.value();
    final updated = [
      trimmed,
      ...current.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
    ].take(_maxRecent).toList();
    return _setList('recentSearches', updated, current);
  }

  Future<void> clearRecentSearches() =>
      _setList('recentSearches', const [], recentSearches);

  /// Whether the streak chip, the Calendar card and the Streaks page are
  /// shown at all.
  bool get showStreaks => _read('showStreaks', true);

  Future<void> setShowStreaks(bool value) => _set('showStreaks', value, true);

  /// How many missed days a week a streak forgives, 0 to 3.
  int get graceDays {
    final value = _read('graceDays', _defaultGraceDays);
    return value >= 0 && value <= 3 ? value : _defaultGraceDays;
  }

  Future<void> setGraceDays(int days) {
    if (days < 0 || days > 3) {
      throw ArgumentError.value(days, 'days', 'must be 0 to 3');
    }
    return _set('graceDays', days, graceDays);
  }

  /// Whether the home screen widget shows the streak (with the Quick add
  /// buttons) or only the buttons. The streak is the one thing from the
  /// journal that the widget is ever given.
  bool get widgetShowsStreak => _read('widgetShowsStreak', true);

  Future<void> setWidgetShowsStreak(bool value) =>
      _set('widgetShowsStreak', value, true);

  static const _defaultGraceDays = 1;

  T _read<T>(String key, T fallback) {
    final value = _values[key];
    return value is T ? value : fallback;
  }

  Future<void> _setList(
    String key,
    List<String> value,
    List<String> current,
  ) async {
    if (listEquals(value, current)) return;
    _values[key] = value;
    notifyListeners();
    await _store.write(_values);
  }

  Future<void> _set<T>(String key, T value, T fallback) async {
    if (_read(key, fallback) == value) return;
    _values[key] = value;
    notifyListeners();
    await _store.write(_values);
  }
}
