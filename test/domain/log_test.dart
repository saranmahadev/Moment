import 'package:flutter_test/flutter_test.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';

void main() {
  group('Log.localDay', () {
    test('is the calendar day of createdAt when the offset is zero', () {
      final log = TextLog(
        id: '1',
        createdAt: DateTime.utc(2026, 3, 14, 9, 30),
        tzOffsetMinutes: 0,
        editedAt: null,
        deletedAt: null,
        body: 'hi',
      );

      expect(log.localDay, DateTime.utc(2026, 3, 14));
    });

    test('a log made late at night stays on its original day after '
        'travelling to a time zone behind it', () {
      // Made at 23:50 in UTC+2 (21:50 UTC): still the 14th locally.
      final log = TextLog(
        id: '1',
        createdAt: DateTime.utc(2026, 3, 14, 21, 50),
        tzOffsetMinutes: 120,
        editedAt: null,
        deletedAt: null,
        body: 'late',
      );

      expect(log.localDay, DateTime.utc(2026, 3, 14));

      // The same instant, read back after the device moved to UTC-5: the
      // recorded offset (not the device's current zone) decides the day.
      expect(log.tzOffsetMinutes, 120);
    });

    test('a negative offset can push a log back to the previous UTC day', () {
      // 00:20 UTC on the 15th, made in UTC-1, so locally it was still 23:20
      // on the 14th.
      final log = EmojiLog(
        id: '2',
        createdAt: DateTime.utc(2026, 3, 15, 0, 20),
        tzOffsetMinutes: -60,
        editedAt: null,
        deletedAt: null,
        emoji: '😌',
        label: null,
        strength: 3,
      );

      expect(log.localDay, DateTime.utc(2026, 3, 14));
    });
  });

  group('type', () {
    test('a TextLog reports LogType.text', () {
      final log = TextLog(
        id: '1',
        createdAt: DateTime.utc(2026),
        tzOffsetMinutes: 0,
        editedAt: null,
        deletedAt: null,
        body: 'hi',
      );
      expect(log.type, LogType.text);
    });

    test('an EmojiLog reports LogType.emoji', () {
      final log = EmojiLog(
        id: '1',
        createdAt: DateTime.utc(2026),
        tzOffsetMinutes: 0,
        editedAt: null,
        deletedAt: null,
        emoji: '😌',
        label: null,
        strength: 1,
      );
      expect(log.type, LogType.emoji);
    });
  });
}
