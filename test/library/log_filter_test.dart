import 'package:flutter_test/flutter_test.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/library/log_filter.dart';

Log text(String id, DateTime at) => TextLog(
  id: id,
  createdAt: at,
  tzOffsetMinutes: 0,
  editedAt: null,
  deletedAt: null,
  body: id,
);

Log emoji(String id, DateTime at, int strength) => EmojiLog(
  id: id,
  createdAt: at,
  tzOffsetMinutes: 0,
  editedAt: null,
  deletedAt: null,
  emoji: '😌',
  label: 'Calm',
  strength: strength,
);

Log photo(String id, DateTime at, {String? caption}) => PhotoLog(
  id: id,
  createdAt: at,
  tzOffsetMinutes: 0,
  editedAt: null,
  deletedAt: null,
  path: '/p.jpg',
  thumbnailPath: '/t.jpg',
  caption: caption,
);

Log audio(String id, DateTime at, {String? title}) => AudioLog(
  id: id,
  createdAt: at,
  tzOffsetMinutes: 0,
  editedAt: null,
  deletedAt: null,
  path: '/a.m4a',
  duration: const Duration(seconds: 4),
  peaks: const [],
  title: title,
  note: null,
);

Log place(String id, DateTime at, {String? name}) => LocationLog(
  id: id,
  createdAt: at,
  tzOffsetMinutes: 0,
  editedAt: null,
  deletedAt: null,
  latitude: 1,
  longitude: 2,
  accuracyMeters: null,
  name: name,
  note: null,
);

void main() {
  // Wednesday 18 November 2026, evening.
  final today = DateTime.utc(2026, 11, 18);
  DateTime day(int month, int d, [int hour = 12]) =>
      DateTime.utc(2026, month, d, hour);

  // Newest first, as the repository hands logs over.
  final logs = <Log>[
    text('today', day(11, 18, 20)),
    text('yesterday', day(11, 17)),
    text('six-days-ago', day(11, 12)),
    text('seven-days-ago', day(11, 11)),
    text('twenty-nine-days-ago', day(10, 20)),
    text('thirty-days-ago', day(10, 19)),
    text('earlier-this-year', day(2, 3)),
    text('last-year', DateTime.utc(2025, 12, 31, 23)),
  ];

  List<String> ids(LogFilter f, [List<Log>? from]) =>
      f.apply(from ?? logs, today: today).map((l) => l.id).toList();

  group('the default filter', () {
    test('keeps everything, newest first, and is not active', () {
      const f = LogFilter();
      expect(f.isActive, isFalse);
      expect(f.activeCount, 0);
      expect(ids(f), logs.map((l) => l.id));
    });
  });

  group('when', () {
    test('Today is the local day only', () {
      expect(ids(const LogFilter(window: FilterWindow.today)), ['today']);
    });

    test('Last 7 days is today and the six days before', () {
      expect(ids(const LogFilter(window: FilterWindow.last7)), [
        'today',
        'yesterday',
        'six-days-ago',
      ]);
    });

    test('Last 30 days is today and the 29 days before', () {
      expect(ids(const LogFilter(window: FilterWindow.last30)), [
        'today',
        'yesterday',
        'six-days-ago',
        'seven-days-ago',
        'twenty-nine-days-ago',
      ]);
    });

    test('This year stops at the first of January', () {
      final f = const LogFilter(window: FilterWindow.thisYear);
      expect(ids(f), isNot(contains('last-year')));
      expect(ids(f), contains('earlier-this-year'));
    });

    test('a log made late in the evening elsewhere counts on its own day', () {
      // 23:50 in UTC+5:30 is 18:20 UTC the same day: still "today".
      final late = TextLog(
        id: 'late',
        createdAt: DateTime.utc(2026, 11, 18, 18, 20),
        tzOffsetMinutes: 330,
        editedAt: null,
        deletedAt: null,
        body: 'late',
      );
      expect(ids(const LogFilter(window: FilterWindow.today), [late]), [
        'late',
      ]);
    });
  });

  group('order', () {
    test('Oldest first reverses the list', () {
      expect(
        ids(const LogFilter(oldestFirst: true)),
        logs.reversed.map((l) => l.id),
      );
    });

    test('the order counts as an active filter', () {
      expect(const LogFilter(oldestFirst: true).isActive, isTrue);
    });
  });

  group('emoji strength', () {
    final feelings = [
      emoji('a', day(11, 18), 5),
      emoji('b', day(11, 17), 3),
      emoji('c', day(11, 16), 1),
      emoji('d', day(11, 15), 5),
    ];

    test('keeps only the chosen strengths', () {
      expect(ids(const LogFilter(strengths: {5}), feelings), ['a', 'd']);
      expect(ids(const LogFilter(strengths: {1, 3}), feelings), ['b', 'c']);
    });

    test('no strengths chosen means any', () {
      expect(ids(const LogFilter(), feelings), ['a', 'b', 'c', 'd']);
    });

    test('other types are not touched by a strength choice', () {
      final mixed = [text('t', day(11, 18)), ...feelings];
      expect(ids(const LogFilter(strengths: {5}), mixed), ['t', 'a', 'd']);
    });
  });

  group('only with a caption, title or name', () {
    test('photos need a caption', () {
      final photos = [
        photo('with', day(11, 18), caption: 'Lake'),
        photo('without', day(11, 17)),
        photo('blank', day(11, 16), caption: '  '),
      ];
      expect(ids(const LogFilter(onlyNamed: true), photos), ['with']);
    });

    test('audio needs a title', () {
      final notes = [
        audio('with', day(11, 18), title: 'Walk'),
        audio('without', day(11, 17)),
      ];
      expect(ids(const LogFilter(onlyNamed: true), notes), ['with']);
    });

    test('places need a name', () {
      final places = [
        place('with', day(11, 18), name: 'Bench'),
        place('without', day(11, 17)),
      ];
      expect(ids(const LogFilter(onlyNamed: true), places), ['with']);
    });

    test('text has no caption, so the choice leaves it alone', () {
      expect(ids(const LogFilter(onlyNamed: true), [text('t', day(11, 18))]), [
        't',
      ]);
    });
  });

  group('together', () {
    test('every choice applies at once, and each counts', () {
      const f = LogFilter(
        window: FilterWindow.last7,
        oldestFirst: true,
        strengths: {5},
        onlyNamed: true,
      );
      expect(f.activeCount, 4);
      final feelings = [
        emoji('new', day(11, 18), 5),
        emoji('mid', day(11, 17), 3),
        emoji('old', day(11, 12), 5),
        emoji('too-old', day(10, 1), 5),
      ];
      expect(ids(f, feelings), ['old', 'new']);
    });

    test('copyWith changes one thing', () {
      const f = LogFilter(strengths: {5});
      expect(f.copyWith(onlyNamed: true).strengths, {5});
      expect(f.copyWith(onlyNamed: true).onlyNamed, isTrue);
      expect(f.copyWith(window: FilterWindow.today).strengths, {5});
    });

    test('two equal filters are equal', () {
      expect(
        const LogFilter(strengths: {1, 2}),
        const LogFilter(strengths: {2, 1}),
      );
      expect(const LogFilter(), isNot(const LogFilter(oldestFirst: true)));
    });
  });
}
