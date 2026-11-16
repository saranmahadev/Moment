import 'package:flutter_test/flutter_test.dart';
import 'package:moment/calendar/calendar_model.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';

/// A text log made at [utc], on a device whose clock was [offset] ahead of
/// UTC at that moment.
TextLog textAt(DateTime utc, Duration offset, {String body = 'x'}) => TextLog(
  id: '${utc.toIso8601String()}-${offset.inMinutes}',
  createdAt: utc,
  tzOffsetMinutes: offset.inMinutes,
  editedAt: null,
  deletedAt: null,
  body: body,
);

EmojiLog emojiAt(DateTime utc) => EmojiLog(
  id: 'e-${utc.toIso8601String()}',
  createdAt: utc,
  tzOffsetMinutes: 0,
  editedAt: null,
  deletedAt: null,
  emoji: '😌',
  label: 'Calm',
  strength: 4,
);

void main() {
  group('monthGrid', () {
    test('November 2026: six weeks from Monday 26 October', () {
      final grid = monthGrid(2026, 11);

      expect(grid, hasLength(42));
      expect(grid.first, DateTime.utc(2026, 10, 26));
      expect(grid[6], DateTime.utc(2026, 11, 1)); // a Sunday
      expect(grid.last, DateTime.utc(2026, 12, 6));
      expect(grid.every((d) => d.isUtc), isTrue);
    });

    test('a month that starts on a Monday starts in the first cell', () {
      // 1 June 2026 is a Monday.
      expect(monthGrid(2026, 6).first, DateTime.utc(2026, 6, 1));
    });

    test('February in a leap year has its 29th', () {
      int februaryDays(int year) =>
          monthGrid(year, 2).where((d) => d.month == 2).length;

      expect(februaryDays(2028), 29);
      expect(februaryDays(2027), 28);
    });

    test('every cell is exactly one day after the one before', () {
      final grid = monthGrid(2026, 3); // spans a daylight-saving change
      for (var i = 1; i < grid.length; i++) {
        expect(grid[i].difference(grid[i - 1]), const Duration(days: 1));
      }
    });
  });

  group('logsByDay', () {
    test('a log made at 23:50 stays on its day after travelling', () {
      // 23:50 on 6 November in Bengaluru (UTC+5:30) is 18:20 UTC.
      final log = textAt(
        DateTime.utc(2026, 11, 6, 18, 20),
        const Duration(hours: 5, minutes: 30),
      );

      final days = logsByDay([log]);

      // Whatever zone the phone is in now, it is still the 6th.
      expect(days.keys.single, DateTime.utc(2026, 11, 6));
    });

    test('the same instant lands on different days in different zones', () {
      final instant = DateTime.utc(2026, 11, 6, 22, 30);

      expect(
        logsByDay([textAt(instant, const Duration(hours: 2))]).keys.single,
        DateTime.utc(2026, 11, 7),
      );
      expect(
        logsByDay([textAt(instant, const Duration(hours: -8))]).keys.single,
        DateTime.utc(2026, 11, 6),
      );
    });

    test('a day that crosses a daylight-saving change stays one day', () {
      // Berlin, 25 October 2026: clocks go back at 03:00 (UTC+2 to UTC+1).
      final before = textAt(
        DateTime.utc(2026, 10, 24, 22, 30), // 00:30 local, still summer time
        const Duration(hours: 2),
      );
      final after = textAt(
        DateTime.utc(2026, 10, 25, 22, 30), // 23:30 local, winter time
        const Duration(hours: 1),
      );

      final days = logsByDay([after, before]);

      expect(days.keys.single, DateTime.utc(2026, 10, 25));
      expect(days.values.single, [after, before]);
    });

    test('the spring-forward day, an hour short, is still one day', () {
      // Berlin, 29 March 2026: clocks go forward at 02:00 (UTC+1 to UTC+2).
      final early = textAt(
        DateTime.utc(2026, 3, 29, 0, 30), // 01:30 local, winter time
        const Duration(hours: 1),
      );
      final late = textAt(
        DateTime.utc(2026, 3, 29, 21, 30), // 23:30 local, summer time
        const Duration(hours: 2),
      );

      expect(logsByDay([late, early]).keys.single, DateTime.utc(2026, 3, 29));
    });

    test('keeps the order it was given within a day', () {
      final a = textAt(DateTime.utc(2026, 11, 6, 20), Duration.zero);
      final b = textAt(DateTime.utc(2026, 11, 6, 9), Duration.zero);
      final c = textAt(DateTime.utc(2026, 11, 5, 9), Duration.zero);

      final days = logsByDay([a, b, c]);

      expect(days[DateTime.utc(2026, 11, 6)], [a, b]);
      expect(days[DateTime.utc(2026, 11, 5)], [c]);
    });

    test('only the wanted type, when one is asked for', () {
      final text = textAt(DateTime.utc(2026, 11, 6, 20), Duration.zero);
      final emoji = emojiAt(DateTime.utc(2026, 11, 6, 21));

      final days = logsByDay([emoji, text], type: LogType.emoji);

      expect(days[DateTime.utc(2026, 11, 6)], [emoji]);
    });
  });

  group('typesOn', () {
    test('lists each type once, in the app\'s type order', () {
      final logs = [
        emojiAt(DateTime.utc(2026, 11, 6, 21)),
        textAt(DateTime.utc(2026, 11, 6, 20), Duration.zero),
        emojiAt(DateTime.utc(2026, 11, 6, 8)),
      ];

      expect(typesOn(logs), [LogType.text, LogType.emoji]);
      expect(typesOn(const []), isEmpty);
    });
  });

  group('summaryOf', () {
    Log make(Log log) => log;
    final at = DateTime.utc(2026, 11, 6, 12);

    test('emoji: its name and strength', () {
      expect(summaryOf(emojiAt(at)), 'Calm · strength 4 of 5');
      expect(
        summaryOf(
          EmojiLog(
            id: 'e',
            createdAt: at,
            tzOffsetMinutes: 0,
            editedAt: null,
            deletedAt: null,
            emoji: '🫠',
            label: null,
            strength: 2,
          ),
        ),
        '🫠 · strength 2 of 5',
      );
    });

    test('text: its words, on one line', () {
      expect(
        summaryOf(textAt(at, Duration.zero, body: 'Quiet evening.\nSlept.')),
        'Quiet evening. Slept.',
      );
    });

    test('photo: its caption, or just "Photo"', () {
      PhotoLog photo(String? caption) => PhotoLog(
        id: 'p',
        createdAt: at,
        tzOffsetMinutes: 0,
        editedAt: null,
        deletedAt: null,
        path: 'a.jpg',
        thumbnailPath: 'a-thumb.jpg',
        caption: caption,
      );
      expect(summaryOf(photo('Morning light')), 'Morning light');
      expect(summaryOf(photo(null)), 'Photo');
    });

    test('audio and video: a title and how long', () {
      expect(
        summaryOf(
          make(
            AudioLog(
              id: 'a',
              createdAt: at,
              tzOffsetMinutes: 0,
              editedAt: null,
              deletedAt: null,
              path: 'a.m4a',
              duration: const Duration(seconds: 42),
              peaks: const [],
              title: null,
              note: null,
            ),
          ),
        ),
        'Voice note · 0:42',
      );
      expect(
        summaryOf(
          make(
            VideoLog(
              id: 'v',
              createdAt: at,
              tzOffsetMinutes: 0,
              editedAt: null,
              deletedAt: null,
              path: 'v.mp4',
              posterPath: 'v.jpg',
              duration: const Duration(seconds: 48),
              caption: 'Walk to the station',
            ),
          ),
        ),
        'Walk to the station · 0:48',
      );
    });

    test('location: its name, or its coordinates', () {
      LocationLog place(String? name) => LocationLog(
        id: 'l',
        createdAt: at,
        tzOffsetMinutes: 0,
        editedAt: null,
        deletedAt: null,
        latitude: 12.9716,
        longitude: 77.5946,
        accuracyMeters: null,
        name: name,
        note: null,
      );
      expect(summaryOf(place('Favourite bench')), 'Favourite bench');
      expect(summaryOf(place(null)), contains('12.9716'));
    });
  });
}
