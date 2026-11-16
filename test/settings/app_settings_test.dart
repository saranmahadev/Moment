import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/settings/app_settings.dart';
import 'package:moment/settings/media_quality.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late File file;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('app_settings_test_');
    file = File(p.join(tempDir.path, 'nested', 'settings.json'));
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('place names are not looked up unless turned on', () async {
    final settings = await AppSettings.load(FileSettingsStore(file));

    expect(settings.lookUpPlaceNames, isFalse);
  });

  test('a change takes effect at once and tells listeners', () async {
    final settings = await AppSettings.load(MemorySettingsStore());
    var notified = 0;
    settings.addListener(() => notified++);

    final saving = settings.setLookUpPlaceNames(true);

    expect(settings.lookUpPlaceNames, isTrue);
    expect(notified, 1);
    await saving;
  });

  test('setting the value it already has tells nobody', () async {
    final settings = await AppSettings.load(MemorySettingsStore());
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setLookUpPlaceNames(false);

    expect(notified, 0);
  });

  test('a change survives a restart', () async {
    final first = await AppSettings.load(FileSettingsStore(file));
    await first.setLookUpPlaceNames(true);

    final second = await AppSettings.load(FileSettingsStore(file));

    expect(second.lookUpPlaceNames, isTrue);
  });

  test('in-memory settings start from the values given', () {
    expect(AppSettings.inMemory().lookUpPlaceNames, isFalse);
    expect(
      AppSettings.inMemory({'lookUpPlaceNames': true}).lookUpPlaceNames,
      isTrue,
    );
  });

  test('a damaged settings file falls back to the defaults', () async {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('{not json');

    final settings = await AppSettings.load(FileSettingsStore(file));

    expect(settings.lookUpPlaceNames, isFalse);
  });

  test('a value of the wrong kind falls back to its default', () async {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('{"lookUpPlaceNames": "yes"}');

    final settings = await AppSettings.load(FileSettingsStore(file));

    expect(settings.lookUpPlaceNames, isFalse);
  });

  group('appearance', () {
    test('follows the system and keeps glass, until changed', () async {
      final settings = await AppSettings.load(FileSettingsStore(file));

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.reduceTransparency, isFalse);
    });

    test('theme and Reduce Transparency survive a restart', () async {
      final first = await AppSettings.load(FileSettingsStore(file));
      await first.setThemeMode(ThemeMode.dark);
      await first.setReduceTransparency(true);

      final second = await AppSettings.load(FileSettingsStore(file));

      expect(second.themeMode, ThemeMode.dark);
      expect(second.reduceTransparency, isTrue);
    });

    test('an unknown theme name falls back to the system', () {
      expect(
        AppSettings.inMemory({'themeMode': 'sepia'}).themeMode,
        ThemeMode.system,
      );
    });

    test('each change tells listeners once', () async {
      final settings = AppSettings.inMemory();
      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setThemeMode(ThemeMode.light);
      await settings.setThemeMode(ThemeMode.light);
      await settings.setReduceTransparency(true);

      expect(notified, 2);
    });
  });

  group('logging', () {
    test(
      'defaults: the five moods, no reminder at 21:00, original quality',
      () {
        final settings = AppSettings.inMemory();

        expect(settings.quickEmoji, ['😊', '😌', '😐', '😔', '😤']);
        expect(settings.reminderOn, isFalse);
        expect(settings.reminderTime, const TimeOfDay(hour: 21, minute: 0));
        expect(settings.mediaQuality, MediaQuality.original);
      },
    );

    test('each one survives a restart', () async {
      final first = await AppSettings.load(FileSettingsStore(file));
      await first.setQuickEmoji(['🥰', '😴', '😊', '😢', '🤒']);
      await first.setReminderOn(true);
      await first.setReminderTime(const TimeOfDay(hour: 7, minute: 45));
      await first.setMediaQuality(MediaQuality.smaller);

      final second = await AppSettings.load(FileSettingsStore(file));

      expect(second.quickEmoji, ['🥰', '😴', '😊', '😢', '🤒']);
      expect(second.reminderOn, isTrue);
      expect(second.reminderTime, const TimeOfDay(hour: 7, minute: 45));
      expect(second.mediaQuality, MediaQuality.smaller);
    });

    test('the quick row is always exactly five emoji', () async {
      final settings = AppSettings.inMemory();

      expect(() => settings.setQuickEmoji(['😊']), throwsArgumentError);
      expect(
        () => settings.setQuickEmoji(['😊', '😌', '😐', '😔', '']),
        throwsArgumentError,
      );
      expect(settings.quickEmoji, hasLength(5));
    });

    test('damaged values fall back to the defaults', () {
      final settings = AppSettings.inMemory({
        'quickEmoji': ['😊', 7],
        'reminderMinutes': 5000,
        'mediaQuality': 'ultra',
      });

      expect(settings.quickEmoji, ['😊', '😌', '😐', '😔', '😤']);
      expect(settings.reminderTime, const TimeOfDay(hour: 21, minute: 0));
      expect(settings.mediaQuality, MediaQuality.original);
    });
  });
}
