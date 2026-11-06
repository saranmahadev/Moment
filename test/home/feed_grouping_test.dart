import 'package:flutter_test/flutter_test.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/home/feed_grouping.dart';

TextLog _textAt(DateTime createdAt, {String id = 'id'}) => TextLog(
  id: id,
  createdAt: createdAt,
  tzOffsetMinutes: 0,
  editedAt: null,
  deletedAt: null,
  body: 'body',
);

void main() {
  // "Now" is Friday 6 November 2026, matching 02-Home-all-six-log-types.png.
  final now = DateTime.utc(2026, 11, 6, 21, 50);

  test('groups a log made today under TODAY with its weekday and date', () {
    final sections = groupFeedByDay([
      _textAt(DateTime.utc(2026, 11, 6, 20, 12)),
    ], now: now);

    expect(sections, hasLength(1));
    expect(sections.single.label, 'TODAY · FRI 6 NOV');
    expect(sections.single.logs, hasLength(1));
  });

  test('groups a log made yesterday under YESTERDAY', () {
    final sections = groupFeedByDay([
      _textAt(DateTime.utc(2026, 11, 5, 18, 30)),
    ], now: now);

    expect(sections.single.label, 'YESTERDAY · THU 5 NOV');
  });

  test('an older log is labelled with just its weekday and date', () {
    final sections = groupFeedByDay([
      _textAt(DateTime.utc(2026, 10, 30, 9, 0)),
    ], now: now);

    expect(sections.single.label, 'FRI 30 OCT');
  });

  test('keeps logs from the same day together, in feed order', () {
    final sections = groupFeedByDay([
      _textAt(DateTime.utc(2026, 11, 6, 21, 40), id: 'a'),
      _textAt(DateTime.utc(2026, 11, 6, 20, 12), id: 'b'),
    ], now: now);

    expect(sections, hasLength(1));
    expect(sections.single.logs.map((l) => l.id), ['a', 'b']);
  });

  test('splits logs from different days into separate, ordered sections', () {
    final sections = groupFeedByDay([
      _textAt(DateTime.utc(2026, 11, 6, 21, 40), id: 'today'),
      _textAt(DateTime.utc(2026, 11, 5, 22, 10), id: 'yesterday'),
    ], now: now);

    expect(sections, hasLength(2));
    expect(sections[0].label, 'TODAY · FRI 6 NOV');
    expect(sections[0].logs.single.id, 'today');
    expect(sections[1].label, 'YESTERDAY · THU 5 NOV');
    expect(sections[1].logs.single.id, 'yesterday');
  });

  test('groups by the recorded local day, not the UTC day', () {
    // 00:20 UTC on the 7th, made in UTC-1, so locally it was still 23:20 on
    // the 6th (today).
    final log = TextLog(
      id: 'late',
      createdAt: DateTime.utc(2026, 11, 7, 0, 20),
      tzOffsetMinutes: -60,
      editedAt: null,
      deletedAt: null,
      body: 'late',
    );

    final sections = groupFeedByDay([log], now: now);
    expect(sections.single.label, 'TODAY · FRI 6 NOV');
  });

  test('an empty feed has no sections', () {
    expect(groupFeedByDay(const [], now: now), isEmpty);
  });

  group('LogType filtering is not this function\'s job', () {
    test('it groups whatever list it is given, unfiltered', () {
      final emoji = EmojiLog(
        id: 'e',
        createdAt: DateTime.utc(2026, 11, 6, 8),
        tzOffsetMinutes: 0,
        editedAt: null,
        deletedAt: null,
        emoji: '😌',
        label: null,
        strength: 3,
      );
      final sections = groupFeedByDay([emoji], now: now);
      expect(sections.single.logs.single.type, LogType.emoji);
    });
  });
}
